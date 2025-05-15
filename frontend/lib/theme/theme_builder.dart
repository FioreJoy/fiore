// frontend/lib/theme/theme_builder.dart
import 'package:flutter/material.dart';
import 'app_palettes.dart'; // Your palette definitions
import 'theme_constants.dart'; // For shared constants like borderRadius

ThemeData buildThemeFromPalette(AppPalette palette) {
  final baseTheme = palette.brightness == Brightness.dark 
                    ? ThemeData.dark(useMaterial3: true) 
                    : ThemeData.light(useMaterial3: true);

  return baseTheme.copyWith(
    primaryColor: palette.primary,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: palette.brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      tertiary: palette.tertiary,
      onTertiary: palette.onTertiary,
      error: palette.error,
      onError: palette.onError,
      background: palette.background,
      onBackground: palette.onBackground,
      surface: palette.surface,
      onSurface: palette.onSurface,
      surfaceVariant: palette.surfaceVariant,
      onSurfaceVariant: palette.onSurfaceVariant,
      outline: palette.outlineButtonBorder, // Use the border color for M3 outline
      outlineVariant: palette.divider, // Use divider for a more subtle variant
      shadow: Colors.black.withOpacity(0.15),
      surfaceTint: palette.primary.withAlpha(20), // Subtle tint for M3 surfaces
      // Inverse colors can be tricky; derive simply or use fixed fallbacks
      inverseSurface: palette.brightness == Brightness.dark 
                        ? fioreLightPalette.surface // A known light surface
                        : fioreDarkPalette.surface,  // A known dark surface
      onInverseSurface: palette.brightness == Brightness.dark 
                        ? fioreLightPalette.onSurface 
                        : fioreDarkPalette.onSurface,
      inversePrimary: palette.secondary, // Often the accent can work as inverse primary
      // Container colors
      primaryContainer: Color.alphaBlend(palette.primary.withOpacity(0.1), palette.surface),
      onPrimaryContainer: palette.onPrimary,
      secondaryContainer: Color.alphaBlend(palette.secondary.withOpacity(0.1), palette.surface),
      onSecondaryContainer: palette.onSecondary,
      tertiaryContainer: Color.alphaBlend(palette.tertiary.withOpacity(0.1), palette.surface),
      onTertiaryContainer: palette.onTertiary,
      errorContainer: Color.alphaBlend(palette.error.withOpacity(0.1), palette.surface),
      onErrorContainer: palette.onError,
      surfaceBright: Color.lerp(palette.surface, Colors.white, 0.05), // Slightly brighter surface
      surfaceDim: Color.lerp(palette.surface, Colors.black, 0.05), // Slightly dimmer surface

    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface, // Common to use surface for M3 style AppBar
      foregroundColor: palette.onSurface,
      elevation: 0.5,
      centerTitle: false,
      iconTheme: IconThemeData(color: palette.onSurface),
      actionsIconTheme: IconThemeData(color: palette.onSurface),
      titleTextStyle: TextStyle(
        color: palette.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
      ),
    ),
    cardTheme: CardTheme(
      color: palette.surface,
      elevation: 1, // M3 cards often have less elevation
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
        // M3 often uses outline or no border on cards unless specifically designed
        // side: BorderSide(color: palette.divider.withOpacity(0.5), width: 0.8), 
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.secondary, 
        foregroundColor: palette.onSecondary,
        elevation: 1, // M3 buttons are often flatter
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Poppins'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.buttonBorderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: ThemeConstants.smallPadding + 4), // M3 buttons often taller
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.outlineButtonForeground,
        side: BorderSide(color: palette.outlineButtonBorder, width: 1), // M3 outline is typically 1px
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.buttonBorderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: ThemeConstants.smallPadding + 4),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.buttonBorderRadius)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: ThemeConstants.smallPadding + 4),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceVariant.withOpacity(palette.brightness == Brightness.dark ? 0.3 : 0.5), // More subtle fill
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2), // M3 fields often less rounded
        borderSide: BorderSide(color: palette.outlineButtonBorder.withOpacity(0.7)), // Use outline color from palette
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        borderSide: BorderSide(color: palette.secondary, width: 2), 
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        borderSide: BorderSide(color: palette.outlineButtonBorder.withOpacity(0.5)),
      ),
      labelStyle: TextStyle(color: palette.onSurfaceVariant.withOpacity(0.9)),
      hintStyle: TextStyle(color: palette.onSurfaceVariant.withOpacity(0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 14), // Adjusted padding
      prefixIconColor: palette.onSurfaceVariant.withOpacity(0.7),
      suffixIconColor: palette.onSurfaceVariant.withOpacity(0.7),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.tertiary, 
      foregroundColor: palette.onTertiary,
      elevation: 2, // M3 FABs usually have less elevation
      shape: const CircleBorder(), // M3 FABs are circular by default
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.chipBackground,
      selectedColor: palette.chipSelectedBackground,
      disabledColor: palette.divider.withOpacity(0.5),
      labelStyle: TextStyle(color: palette.chipLabel),
      secondaryLabelStyle: TextStyle(color: palette.chipSelectedLabel),
      padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding + 2, vertical: ThemeConstants.smallPadding / 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5)),
      side: BorderSide(color: palette.divider.withOpacity(0.7)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.bottomNavBackground,
      selectedItemColor: palette.bottomNavSelected,
      unselectedItemColor: palette.bottomNavUnselected,
      type: BottomNavigationBarType.fixed,
      elevation: 2, // Common M3 elevation
      selectedIconTheme: IconThemeData(size: 24, color: palette.bottomNavSelected),
      unselectedIconTheme: IconThemeData(size: 24, color: palette.bottomNavUnselected),
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.bottomNavSelected),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.bottomNavUnselected),
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1, // M3 often uses 1px dividers
    ),
    iconTheme: IconThemeData(
      color: palette.onSurface, 
      size: 24,
    ),
    textTheme: baseTheme.textTheme.copyWith(
      // Copy Poppins to all text styles for consistency
      displayLarge: baseTheme.textTheme.displayLarge?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      displayMedium: baseTheme.textTheme.displayMedium?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      displaySmall: baseTheme.textTheme.displaySmall?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(color: palette.onBackground, fontFamily: 'Poppins'),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(color: palette.onSurface, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(color: palette.onSurface, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
      titleSmall: baseTheme.textTheme.titleSmall?.copyWith(color: palette.onSurface.withOpacity(0.85), fontFamily: 'Poppins', fontWeight: FontWeight.w500),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(color: palette.onBackground, fontFamily: 'Poppins', height: 1.5),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(color: palette.onBackground.withOpacity(0.85), fontFamily: 'Poppins', height: 1.4),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(color: palette.onBackground.withOpacity(0.7), fontFamily: 'Poppins', height: 1.3),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(color: palette.onSecondary, fontFamily: 'Poppins', fontWeight: FontWeight.w600), // Text on ElevatedButton
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(color: palette.outlineButtonForeground, fontFamily: 'Poppins', fontWeight: FontWeight.w500), // Text on OutlinedButton/TextButton
      labelSmall: baseTheme.textTheme.labelSmall?.copyWith(color: palette.onSurface.withOpacity(0.7), fontFamily: 'Poppins', fontWeight: FontWeight.w500),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.secondary,
      selectionColor: palette.secondary.withOpacity(0.4),
      selectionHandleColor: palette.secondary,
    ),
    useMaterial3: true, // Ensure M3 is enabled
  );
}
