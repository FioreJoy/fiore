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


// --- Theme Imports ---
import 'services/theme_provider.dart'; // <- New ThemeProvider
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';

// --- App Constants ---
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthProvider and wait for token
  final authProvider = AuthProvider();
  await authProvider.loadToken();

  // Initialize ThemeProvider
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        // --- Core Providers ---
        Provider<ApiClient>(create: (_) => ApiClient(), dispose: (_, client) => client.dispose()),
        Provider<WebSocketService>(create: (_) => WebSocketService(), dispose: (_, service) => service.dispose()),
        Provider<LocationService>(create: (_) => LocationService()), // Add this line

        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),

        // --- API Service Providers ---
        ProxyProvider<ApiClient, AuthService>(update: (_, apiClient, __) => AuthService(apiClient)),
        ProxyProvider<ApiClient, UserService>(update: (_, apiClient, __) => UserService(apiClient)),
        ProxyProvider<ApiClient, CommunityService>(update: (_, apiClient, __) => CommunityService(apiClient)),
        ProxyProvider<ApiClient, EventService>(update: (_, apiClient, __) => EventService(apiClient)),
        ProxyProvider<ApiClient, PostService>(update: (_, apiClient, __) => PostService(apiClient)),
        ProxyProvider<ApiClient, ReplyService>(update: (_, apiClient, __) => ReplyService(apiClient)),
        ProxyProvider<ApiClient, VoteService>(update: (_, apiClient, __) => VoteService(apiClient)),
        ProxyProvider<ApiClient, ChatService>(update: (_, apiClient, __) => ChatService(apiClient)),
        ProxyProvider<ApiClient, SettingsService>(update: (_, apiClient, __) => SettingsService(apiClient)),
        ProxyProvider<ApiClient, BlockService>(update: (_, apiClient, __) => BlockService(apiClient)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigationScreen(),
        // Add more routes here if needed
      },
    );
  }
}
