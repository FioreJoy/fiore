// frontend/lib/main.dart
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
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';

// --- App Constants ---
import 'app_constants.dart'; // For AppConstants.appName

void main() async {
  // Ensure Flutter binding is initialized for async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize providers that need async initialization BEFORE runApp
  // AuthProvider handles its own async _tryAutoLogin in its constructor.
  // ThemeProvider handles its own async _loadTheme in its constructor.
  final authProvider = AuthProvider();
  final themeProvider = ThemeProvider();

  // Wait for initial loading to complete to avoid flicker or race conditions
  // A better approach might be a splash screen that waits for these futures.
  // For now, a simple await if these providers expose a "ready" future.
  // Since AuthProvider loads in constructor and isLoading handles UI, this is okay.

  runApp(
    MultiProvider(
      providers: [
        // --- Foundational Services (Singletons, no UI state change) ---
        // ApiClient is provided once and used by other API services.
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, apiClient) => apiClient.dispose(), // Ensure client is closed
        ),
        // WebSocketService: Manages its own lifecycle, provided as a singleton.
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
          dispose: (_, wsService) => wsService.dispose(),
        ),
        // LocationService: For Nominatim/Photon, no internal state tied to ApiClient.
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),

        // --- State Management Providers (ChangeNotifier) ---
        // AuthProvider manages authentication state and notifies UI.
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        // ThemeProvider manages theme state and notifies UI.
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),

        // --- API Service Providers (Depend on ApiClient, stateless themselves) ---
        // Use ProxyProvider to inject ApiClient into these services.
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

        // --- Complex State Providers (Depend on other services/providers) ---
        // NotificationProvider depends on NotificationService and AuthProvider.
        ChangeNotifierProxyProvider2<NotificationService, AuthProvider, NotificationProvider>(
          create: (context) {
            final notificationService = context.read<NotificationService>();
            final authProviderForNotif = context.read<AuthProvider>();
            print("Main: Creating NotificationProvider with NotificationService: ${notificationService.runtimeType}, AuthProvider: ${authProviderForNotif.runtimeType}");
            return NotificationProvider(notificationService, authProviderForNotif);
          },
          update: (context, notificationService, authProviderForNotif, previousNotificationProvider) {
            print("Main: Updating NotificationProvider. Auth isAuthenticated: ${authProviderForNotif.isAuthenticated}");
            // Re-create NotificationProvider if dependencies change,
            // or update existing one if it supports it.
            // Here, we create a new one to ensure fresh state with new dependencies.
            return NotificationProvider(notificationService, authProviderForNotif);
          },
          // dispose: (_, provider) => provider.dispose(), // Add if NotificationProvider has a dispose method
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch providers to rebuild MyApp when their state changes.
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    print("MyApp build: Auth isLoading: ${authProvider.isLoading}, Auth isAuthenticated: ${authProvider.isAuthenticated}, Theme isLoading: ${themeProvider.isLoading}");

    // Show a loading screen while initial auth and theme are loading.
    if (authProvider.isLoading || themeProvider.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: authProvider.isAuthenticated
          ? const MainNavigationScreen()
          : const LoginScreen(),
      routes: {
        // Define named routes for cleaner navigation if needed
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigationScreen(),
        // Add other routes here
      },
    );
  }
}