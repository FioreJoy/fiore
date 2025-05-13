// frontend/lib/services/auth_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userImageUrl;
  bool _isLoading = true; // True initially, set to false after auto-login attempt

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _imageUrlKey = 'user_image_url';

  final StreamController<AuthProvider> _userStateController = StreamController<AuthProvider>.broadcast();
  Stream<AuthProvider> get userStateStream => _userStateController.stream;

  AuthProvider() {
    print("AuthProvider: Initializing...");
    // _tryAutoLogin is async, constructor completes. isLoading=true handles UI.
    _tryAutoLogin();
  }

  @override
  void dispose() {
    print("AuthProvider: Disposing.");
    _userStateController.close();
    super.dispose();
  }

  bool get isAuthenticated => _token != null && _userId != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get userImageUrl => _userImageUrl;
  bool get isLoading => _isLoading;

  Future<void> _tryAutoLogin() async {
    print("AuthProvider: Attempting auto-login...");
    // Keep _isLoading = true until this method completes.
    // Only notify if there's an actual change in auth state or after loading finishes.
    String? tempToken, tempUserId, tempImageUrl;
    bool initialAuthStatus = isAuthenticated; // Auth status before trying

    try {
      tempToken = await _storage.read(key: _tokenKey);
      tempUserId = await _storage.read(key: _userIdKey);
      tempImageUrl = await _storage.read(key: _imageUrlKey);

      if (tempToken != null && tempToken.isNotEmpty &&
          tempUserId != null && tempUserId.isNotEmpty) {
        _token = tempToken;
        _userId = tempUserId;
        _userImageUrl = tempImageUrl;
        print("AuthProvider: Auto-login successful for User ID: $_userId");
      } else {
        _token = null;
        _userId = null;
        _userImageUrl = null;
        print("AuthProvider: No valid credentials for auto-login.");
      }
    } catch (e) {
      print("AuthProvider: Error during auto-login storage read: $e");
      _token = null;
      _userId = null;
      _userImageUrl = null;
    } finally {
      // This block executes regardless of try/catch outcome.
      // Set isLoading to false and notify listeners of this change and any auth state change.
      if (_isLoading || initialAuthStatus != isAuthenticated) {
        _isLoading = false;
        notifyListeners(); // Notifies about isLoading change and potential auth state change
        if (!_userStateController.isClosed) _userStateController.add(this);
        print("AuthProvider: Auto-login attempt finished. isLoading: false, isAuthenticated: $isAuthenticated");
      } else {
        // If isLoading was already false (e.g., multiple calls) and auth state didn't change, no need to notify.
        _isLoading = false; // Ensure it's false
      }
    }
  }

  Future<void> loginSuccess(String token, String userId, String? imageUrl) async {
    bool stateChanged = (_token != token || _userId != userId || _userImageUrl != imageUrl || _isLoading);

    _token = token;
    _userId = userId;
    _userImageUrl = imageUrl;
    _isLoading = false;

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _storage.write(key: _imageUrlKey, value: imageUrl);
      } else {
        await _storage.delete(key: _imageUrlKey);
      }
      print("AuthProvider: Login Success - User: $userId, Token & Image URL persisted.");
    } catch (e) {
      print("AuthProvider: Error persisting login data: $e");
    }

    if (stateChanged) {
      notifyListeners();
      if (!_userStateController.isClosed) _userStateController.add(this);
    }
  }

  Future<void> logout() async {
    bool stateChanged = (_token != null || _userId != null || _userImageUrl != null || _isLoading);

    _token = null;
    _userId = null;
    _userImageUrl = null;
    _isLoading = false;

    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _imageUrlKey);
      print("AuthProvider: User logged out, credentials cleared.");
    } catch (e) {
      print("AuthProvider: Error clearing stored credentials during logout: $e");
    }
    if(stateChanged){
      notifyListeners();
      if (!_userStateController.isClosed) _userStateController.add(this);
    }
  }

  Future<void> updateUserImageUrl(String? newImageUrl) async {
    if (_userImageUrl == newImageUrl && !_isLoading) return; // No change needed and not loading

    bool wasLoading = _isLoading;
    _userImageUrl = newImageUrl;
    _isLoading = false; // Assume image update means primary loading is done

    try {
      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        await _storage.write(key: _imageUrlKey, value: newImageUrl);
      } else {
        await _storage.delete(key: _imageUrlKey);
      }
      print("AuthProvider: Updated user image URL to '$newImageUrl' and persisted.");
    } catch (e) {
      print("AuthProvider: Error persisting updated image URL: $e");
    }
    // Notify if image changed or if it resolved an initial loading state
    if (_userImageUrl != newImageUrl || wasLoading) {
      notifyListeners();
      if (!_userStateController.isClosed) _userStateController.add(this);
    }
  }
}