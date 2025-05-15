import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Screen Imports ---
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';

// --- Service Imports ---
import 'services/auth_provider.dart';
import 'services/api_client.dart';
import 'services/websocket_service.dart';
import 'services/api/auth_service.dart';
import 'services/api/user_service.dart';
import 'services/api/community_service.dart';
import 'services/api/event_service.dart';
import 'services/api/post_service.dart';
import 'services/api/reply_service.dart';
import 'services/api/vote_service.dart';
import 'services/api/chat_service.dart';
import 'services/api/settings_service.dart';
import 'services/api/block_service.dart';
import 'services/api/location_service.dart';
import 'services/api/favorite_service.dart';
import 'services/api/notification_service.dart';
import 'services/notification_provider.dart';

// --- Theme Imports ---
import 'services/theme_provider.dart';
import 'theme/app_palettes.dart';    // Import AppPalette definitions
import 'theme/theme_builder.dart'; // Import the theme builder function

// --- App Constants ---
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, apiClient) => apiClient.dispose(),
        ),
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
          dispose: (_, wsService) => wsService.dispose(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ProxyProvider<ApiClient, AuthService>(
          update: (_, apiClient, __) => AuthService(apiClient),
        ),
        ProxyProvider<ApiClient, UserService>(
          update: (_, apiClient, __) => UserService(apiClient),
        ),
        ProxyProvider<ApiClient, CommunityService>(
          update: (_, apiClient, __) => CommunityService(apiClient),
        ),
        ProxyProvider<ApiClient, EventService>(
          update: (_, apiClient, __) => EventService(apiClient),
        ),
        ProxyProvider<ApiClient, PostService>(
          update: (_, apiClient, __) => PostService(apiClient),
        ),
        ProxyProvider<ApiClient, ReplyService>(
          update: (_, apiClient, __) => ReplyService(apiClient),
        ),
        ProxyProvider<ApiClient, VoteService>(
          update: (_, apiClient, __) => VoteService(apiClient),
        ),
        ProxyProvider<ApiClient, FavoriteService>(
          update: (_, apiClient, __) => FavoriteService(apiClient),
        ),
        ProxyProvider<ApiClient, ChatService>(
          update: (_, apiClient, __) => ChatService(apiClient),
        ),
        ProxyProvider<ApiClient, SettingsService>(
          update: (_, apiClient, __) => SettingsService(apiClient),
        ),
        ProxyProvider<ApiClient, BlockService>(
          update: (_, apiClient, __) => BlockService(apiClient),
        ),
        ProxyProvider<ApiClient, NotificationService>(
          update: (_, apiClient, __) => NotificationService(apiClient),
        ),
        ChangeNotifierProxyProvider2<NotificationService, AuthProvider, NotificationProvider>(
          create: (context) {
            final notificationService = context.read<NotificationService>();
            final authProviderForNotif = context.read<AuthProvider>();
            return NotificationProvider(notificationService, authProviderForNotif);
          },
          update: (context, notificationService, authProviderForNotif, previousNotificationProvider) {
            return NotificationProvider(notificationService, authProviderForNotif);
          },
        ),
      ],
      child: const FioreApp(),
    ),
  );
}

class FioreApp extends StatelessWidget {
  const FioreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    if (authProvider.isLoading || themeProvider.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    ThemeData themeToApply;
    ThemeData darkThemeToApply;

    // If a specific named theme is selected, ThemeProvider.currentTheme already holds the correct ThemeData
    // and ThemeProvider.themeMode reflects its brightness.
    if (themeProvider.currentThemeName != fioreLightPalette.name &&
        themeProvider.currentThemeName != fioreDarkPalette.name &&
        themeProvider.themeMode != ThemeMode.system) {
      // A custom palette is active
      themeToApply = themeProvider.currentTheme; // This IS the custom theme
      // For MaterialApp, if currentTheme is dark, it should go to darkTheme slot.
      // If currentTheme is light, it goes to theme slot.
      // This logic is a bit redundant if themeMode is correctly set by ThemeProvider.
      if (themeProvider.currentTheme.brightness == Brightness.dark) {
        darkThemeToApply = themeProvider.currentTheme;
        themeToApply = buildThemeFromPalette(fioreLightPalette); // Default light
      } else {
        darkThemeToApply = buildThemeFromPalette(fioreDarkPalette); // Default dark
      }
    } else {
      // Using system, or explicit Fiore Light/Dark via simple toggle
      themeToApply = buildThemeFromPalette(fioreLightPalette);
      darkThemeToApply = buildThemeFromPalette(fioreDarkPalette);
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: themeToApply,
      darkTheme: darkThemeToApply,
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