import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Removed ApiService import for now to keep it focused on auth state

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userImageUrl; // Store user image URL from login/profile fetch
  bool _isTryingAutoLogin = true;

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  static const _userIdKey = 'userId';
  static const _imageUrlKey = 'userImageUrl';

  AuthProvider() {
    _tryAutoLogin();
  }

  // --- Getters ---
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId; // Keep as String, parse to int where needed
  String? get userImageUrl => _userImageUrl;
  bool get isTryingAutoLogin => _isTryingAutoLogin;

  // --- Actions ---

  /// Stores authentication details after a successful login or signup.
  Future<void> loginSuccess(String token, String userId, String? imageUrl) async {
    _token = token;
    _userId = userId;
    _userImageUrl = imageUrl; // Store potentially updated image URL

    // Persist to secure storage
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (imageUrl != null) {
      await _storage.write(key: _imageUrlKey, value: imageUrl);
    } else {
      // Ensure old value is removed if new one is null
      await _storage.delete(key: _imageUrlKey);
    }

    _isTryingAutoLogin = false; // No longer trying if we just logged in
    print("AuthProvider: Login Success Persisted - User: $userId");
    notifyListeners();
  }

  /// Attempts to load authentication details from storage on app startup.
  Future<void> _tryAutoLogin() async {
    final storedToken = await _storage.read(key: _tokenKey);
    final storedUserId = await _storage.read(key: _userIdKey);
    final storedImageUrl = await _storage.read(key: _imageUrlKey);

    if (storedToken != null && storedUserId != null) {
      // Basic check: Assume token is valid if present.
      // For production, add a check here: call an API endpoint (like /auth/me)
      // to verify the token is still valid before setting the state.
      // If invalid, call logout() here.
      _token = storedToken;
      _userId = storedUserId;
      _userImageUrl = storedImageUrl;
      print("AuthProvider: Auto-login successful for User: $storedUserId");
    } else {
      print("AuthProvider: No credentials found for auto-login.");
      // Ensure state is cleared if no credentials found
      _token = null;
      _userId = null;
      _userImageUrl = null;
    }
    _isTryingAutoLogin = false; // Mark attempt as finished
    notifyListeners(); // Notify listeners regardless of success/failure
  }

  /// Clears authentication details and notifies listeners.
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userImageUrl = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _imageUrlKey);
    print("AuthProvider: User logged out.");
    // Ensure auto-login flag isn't stuck on true if logout happens during startup
    if (_isTryingAutoLogin) {
      _isTryingAutoLogin = false;
    }
    notifyListeners();
  }

  /// Allows updating the stored user image URL (e.g., after profile update)
  /// without requiring a full re-login.
  Future<void> updateUserImageUrl(String? newImageUrl) async {
    if (_userImageUrl != newImageUrl) {
      _userImageUrl = newImageUrl;
      if (newImageUrl != null) {
        await _storage.write(key: _imageUrlKey, value: newImageUrl);
      } else {
        await _storage.delete(key: _imageUrlKey);
      }
      print("AuthProvider: Updated user image URL.");
      notifyListeners();
    }
  }
}