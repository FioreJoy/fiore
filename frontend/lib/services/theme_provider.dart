// frontend/lib/services/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themePrefKey = 'themeMode';
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  bool _isLoading = true;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading; // Expose loading state if needed elsewhere

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themePrefKey);

    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system; // Default or if null/invalid
    }
    _isLoading = false;
    notifyListeners(); // Notify listeners after loading
    print("Theme loaded: $_themeMode"); // Debug log
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, isDarkMode ? 'dark' : 'light');
    print("Theme set to: $_themeMode"); // Debug log
    notifyListeners();
  }

  // Optional: Method to set theme explicitly if needed
  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return; // No change

    _themeMode = themeMode;
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (themeMode == ThemeMode.dark) {
      themeString = 'dark';
    } else if (themeMode == ThemeMode.light) {
      themeString = 'light';
    }
    await prefs.setString(_themePrefKey, themeString);
    print("Theme explicitly set to: $_themeMode"); // Debug log
    notifyListeners();
  }
}