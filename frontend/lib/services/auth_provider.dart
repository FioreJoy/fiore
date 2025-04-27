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

  AuthProvider() {
    _tryAutoLogin();
  }

  // --- Getters ---
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get userImageUrl => _userImageUrl;
  bool get isTryingAutoLogin => _isTryingAutoLogin;

  // <<< ADD THIS for compatibility >>>
  bool get isLoading => _isTryingAutoLogin;
  Future<void> loadToken() async => await _tryAutoLogin();
  // <<< ADD ENDS >>>

  // --- Actions ---

  Future<void> loginSuccess(String token, String userId, String? imageUrl) async {
    _token = token;
    _userId = userId;
    _userImageUrl = imageUrl;

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (imageUrl != null) {
      await _storage.write(key: _imageUrlKey, value: imageUrl);
    } else {
      await _storage.delete(key: _imageUrlKey);
    }

    _isTryingAutoLogin = false;
    print("AuthProvider: Login Success Persisted - User: $userId");
    notifyListeners();
  }

  Future<void> _tryAutoLogin() async {
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
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userImageUrl = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _imageUrlKey);
    print("AuthProvider: User logged out.");

    if (_isTryingAutoLogin) {
      _isTryingAutoLogin = false;
    }
    notifyListeners();
  }

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
