// frontend/lib/services/auth_provider.dart

import 'dart:async'; // For StreamController
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userImageUrl;
  bool _isTryingAutoLogin = true;

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  static const _userIdKey = 'userId';
  static const _imageUrlKey = 'userImageUrl';

  // --- Stream for auth state changes ---
  // Broadcasting this provider instance itself when auth state changes.
  final StreamController<AuthProvider> _userStateController = StreamController<AuthProvider>.broadcast();
  Stream<AuthProvider> get userStream => _userStateController.stream;
  // --- End Stream ---


  AuthProvider() {
    _tryAutoLogin();
  }

  @override
  void dispose() {
    _userStateController.close(); // Close the stream controller
    super.dispose();
    print("AuthProvider disposed.");
  }

  // --- Getters ---
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get userImageUrl => _userImageUrl;
  bool get isTryingAutoLogin => _isTryingAutoLogin; // Keep for initial loading UI
  bool get isLoading => _isTryingAutoLogin; // For compatibility if some UI uses isLoading

  Future<void> loadToken() async => await _tryAutoLogin(); // For compatibility

  // --- Actions ---

  Future<void> loginSuccess(String token, String userId, String? imageUrl) async {
    _token = token;
    _userId = userId;
    _userImageUrl = imageUrl;

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _storage.write(key: _imageUrlKey, value: imageUrl);
    } else {
      await _storage.delete(key: _imageUrlKey);
    }

    _isTryingAutoLogin = false; // No longer trying auto login
    print("AuthProvider: Login Success Persisted - User: $userId, Image: $imageUrl");
    notifyListeners();
    if (!_userStateController.isClosed) _userStateController.add(this); // Notify stream listeners
  }

  Future<void> _tryAutoLogin() async {
    // Ensure isTryingAutoLogin is true at the start of this specific operation
    if (!_isTryingAutoLogin) { // Guard against multiple calls if already resolved
      _isTryingAutoLogin = true;
      notifyListeners(); // Notify if state is explicitly changed
    }

    final storedToken = await _storage.read(key: _tokenKey);
    final storedUserId = await _storage.read(key: _userIdKey);
    final storedImageUrl = await _storage.read(key: _imageUrlKey);

    if (storedToken != null && storedUserId != null) {
      _token = storedToken;
      _userId = storedUserId;
      _userImageUrl = storedImageUrl;
      print("AuthProvider: Auto-login successful for User: $storedUserId");
    } else {
      print("AuthProvider: No credentials found for auto-login.");
      _token = null;
      _userId = null;
      _userImageUrl = null;
    }
    _isTryingAutoLogin = false;
    notifyListeners();
    if (!_userStateController.isClosed) _userStateController.add(this); // Notify stream listeners
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userImageUrl = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _imageUrlKey);
    print("AuthProvider: User logged out.");

    if (_isTryingAutoLogin) { // Ensure this flag is reset if logout happens during auto-login attempt
      _isTryingAutoLogin = false;
    }
    notifyListeners();
    if (!_userStateController.isClosed) _userStateController.add(this); // Notify stream listeners
  }

  Future<void> updateUserImageUrl(String? newImageUrl) async {
    if (_userImageUrl != newImageUrl) {
      _userImageUrl = newImageUrl;
      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        await _storage.write(key: _imageUrlKey, value: newImageUrl);
      } else {
        await _storage.delete(key: _imageUrlKey);
      }
      print("AuthProvider: Updated user image URL to $newImageUrl");
      notifyListeners();
      // No need to notify _userStateController here as only image URL changed, not auth state.
      // However, if some parts of UI react to userImageUrl via userStream, then add it.
      // For now, assuming image URL change doesn't alter fundamental auth state.
    }
  }
}