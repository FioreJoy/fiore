// frontend/lib/services/notification_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:collection/collection.dart'; // Not strictly needed for current logic

import '../models/notification_model.dart';
import 'api/notification_service.dart';
import 'auth_provider.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService;
  final AuthProvider _authProvider;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _canLoadMore = true;
  String? _error;
  int _currentPage = 0;
  final int _limit = 20;

  late StreamSubscription _authSubscription;

  NotificationProvider(this._notificationService, this._authProvider) {
    print("+++ NotificationProvider CONSTRUCTOR CALLED +++");
    print("  Received NotificationService: ${_notificationService.runtimeType}");
    print("  Received AuthProvider: ${_authProvider.runtimeType}, IsAuth: ${_authProvider.isAuthenticated}");

    _authSubscription = _authProvider.userStream.listen((authData) { // authData is AuthProvider instance
      print("NotificationProvider: Auth state changed via userStream. IsAuth: ${authData.isAuthenticated}");
      if (authData.isAuthenticated && authData.token != null) {
        resetAndFetchNotifications();
      } else {
        clearNotifications();
      }
    });

    if (_authProvider.isAuthenticated && _authProvider.token != null) {
      print("NotificationProvider: Initialized while authenticated. Scheduling resetAndFetchNotifications().");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // No mounted check needed here as this is not a widget's state object
        print("NotificationProvider: PostFrameCallback - Calling resetAndFetchNotifications().");
        resetAndFetchNotifications();
      });
    } else {
      print("NotificationProvider: Initialized while unauthenticated.");
    }
  }

  @override
  void dispose() {
    print("--- NotificationProvider DISPOSE CALLED ---");
    _authSubscription.cancel();
    super.dispose();
    print("NotificationProvider disposed successfully.");
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _canLoadMore;
  String? get error => _error;

  Future<void> resetAndFetchNotifications() async {
    if (_isLoading) {
      print("NotificationProvider: resetAndFetchNotifications called while already loading, returning.");
      return;
    }
    print("NotificationProvider: Resetting and fetching initial notifications.");
    _notifications = [];
    _currentPage = 0;
    _canLoadMore = true;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        fetchNotifications(isInitialLoad: true),
        fetchUnreadCount(),
      ]);
    } catch (e) {
      print("NotificationProvider: Error during resetAndFetch (likely from fetchNotifications): $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> fetchNotifications({bool isInitialLoad = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      print("NotificationProvider: fetchNotifications - Not authenticated.");
      _error = "Not authenticated.";
      if (isInitialLoad) _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
      return;
    }
    if ((_isLoadingMore && !isInitialLoad) || (!isInitialLoad && !_canLoadMore)) {
      print("NotificationProvider: fetchNotifications - Skipping (isLoadingMore: $_isLoadingMore, canLoadMore: $_canLoadMore).");
      return;
    }

    if (isInitialLoad) {
      print("NotificationProvider: fetchNotifications - Initial load preparations.");
      _currentPage = 0;
      _notifications.clear();
      _canLoadMore = true;
      // _isLoading is set by resetAndFetchNotifications for initial load
    }

    print("NotificationProvider: Fetching notifications (page: ${_currentPage + 1})");
    if (!isInitialLoad) _isLoadingMore = true; else _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> fetchedData = await _notificationService.getNotifications(
        token: _authProvider.token!,
        limit: _limit,
        offset: _currentPage * _limit,
      );
      print("NotificationProvider: Fetched ${fetchedData.length} notifications from service.");

      final newNotifications = fetchedData
          .map((data) => NotificationModel.fromJson(data as Map<String, dynamic>))
          .toList();

      if (newNotifications.length < _limit) {
        _canLoadMore = false;
        print("NotificationProvider: Can no longer load more notifications.");
      }

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
      if (isInitialLoad) _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      print("NotificationProvider: fetchUnreadCount - Not authenticated.");
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    print("NotificationProvider: Fetching unread count...");
    try {
      final response = await _notificationService.getUnreadNotificationCount(token: _authProvider.token!);
      _unreadCount = response['count'] as int? ?? 0;
      print("NotificationProvider: Unread count updated to $_unreadCount");
    } catch (e) {
      print("NotificationProvider: Error fetching unread count: $e");
    }
    notifyListeners();
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    print("NotificationProvider: Marking notification $notificationId as read.");
    try {
      await _notificationService.markNotificationsRead(
        token: _authProvider.token!,
        notificationIds: [notificationId],
        isRead: true,
      );
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        // Create a new model instance for immutability
        final oldNotification = _notifications[index];
        _notifications[index] = NotificationModel(
            id: oldNotification.id, type: oldNotification.type, isRead: true,
            createdAt: oldNotification.createdAt, contentPreview: oldNotification.contentPreview,
            actor: oldNotification.actor, relatedEntity: oldNotification.relatedEntity
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
        notifyListeners();
        print("NotificationProvider: Notification $notificationId marked read locally.");
      }
    } catch (e) {
      print("NotificationProvider: Error marking notification $notificationId as read: $e");
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    print("NotificationProvider: Marking all notifications as read.");
    try {
      await _notificationService.markAllNotificationsRead(token: _authProvider.token!);
      _notifications = _notifications.map((n) {
        if (n.isRead) return n; // Avoid creating new instance if already read
        return NotificationModel(
            id: n.id, type: n.type, isRead: true, createdAt: n.createdAt,
            contentPreview: n.contentPreview, actor: n.actor, relatedEntity: n.relatedEntity
        );
      }).toList();
      _unreadCount = 0;
      notifyListeners();
      print("NotificationProvider: All notifications marked read locally.");
    } catch (e) {
      print("NotificationProvider: Error marking all notifications as read: $e");
    }
  }

  void clearNotifications() {
    print("NotificationProvider: Clearing all notifications and count.");
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _canLoadMore = true;
    _error = null;
    _currentPage = 0;
    notifyListeners();
  }

  void handleIncomingPushNotification(Map<String, dynamic> payload) {
    print("NotificationProvider: Received push notification payload: $payload - Refreshing data.");
    resetAndFetchNotifications();
  }

  Future<void> registerDeviceToken(String deviceToken, String platform) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) return;
    print("NotificationProvider: Registering device token $platform...");
    try {
      await _notificationService.registerDeviceToken(
        token: _authProvider.token!,
        deviceToken: deviceToken,
        platform: platform,
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
        token: _authProvider.token!,
        deviceToken: deviceToken,
      );
      print("NotificationProvider: Device token $deviceToken unregistered successfully.");
    } catch (e) {
      print("NotificationProvider: Error unregistering device token: $e");
    }
  }
}