// frontend/lib/services/notification_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart'; // For ChangeNotifier & WidgetsBinding
import 'package:flutter/widgets.dart'; // For WidgetsBinding

import '../models/notification_model.dart';
import 'api/notification_service.dart';
import 'auth_provider.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService;
  final AuthProvider _authProvider;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false; // For initial full load
  bool _isLoadingMore = false; // For pagination
  bool _canLoadMore = true;
  String? _error;
  int _currentPage = 0;
  final int _limit = 20;

  StreamSubscription<AuthProvider>? _authSubscription; // Make it nullable

  NotificationProvider(this._notificationService, this._authProvider) {
    print("+++ NotificationProvider CONSTRUCTOR CALLED +++");
    // Listen to AuthProvider changes
    _authSubscription = _authProvider.userStateStream.listen(_handleAuthStateChanged);

    // Initial fetch if already authenticated and AuthProvider is not loading
    if (_authProvider.isAuthenticated && !_authProvider.isLoading && _authProvider.token != null) {
      print("NotificationProvider: Initialized authenticated & AuthProvider loaded. Fetching notifications.");
      // Use WidgetsBinding to ensure this runs after the first frame,
      // giving other parts of the app time to initialize.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) { // Check if provider is still active/listened to
          resetAndFetchNotifications();
        }
      });
    } else if (_authProvider.isLoading) {
      print("NotificationProvider: AuthProvider is still loading. Waiting for auth state change.");
    }
    else {
      print("NotificationProvider: Initialized unauthenticated or token missing.");
      clearLocalState(); // Ensure clean state if not authenticated
    }
  }

  void _handleAuthStateChanged(AuthProvider authProviderInstance) {
    print("NotificationProvider: Auth state changed. IsAuth: ${authProviderInstance.isAuthenticated}, AuthIsLoading: ${authProviderInstance.isLoading}");
    if (authProviderInstance.isAuthenticated && !authProviderInstance.isLoading && authProviderInstance.token != null) {
      // If previously not loading notifications or if an error existed, try fetching.
      if (!_isLoading && (_notifications.isEmpty || _error != null)) {
        print("NotificationProvider: Auth now available, initiating notification fetch.");
        resetAndFetchNotifications();
      }
    } else {
      print("NotificationProvider: Auth lost or still loading, clearing notifications.");
      clearLocalState();
    }
  }

  void clearLocalState() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _canLoadMore = true;
    _error = null;
    _currentPage = 0;
    notifyListeners();
  }


  @override
  void dispose() {
    print("--- NotificationProvider DISPOSE CALLED ---");
    _authSubscription?.cancel();
    super.dispose();
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading; // True during initial full load or refresh
  bool get isLoadingMore => _isLoadingMore; // True only during pagination
  bool get canLoadMore => _canLoadMore;
  String? get error => _error;

  Future<void> resetAndFetchNotifications() async {
    if (_isLoading) return; // Prevent concurrent full reloads
    print("NotificationProvider: Resetting and fetching initial notifications.");
    _currentPage = 0;
    _canLoadMore = true;
    _error = null;
    _isLoading = true; // Indicate overall loading process
    _notifications.clear(); // Clear immediately for UI responsiveness
    notifyListeners();

    try {
      // Fetch unread count first or in parallel
      await fetchUnreadCount(); // Update unread count
      await fetchNotifications(isInitialLoad: true); // Fetch first page
    } catch (e) {
      print("NotificationProvider: Error during resetAndFetch: $e");
      // _error will be set by fetchNotifications if it fails
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNotifications({bool isInitialLoad = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Not authenticated.";
      if (isInitialLoad) _isLoading = false; else _isLoadingMore = false;
      notifyListeners(); return;
    }
    if ((_isLoadingMore && !isInitialLoad) || (!isInitialLoad && !_canLoadMore)) return;

    if (isInitialLoad) {
      _currentPage = 0;
      if(_notifications.isNotEmpty) _notifications.clear(); // Clear only if needed
      _canLoadMore = true;
      // For initial load, _isLoading is already true from resetAndFetchNotifications
    }

    print("NotificationProvider: Fetching notifications (page: ${_currentPage + 1})");
    if (!isInitialLoad) _isLoadingMore = true;
    // No need to set _isLoading = true here if isInitialLoad, already handled by resetAndFetch
    notifyListeners(); // Notify for _isLoadingMore change

    try {
      final List<dynamic> fetchedData = await _notificationService.getNotifications(
        token: _authProvider.token!, limit: _limit, offset: _currentPage * _limit,
      );
      final newNotifications = fetchedData.map((data) => NotificationModel.fromJson(data as Map<String, dynamic>)).toList();

      if (newNotifications.length < _limit) _canLoadMore = false;

      final existingIds = _notifications.map((n) => n.id).toSet();
      _notifications.addAll(newNotifications.where((n) => !existingIds.contains(n.id)));
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _currentPage++;
      _error = null;
    } catch (e) {
      print("NotificationProvider: Error fetching notifications: $e");
      _error = e.toString().replaceFirst("Exception: ", "");
      _canLoadMore = false;
    } finally {
      // Only change _isLoading if it was an initial load.
      // _isLoadingMore is always reset.
      if (isInitialLoad) _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _unreadCount = 0; notifyListeners(); return;
    }
    try {
      final response = await _notificationService.getUnreadNotificationCount(token: _authProvider.token!);
      final newCount = response['count'] as int? ?? 0;
      if (_unreadCount != newCount) {
        _unreadCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      print("NotificationProvider: Error fetching unread count: $e");
      _error = "Failed to update unread count.";
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    final originalNotificationIndex = _notifications.indexWhere((n) => n.id == notificationId);
    if (originalNotificationIndex == -1 || _notifications[originalNotificationIndex].isRead) return;

    final oldNotification = _notifications[originalNotificationIndex];
    _notifications[originalNotificationIndex] = NotificationModel(
        id: oldNotification.id, type: oldNotification.type, isRead: true,
        createdAt: oldNotification.createdAt, contentPreview: oldNotification.contentPreview,
        actor: oldNotification.actor, relatedEntity: oldNotification.relatedEntity
    );
    _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    notifyListeners();

    try {
      await _notificationService.markNotificationsRead(
        token: _authProvider.token!, notificationIds: [notificationId], isRead: true,
      );
    } catch (e) {
      print("NP: Error marking $notificationId as read on server: $e");
      _notifications[originalNotificationIndex] = oldNotification;
      _unreadCount = (_unreadCount + 1);
      _error = "Failed to mark as read. Please try again.";
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null || _unreadCount == 0) return;
    final List<NotificationModel> previouslyUnreadCopy = List.from(_notifications.where((n) => !n.isRead));

    _notifications = _notifications.map((n) => n.isRead ? n : NotificationModel(
        id: n.id, type: n.type, isRead: true, createdAt: n.createdAt,
        contentPreview: n.contentPreview, actor: n.actor, relatedEntity: n.relatedEntity
    )).toList();
    final int oldUnreadCount = _unreadCount;
    _unreadCount = 0;
    notifyListeners();

    try {
      await _notificationService.markAllNotificationsRead(token: _authProvider.token!);
    } catch (e) {
      print("NP: Error marking all as read on server: $e");
      // Rollback by finding original objects and re-inserting their state or re-filtering
      _notifications = _notifications.map((n) {
        final original = previouslyUnreadCopy.firstWhere((oldN) => oldN.id == n.id, orElse: () => n);
        return original; // This restores the 'isRead' state from before optimistic update
      }).toList();
      _unreadCount = oldUnreadCount;
      _error = "Failed to mark all as read. Please try again.";
      notifyListeners();
    }
  }

  // register/unregisterDeviceToken methods remain the same.
  Future<void> registerDeviceToken(String deviceToken, String platform) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    print("NotificationProvider: Registering device token $platform...");
    try {
      await _notificationService.registerDeviceToken(
        token: _authProvider.token!, deviceToken: deviceToken, platform: platform,
      );
      print("NotificationProvider: Device token $platform registered successfully.");
    } catch (e) {
      print("NotificationProvider: Error registering device token: $e");
    }
  }

  Future<void> unregisterDeviceToken(String deviceToken) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    print("NotificationProvider: Unregistering device token...");
    try {
      await _notificationService.unregisterDeviceToken(
        token: _authProvider.token!, deviceToken: deviceToken,
      );
      print("NotificationProvider: Device token $deviceToken unregistered successfully.");
    } catch (e) {
      print("NotificationProvider: Error unregistering device token: $e");
    }
  }
}