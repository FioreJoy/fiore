// frontend/lib/theme/app_palettes.dart
import 'package:flutter/material.dart';

// Defines the structure for a color palette
class AppPalette {
  final String name;
  final Brightness brightness;

  final Color primary;
  final Color secondary;
  final Color tertiary;

  final Color background;
  final Color surface;
  final Color surfaceVariant;

  final Color error;

  final Color onPrimary;
  final Color onSecondary;
  final Color onTertiary;
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onError;

  // Corrected field names
  final Color outlineButtonForeground;
  final Color outlineButtonBorder;

  final Color chipBackground;
  final Color chipSelectedBackground;
  final Color chipLabel;
  final Color chipSelectedLabel;
  
  final Color bottomNavBackground;
  final Color bottomNavSelected;
  final Color bottomNavUnselected;

  final Color divider;

  const AppPalette({
    required this.name,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onError,
    required this.outlineButtonForeground, // Corrected
    required this.outlineButtonBorder,    // Corrected
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.chipLabel,
    required this.chipSelectedLabel,
    required this.bottomNavBackground,
    required this.bottomNavSelected,
    required this.bottomNavUnselected,
    required this.divider,
  });
}

// --- Define Specific Palettes ---

// Existing Fiore Light (approximated from light_theme.dart)
const AppPalette fioreLightPalette = AppPalette(
  name: "Fiore Light",
  brightness: Brightness.light,
  primary: Color(0xFF1B1F3B), // Midnight Blue
  secondary: Color(0xFF00FFFF), // Cyan
  tertiary: Color(0xFFFFDD44), // Yellow
  background: Color(0xFFF0F2F5), 
  surface: Colors.white,
  surfaceVariant: Color(0xFFE8EAF6), 
  error: Color(0xFFB00020), 
  onPrimary: Colors.white,
  onSecondary: Color(0xFF1B1F3B), 
  onTertiary: Color(0xFF1B1F3B), 
  onBackground: Color(0xFF1C1B1F), 
  onSurface: Color(0xFF1C1B1F), 
  onSurfaceVariant: Color(0xFF49454F), 
  onError: Colors.white,
  outlineButtonForeground: Color(0xFF1B1F3B), // Corrected
  outlineButtonBorder: Color(0xFF00FFFF),    // Corrected
  chipBackground: Color(0xFFE8EAF6),
  chipSelectedBackground: Color(0xFF00FFFF),
  chipLabel: Color(0xFF1B1F3B),
  chipSelectedLabel: Color(0xFF1B1F3B),
  bottomNavBackground: Colors.white,
  bottomNavSelected: Color(0xFF00FFFF),
  bottomNavUnselected: Color(0xFF757575), // Colors.grey
  divider: Color(0xFFDCDCDC),
);

// Existing Fiore Dark (approximated from dark_theme.dart)
const AppPalette fioreDarkPalette = AppPalette(
  name: "Fiore Dark",
  brightness: Brightness.dark,
  primary: Color(0xFF1B1F3B), 
  secondary: Color(0xFF00FFFF), 
  tertiary: Color(0xFFFFDD44), 
  background: Color(0xFF050714), 
  surface: Color(0xFF0A0C18),    
  surfaceVariant: Color(0xFF121426), 
  error: Color(0xFFCF6679), 
  onPrimary: Colors.white,
  onSecondary: Color(0xFF050714), 
  onTertiary: Color(0xFF050714), 
  onBackground: Color(0xFFE1E3E6), 
  onSurface: Color(0xFFE1E3E6), 
  onSurfaceVariant: Color(0xFFCAC4D0), 
  onError: Colors.black,
  outlineButtonForeground: Color(0xFF00FFFF), // Corrected
  outlineButtonBorder: Color(0xFF00FFFF),    // Corrected
  chipBackground: Color(0xFF121426),
  chipSelectedBackground: Color(0xFF00FFFF),
  chipLabel: Color(0xFFE1E3E6),
  chipSelectedLabel: Color(0xFF050714),
  bottomNavBackground: Color(0xFF0A0C18),
  bottomNavSelected: Color(0xFF00FFFF),
  bottomNavUnselected: Color(0xFF757575), // Colors.grey
  divider: Color(0x1FFFFFFF), 
);

// Forest Calm
const AppPalette forestCalmPalette = AppPalette(
  name: "Forest Calm",
  brightness: Brightness.dark,
  primary: Color(0xFF2E4030),        
  secondary: Color(0xFF6B8E23),       
  tertiary: Color(0xFFDAA520),        
  background: Color(0xFF1A2A1C),     
  surface: Color(0xFF223024),        
  surfaceVariant: Color(0xFF2E4030),  
  error: Color(0xFFD32F2F),
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onTertiary: Color(0xFF2E4030),
  onBackground: Color(0xFFE0E0E0),
  onSurface: Color(0xFFF5F5F5),
  onSurfaceVariant: Color(0xFFE0E0E0), 
  onError: Colors.white,
  outlineButtonForeground: Color(0xFFDAA520), // Corrected
  outlineButtonBorder: Color(0xFFDAA520),    // Corrected
  chipBackground: Color(0xFF3A4D32),
  chipSelectedBackground: Color(0xFF6B8E23),
  chipLabel: Color(0xFFE0E0E0),
  chipSelectedLabel: Colors.white,
  bottomNavBackground: Color(0xFF1F2E21),
  bottomNavSelected: Color(0xFFDAA520),
  bottomNavUnselected: Color(0xFFA0A0A0),
  divider: Color(0x803A4D32), 
);

// Joy Navy
const AppPalette joyNavyPalette = AppPalette(
  name: "Joy Navy",
  brightness: Brightness.dark,
  primary: Color(0xFF001F54),        
  secondary: Color(0xFFFF6F61),       
  tertiary: Color(0xFFF7C548),        
  background: Color(0xFF030C1E),     
  surface: Color(0xFF0A1931),        
  surfaceVariant: Color(0xFF183A5A),  
  error: Color(0xFFE57373),
  onPrimary: Colors.white,
  onSecondary: Colors.black,
  onTertiary: Color(0xFF001F54),
  onBackground: Color(0xFFEAEAEA),
  onSurface: Color(0xFFF0F0F0),
  onSurfaceVariant: Color(0xFFEAEAEA),
  onError: Colors.white,
  outlineButtonForeground: Color(0xFFF7C548), // Corrected
  outlineButtonBorder: Color(0xFFF7C548),    // Corrected
  chipBackground: Color(0xFF183A5A),
  chipSelectedBackground: Color(0xFFFF6F61),
  chipLabel: Color(0xFFE0E0E0),
  chipSelectedLabel: Colors.black,
  bottomNavBackground: Color(0xFF071223),
  bottomNavSelected: Color(0xFFFF6F61),
  bottomNavUnselected: Color(0xFFA0A0A0),
  divider: Color(0x80183A5A),
);

// Sunset Glow
const AppPalette sunsetGlowPalette = AppPalette(
  name: "Sunset Glow",
  brightness: Brightness.dark,
  primary: Color(0xFF4A148C),        
  secondary: Color(0xFFFF7043),       
  tertiary: Color(0xFFFFCA28),        
  background: Color(0xFF22002E),     
  surface: Color(0xFF311B92),        
  surfaceVariant: Color(0xFF4527A0),  
  error: Color(0xFFEF5350),
  onPrimary: Colors.white,
  onSecondary: Colors.black,
  onTertiary: Color(0xFF4A0033),
  onBackground: Color(0xFFF5E0FF),   
  onSurface: Color(0xFFFCE4EC),      
  onSurfaceVariant: Color(0xFFF5E0FF),
  onError: Colors.white,
  outlineButtonForeground: Color(0xFFFFCA28), // Corrected
  outlineButtonBorder: Color(0xFFFFCA28),    // Corrected
  chipBackground: Color(0xFF6A1B9A),
  chipSelectedBackground: Color(0xFFFF7043),
  chipLabel: Color(0xFFF5E0FF),
  chipSelectedLabel: Colors.black,
  bottomNavBackground: Color(0xFF2A0D35),
  bottomNavSelected: Color(0xFFFFCA28),
  bottomNavUnselected: Color(0xFFD1C4E9),
  divider: Color(0x666A1B9A),
);

// Oceanic Breeze
const AppPalette oceanicBreezePalette = AppPalette(
  name: "Oceanic Breeze",
  brightness: Brightness.light,
  primary: Color(0xFF0077B6),        
  secondary: Color(0xFF00B4D8),       
  tertiary: Color(0xFFFF8A65),        
  background: Color(0xFFE0F7FA),     
  surface: Colors.white,
  surfaceVariant: Color(0xFFB3E5FC),  
  error: Color(0xFFD32F2F),
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onTertiary: Colors.black,
  onBackground: Color(0xFF003B46),   
  onSurface: Color(0xFF002329),
  onSurfaceVariant: Color(0xFF004250), 
  onError: Colors.white,
  outlineButtonForeground: Color(0xFF0077B6), // Corrected
  outlineButtonBorder: Color(0xFF0077B6),    // Corrected
  chipBackground: Color(0xFFB3E5FC),
  chipSelectedBackground: Color(0xFF0077B6),
  chipLabel: Color(0xFF004250),
  chipSelectedLabel: Colors.white,
  bottomNavBackground: Colors.white,
  bottomNavSelected: Color(0xFF0077B6),
  bottomNavUnselected: Color(0xFF90A4AE), // Colors.blueGrey.shade400
  divider: Color(0xFFB0BEC5), 
);

// Monochrome Slate
const AppPalette monochromeSlatePalette = AppPalette(
  name: "Monochrome Slate",
  brightness: Brightness.dark,
  primary: Color(0xFF37474F),        
  secondary: Color(0xFF00E5FF),       
  tertiary: Color(0xFFB0BEC5),        
  background: Color(0xFF212121),     
  surface: Color(0xFF303030),        
  surfaceVariant: Color(0xFF424242),  
  error: Color(0xFFFF5252),          
  onPrimary: Colors.white,
  onSecondary: Colors.black,
  onTertiary: Color(0xFF212121),
  onBackground: Color(0xFFE0E0E0),
  onSurface: Color(0xFFF5F5F5),
  onSurfaceVariant: Color(0xFFE0E0E0),
  onError: Colors.black,
  outlineButtonForeground: Color(0xFF00E5FF), // Corrected
  outlineButtonBorder: Color(0xFF00E5FF),    // Corrected
  chipBackground: Color(0xFF424242),
  chipSelectedBackground: Color(0xFF00E5FF),
  chipLabel: Color(0xFFE0E0E0),
  chipSelectedLabel: Colors.black,
  bottomNavBackground: Color(0xFF263238), 
  bottomNavSelected: Color(0xFF00E5FF),
  bottomNavUnselected: Color(0xFF90A4AE), 
  divider: Color(0xFF424242),
);

// Retro Pop
const AppPalette retroPopPalette = AppPalette(
  name: "Retro Pop",
  brightness: Brightness.light,
  primary: Color(0xFFD95A40),        
  secondary: Color(0xFF00838F),       
  tertiary: Color(0xFFFBC02D),        
  background: Color(0xFFFFFDE7),     
  surface: Colors.white,
  surfaceVariant: Color(0xFFFFE0B2),  
  error: Color(0xFFC62828),
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onTertiary: Colors.black,
  onBackground: Color(0xFF4E342E),   
  onSurface: Color(0xFF5D4037),
  onSurfaceVariant: Color(0xFF795548), 
  onError: Colors.white,
  outlineButtonForeground: Color(0xFFD95A40), // Corrected
  outlineButtonBorder: Color(0xFFD95A40),    // Corrected
  chipBackground: Color(0xFFFFE0B2),
  chipSelectedBackground: Color(0xFFD95A40),
  chipLabel: Color(0xFF795548),
  chipSelectedLabel: Colors.white,
  bottomNavBackground: Color(0xFFFFFDF5),
  bottomNavSelected: Color(0xFFD95A40),
  bottomNavUnselected: Color(0xFFA1887F), 
  divider: Color(0xFFEFEBE9), 
);

// Sakura Blossom
const AppPalette sakuraBlossomPalette = AppPalette(
  name: "Sakura Blossom",
  brightness: Brightness.light,
  primary: Color(0xFFFFC0CB),        
  secondary: Color(0xFFD8BFD8),       
  tertiary: Color(0xFF90EE90),        
  background: Color(0xFFFFF0F5),     
  surface: Colors.white,
  surfaceVariant: Color(0xFFFAE7F3),  
  error: Color(0xFFFA8072),          
  onPrimary: Color(0xFF800000),      
  onSecondary: Color(0xFF4B0082),    
  onTertiary: Color(0xFF006400),     
  onBackground: Color(0xFF5C3A58),   
  onSurface: Color(0xFF6A4063),
  onSurfaceVariant: Color(0xFF7A5273), 
  onError: Colors.white,
  outlineButtonForeground: Color(0xFFFFC0CB), // Corrected
  outlineButtonBorder: Color(0xFFFFC0CB),    // Corrected
  chipBackground: Color(0xFFFAE7F3),
  chipSelectedBackground: Color(0xFFFFC0CB),
  chipLabel: Color(0xFF7A5273),
  chipSelectedLabel: Color(0xFF800000),
  bottomNavBackground: Colors.white,
  bottomNavSelected: Color(0xFFFFC0CB),
  bottomNavUnselected: Color(0xFFC8A2C8), 
  divider: Color(0xFFF5E3ED),
);

// Tech Noir
const AppPalette techNoirPalette = AppPalette(
  name: "Tech Noir",
  brightness: Brightness.dark,
  primary: Color(0xFF0D0D0D),        
  secondary: Color(0xFF00FFFF),       
  tertiary: Color(0xFFF02E8F),        
  background: Color(0xFF000000),     
  surface: Color(0xFF101010),        
  surfaceVariant: Color(0xFF181818),  
  error: Color(0xFFFF4444),          
  onPrimary: Color(0xFF00FFFF),      
  onSecondary: Colors.black,
  onTertiary: Colors.white,
  onBackground: Color(0xFFAAAAAA),   
  onSurface: Color(0xFFCCCCCC),
  onSurfaceVariant: Color(0xFFAAAAAA),
  onError: Colors.black,
  outlineButtonForeground: Color(0xFF00FFFF), // Corrected
  outlineButtonBorder: Color(0xFF00FFFF),    // Corrected
  chipBackground: Color(0xFF181818),
  chipSelectedBackground: Color(0xFF00FFFF),
  chipLabel: Color(0xFFAAAAAA),
  chipSelectedLabel: Colors.black,
  bottomNavBackground: Color(0xFF0A0A0A),
  bottomNavSelected: Color(0xFF00FFFF),
  bottomNavUnselected: Color(0xFF777777),
  divider: Color(0xFF222222),
);

// List of all available palettes
final List<AppPalette> allAppPalettes = [
  fioreLightPalette,
  fioreDarkPalette,
  forestCalmPalette,
  joyNavyPalette,
  sunsetGlowPalette,
  oceanicBreezePalette,
  monochromeSlatePalette,
  retroPopPalette,
  sakuraBlossomPalette,
  techNoirPalette,
];
