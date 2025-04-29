import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart'; // Import your custom ApiClient here

class AuthProvider with ChangeNotifier {
  String? _token;
  int? _userId;
  String? _userImageUrl;
  bool _isTryingAutoLogin = true;

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  static const _userIdKey = 'userId';
  static const _imageUrlKey = 'userImageUrl';

  // Replace the simple http.Client with your custom ApiClient
  final ApiClient _apiClient = ApiClient(); // Use your ApiClient

  AuthProvider() {
    _tryAutoLogin();
  }

  // --- Getters ---
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  int? get userId => _userId;
  String? get userImageUrl => _userImageUrl;
  bool get isTryingAutoLogin => _isTryingAutoLogin;
  bool get isLoading => _isTryingAutoLogin;

  // Getter for apiClient
  ApiClient get apiClient => _apiClient;

  Future<void> loadToken() async => await _tryAutoLogin();

  // --- Actions ---
  Future<void> loginSuccess(String token, int userId, String? imageUrl) async {
    _token = token;
    _userId = userId;
    _userImageUrl = imageUrl;

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId.toString());
      if (imageUrl != null) {
        await _storage.write(key: _imageUrlKey, value: imageUrl);
      } else {
        await _storage.delete(key: _imageUrlKey);
      }
      print("AuthProvider: Login Success Persisted - User: $userId");

      // Use the ApiClient to set the token
      _apiClient.setAuthToken(token);
    } catch (e) {
      print("AuthProvider: Error during login storage: $e");
    }

    _isTryingAutoLogin = false;
    notifyListeners();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final storedToken = await _storage.read(key: _tokenKey);
      final storedUserId = await _storage.read(key: _userIdKey);
      final storedImageUrl = await _storage.read(key: _imageUrlKey);

      if (storedToken != null && storedUserId != null) {
        _token = storedToken;
        _userId = int.tryParse(storedUserId);
        _userImageUrl = storedImageUrl;
        print("AuthProvider: Auto-login successful for User: $storedUserId");

        // Use the ApiClient to set the token
        _apiClient.setAuthToken(storedToken);
      } else {
        print("AuthProvider: No credentials found for auto-login.");
        _token = null;
        _userId = null;
        _userImageUrl = null;
      }
    } catch (e) {
      print("AuthProvider: Error during auto-login: $e");
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

    // Clear the token from ApiClient
    _apiClient.setAuthToken(null);

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
