// frontend/lib/services/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_palettes.dart'; // Import your AppPalette definitions
import '../theme/theme_builder.dart'; // Import the theme builder function
// Keep existing light/dark themes for now as fallbacks or if they have unique M2 style settings
import '../theme/light_theme.dart' as legacy_light_theme;
import '../theme/dark_theme.dart' as legacy_dark_theme;

class ThemeProvider with ChangeNotifier {
  static const String _themeNamePrefKey = 'themeName'; // Store theme by name
  ThemeMode _themeMode =
      ThemeMode.system; // Still used for system/light/dark toggle
  String _currentThemeName =
      'Fiore Dark'; // Default to one of your new palette names

  ThemeData _currentThemeData; // Holds the fully constructed ThemeData

  bool _isLoading = true;

  // Map of theme names to their palettes
  final Map<String, AppPalette> _availablePalettes = {
    for (var palette in allAppPalettes) palette.name: palette,
  };

  ThemeProvider()
      : _currentThemeData = buildThemeFromPalette(fioreDarkPalette) {
    // Initial theme
    print("ThemeProvider: Initializing...");
    _loadSavedTheme();
  }

  ThemeMode get themeMode => _themeMode; // For system/light/dark toggle
  ThemeData get currentTheme =>
      _currentThemeData; // The actual ThemeData to apply
  String get currentThemeName => _currentThemeName;
  List<String> get availableThemeNames => _availablePalettes.keys.toList();
  bool get isLoading => _isLoading;

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeName = prefs.getString(_themeNamePrefKey);
    final savedThemeModeString =
        prefs.getString('themeMode'); // Legacy key for ThemeMode

    print(
        "ThemeProvider: Loading saved theme. Name: $savedThemeName, Mode: $savedThemeModeString");

    if (savedThemeName != null &&
        _availablePalettes.containsKey(savedThemeName)) {
      _currentThemeName = savedThemeName;
      final selectedPalette = _availablePalettes[_currentThemeName]!;
      _currentThemeData = buildThemeFromPalette(selectedPalette);
      // Determine ThemeMode from palette's brightness for consistency if a specific theme is set
      _themeMode = selectedPalette.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
      print("ThemeProvider: Loaded theme '$_currentThemeName' from palette.");
    } else if (savedThemeModeString != null) {
      // Fallback to legacy ThemeMode if specific theme name isn't found
      // This part helps with transition from old ThemeMode setting
      if (savedThemeModeString == 'light') {
        _themeMode = ThemeMode.light;
        _currentThemeName = fioreLightPalette.name; // Default to fioreLight
        _currentThemeData = buildThemeFromPalette(fioreLightPalette);
      } else if (savedThemeModeString == 'dark') {
        _themeMode = ThemeMode.dark;
        _currentThemeName = fioreDarkPalette.name; // Default to fioreDark
        _currentThemeData = buildThemeFromPalette(fioreDarkPalette);
      } else {
        _themeMode = ThemeMode.system;
        // Determine system theme and apply corresponding fioreLight/Dark palette
        // This requires context, so it's better handled by a getter or in build method.
        // For now, default to fioreDarkPalette if system is chosen initially and no specific name
        _currentThemeName =
            fioreDarkPalette.name; // Default if system and no name
        _currentThemeData = buildThemeFromPalette(fioreDarkPalette);
      }
      print(
          "ThemeProvider: Loaded theme based on legacy ThemeMode: $_themeMode, applied: $_currentThemeName");
    } else {
      // Default to system, and apply Fiore Dark palette if system is dark, Light if system is light.
      // This default logic can be more refined. For now, just default to _currentThemeName's palette.
      final selectedPalette = _availablePalettes[_currentThemeName]!;
      _currentThemeData = buildThemeFromPalette(selectedPalette);
      _themeMode = selectedPalette.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
      print(
          "ThemeProvider: No saved theme, defaulted to '$_currentThemeName'.");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Sets a specific named theme
  Future<void> setThemeByName(String themeName) async {
    if (!_availablePalettes.containsKey(themeName)) {
      print("ThemeProvider Error: Theme name '$themeName' not found.");
      return;
    }
    if (_currentThemeName == themeName && !_isLoading) return; // No change

    _currentThemeName = themeName;
    final selectedPalette = _availablePalettes[_currentThemeName]!;
    _currentThemeData = buildThemeFromPalette(selectedPalette);
    // When a specific theme is chosen, its brightness dictates the ThemeMode
    _themeMode = selectedPalette.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeNamePrefKey, _currentThemeName);
    // Also save the equivalent ThemeMode string for compatibility or simple toggles
    await prefs.setString(
        'themeMode', _themeMode == ThemeMode.dark ? 'dark' : 'light');

    print("ThemeProvider: Theme set to '$_currentThemeName'");
    notifyListeners();
  }

  // Toggles between system, light, and dark (primarily for simple toggle switch UI)
  // This will pick the 'Fiore Light' or 'Fiore Dark' palette when mode is explicitly light/dark.
  // When mode is system, it will respect the system setting and use appropriate Fiore palette.
  Future<void> toggleSimpleTheme(ThemeMode mode) async {
    if (_themeMode == mode && _currentThemeName.startsWith("Fiore"))
      return; // No change needed if already on simple toggle

    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String themeModeStr = 'system';

    if (mode == ThemeMode.light) {
      _currentThemeName = fioreLightPalette.name;
      _currentThemeData = buildThemeFromPalette(fioreLightPalette);
      themeModeStr = 'light';
    } else if (mode == ThemeMode.dark) {
      _currentThemeName = fioreDarkPalette.name;
      _currentThemeData = buildThemeFromPalette(fioreDarkPalette);
      themeModeStr = 'dark';
    } else {
      // ThemeMode.system
      // When switching to system, we don't know the actual brightness yet.
      // We'll save 'system'. The MaterialApp will use the correct ThemeData based on platform.
      // We might need to adjust _currentThemeName and _currentThemeData here based on current platform brightness
      // or let the UI figure it out via context. For simplicity, let's set a default.
      // A better way would be to have a getter in ThemeProvider that resolves the actual theme for system.
      _currentThemeName = fioreDarkPalette
          .name; // Default to dark for system if no better logic
      _currentThemeData = buildThemeFromPalette(
          fioreDarkPalette); // This might be incorrect until next build
      print(
          "ThemeProvider: Switched to System mode. Actual theme depends on platform brightness.");
    }

    await prefs.setString(_themeNamePrefKey,
        _currentThemeName); // Save the chosen Fiore Light/Dark
    await prefs.setString(
        'themeMode', themeModeStr); // Save the ThemeMode itself

    print(
        "ThemeProvider: Simple theme toggled to $_themeMode, applied '$_currentThemeName'");
    notifyListeners();
  }

  // Legacy toggleTheme, adapted to use toggleSimpleTheme
  Future<void> toggleTheme(bool isDarkMode) async {
    await toggleSimpleTheme(isDarkMode ? ThemeMode.dark : ThemeMode.light);
  }

  // Getter to resolve actual ThemeData for ThemeMode.system
  ThemeData getSystemResolvedTheme(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      final platformBrightness = MediaQuery.platformBrightnessOf(context);
      final systemPalette = platformBrightness == Brightness.dark
          ? fioreDarkPalette
          : fioreLightPalette;
      return buildThemeFromPalette(systemPalette);
    }
    return _currentThemeData; // Return already resolved theme if not system
  }
}
