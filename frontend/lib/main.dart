// frontend/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Screen Imports ---
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';

// --- Service Imports ---
import 'services/auth_provider.dart';
import 'services/websocket_service.dart'; // Import the WebSocketService
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
// Keep ApiClient import if used by ProxyProvider below

// --- Theme Imports ---
import 'services/theme_provider.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';

// --- App Constants ---
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthProvider (holds ApiClient)
  final authProvider = AuthProvider();
  await authProvider.loadToken();

  // Initialize ThemeProvider
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        // --- Core Providers ---
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),

        // --- Provide WebSocketService globally ---
        // ApiClient is accessed via AuthProvider now
        Provider<WebSocketService>(
          create: (_) => WebSocketService(), // Use parameterless constructor
          // Dispose callback is important
          dispose: (_, service) => service.dispose(),
        ),

        // --- API Service Providers using ProxyProvider ---
        // Depend on AuthProvider to get the configured ApiClient
        ProxyProvider<AuthProvider, AuthService>(
          update: (_, auth, __) => AuthService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, UserService>(
          update: (_, auth, __) => UserService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, CommunityService>(
          update: (_, auth, __) => CommunityService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, EventService>(
          update: (_, auth, __) => EventService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, PostService>(
          update: (_, auth, __) => PostService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, ReplyService>(
          update: (_, auth, __) => ReplyService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, VoteService>(
          update: (_, auth, __) => VoteService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, ChatService>(
          update: (_, auth, __) => ChatService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, SettingsService>(
          update: (_, auth, __) => SettingsService(auth.apiClient),
        ),
        ProxyProvider<AuthProvider, BlockService>(
          update: (_, auth, __) => BlockService(auth.apiClient),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// MyApp class remains the same as the previous version
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    if (authProvider.isLoading || themeProvider.isLoading) {
      return const MaterialApp(/* Loading Screen */);
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
      routes: const { /* routes */ },
    );
  }
}