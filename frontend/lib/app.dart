import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Core Imports ---
import 'app_constants.dart';
import 'core/theme/app_palettes.dart'; // For initial default palette AND list of palettes
import 'core/theme/theme_provider.dart'; // Path to theme_provider.dart
import 'core/theme/theme_builder.dart'; // Path to theme_builder.dart

// --- Presentation Layer (Providers & Screens) ---
import 'presentation/providers/auth_provider.dart';
// Import initial screens (login and main navigation)
import 'presentation/features/auth/screens/login_screen.dart'; // Corrected path
import 'presentation/features/common/screens/main_navigation_screen.dart'; // Corrected path

class FioreApp extends StatelessWidget {
  const FioreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    if (authProvider.isLoading || themeProvider.isLoading) {
      // Use a very basic theme for the initial loading screen if themeProvider's theme isn't ready
      ThemeData initialLoadingTheme;
      try {
        // Attempt to use the current theme from themeProvider if available (even if it's just a default)
        // This might still be the case if themeProvider finished loading before authProvider
        initialLoadingTheme = themeProvider.currentTheme;
      } catch (_) {
        // Fallback if themeProvider.currentTheme itself throws an error during very early init
        initialLoadingTheme =
            ThemeData.dark(useMaterial3: true); // Basic fallback
      }

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: initialLoadingTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    ThemeData themeToApply;
    ThemeData darkThemeToApply;

    // Determine effective light and dark themes based on ThemeProvider
    final AppPalette lightPaletteForMaterialApp = allAppPalettes.firstWhere(
        (p) => p.name == "Fiore Light",
        orElse: () => fioreLightPalette // Ensure a fallback
        );
    final AppPalette darkPaletteForMaterialApp = allAppPalettes.firstWhere(
        (p) => p.name == "Fiore Dark",
        orElse: () => fioreDarkPalette // Ensure a fallback
        );

    // This is the theme for the light mode slot
    themeToApply = buildThemeFromPalette(lightPaletteForMaterialApp);
    // This is the theme for the dark mode slot
    darkThemeToApply = buildThemeFromPalette(darkPaletteForMaterialApp);

    // If a specific custom theme (not "Fiore Light" or "Fiore Dark") is selected,
    // ThemeProvider.currentTheme already holds the ThemeData built from that custom palette.
    // We need to assign it to the correct slot (theme or darkTheme) based on its brightness.
    if (themeProvider.currentThemeName != lightPaletteForMaterialApp.name &&
        themeProvider.currentThemeName != darkPaletteForMaterialApp.name &&
        themeProvider.themeMode != ThemeMode.system) {
      if (themeProvider.currentTheme.brightness == Brightness.dark) {
        darkThemeToApply =
            themeProvider.currentTheme; // The custom theme is dark
        // themeToApply remains the default "Fiore Light" for the light slot
      } else {
        themeToApply = themeProvider.currentTheme; // The custom theme is light
        // darkThemeToApply remains the default "Fiore Dark" for the dark slot
      }
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: themeToApply, // Light theme OR custom light theme
      darkTheme: darkThemeToApply, // Dark theme OR custom dark theme
      home: authProvider.isAuthenticated
          ? const MainNavigationScreen()
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigationScreen(),
      },
    );
  }
}
