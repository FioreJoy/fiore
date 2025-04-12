// services/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  DateTime? _tokenExpiryDate;
  Timer? _autoLogoutTimer;
  
  // Keys for SharedPreferences storage
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _expiryDateKey = 'token_expiry';
  
  // Session timeout in hours (adjust as needed)
  static const int _sessionTimeout = 24;

  String? get token => _token;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null && !isTokenExpired();
  
  // Check if token is expired
  bool isTokenExpired() {
    if (_tokenExpiryDate == null) return true;
    return DateTime.now().isAfter(_tokenExpiryDate!);
  }
  
  // Initialize from shared preferences (call on app startup)
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if token exists in storage
    if (!prefs.containsKey(_tokenKey)) {
      return false;
    }
    
    // Retrieve stored data
    final String? storedToken = prefs.getString(_tokenKey);
    final String? storedUserId = prefs.getString(_userIdKey);
    final String? expiryDateStr = prefs.getString(_expiryDateKey);
    
    // Parse expiry date if it exists
    final DateTime? expiryDate = expiryDateStr != null 
      ? DateTime.tryParse(expiryDateStr) 
      : null;
    
    // Validate data
    if (storedToken == null || storedUserId == null || expiryDate == null) {
      return false;
    }
    
    // Check if token is expired
    if (DateTime.now().isAfter(expiryDate)) {
      // Clear expired token
      await _clearStoredAuthData();
      return false;
    }
    
    // Set data and start timer
    _token = storedToken;
    _userId = storedUserId;
    _tokenExpiryDate = expiryDate;
    
    // Set auto-logout timer
    _setAutoLogoutTimer();
    
    notifyListeners();
    return true;
  }

  // Set auth token with expiry time
  Future<void> setAuthToken(String? token, {DateTime? expiryDate}) async {
    _token = token;
    
    if (token != null) {
      // If expiry date is not provided, set default expiry (24 hours from now)
      _tokenExpiryDate = expiryDate ?? DateTime.now().add(Duration(hours: _sessionTimeout));
      
      // Save to persistent storage
      await _saveAuthData();
      
      // Set auto-logout timer
      _setAutoLogoutTimer();
    } else {
      // If token is null, clear stored data
      await _clearStoredAuthData();
      _tokenExpiryDate = null;
      
      // Cancel any existing auto-logout timer
      _cancelAutoLogoutTimer();
    }
    
    notifyListeners();
  }

  // Set user ID
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    
    if (userId != null && _token != null) {
      // Save to persistent storage
      await _saveAuthData();
    } else if (userId == null) {
      // Clear stored user ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
    }
    
    notifyListeners();
  }

  // Logout user
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _tokenExpiryDate = null;
    
    // Clear stored auth data
    await _clearStoredAuthData();
    
    // Cancel auto-logout timer
    _cancelAutoLogoutTimer();
    
    notifyListeners();
  }
  
  // Extend session (call this when user performs significant actions)
  Future<void> extendSession() async {
    if (_token != null && _userId != null) {
      // Set new expiry time (24 hours from now)
      _tokenExpiryDate = DateTime.now().add(Duration(hours: _sessionTimeout));
      
      // Save to persistent storage
      await _saveAuthData();
      
      // Reset auto-logout timer
      _setAutoLogoutTimer();
      
      notifyListeners();
    }
  }
  
  // Save auth data to persistent storage
  Future<void> _saveAuthData() async {
    if (_token == null || _userId == null || _tokenExpiryDate == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userIdKey, _userId!);
    await prefs.setString(_expiryDateKey, _tokenExpiryDate!.toIso8601String());
  }
  
  // Clear stored auth data
  Future<void> _clearStoredAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_expiryDateKey);
  }
  
  // Set auto-logout timer
  void _setAutoLogoutTimer() {
    // Cancel any existing timer
    _cancelAutoLogoutTimer();
    
    if (_tokenExpiryDate != null) {
      final timeToExpiry = _tokenExpiryDate!.difference(DateTime.now());
      
      // Only set timer if expiry is in the future
      if (timeToExpiry.inSeconds > 0) {
        _autoLogoutTimer = Timer(timeToExpiry, logout);
      }
    }
  }
  
  // Cancel auto-logout timer
  void _cancelAutoLogoutTimer() {
    if (_autoLogoutTimer != null) {
      _autoLogoutTimer!.cancel();
      _autoLogoutTimer = null;
    }
  }
  
  @override
  void dispose() {
    _cancelAutoLogoutTimer();
    super.dispose();
  }
}