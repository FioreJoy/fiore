// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Updated Screen Imports ---
import 'screens/auth/login_screen.dart'; // Updated path
import 'screens/main_navigation_screen.dart'; // Updated path for main container

// Service Imports (Corrected paths)
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

// Theme Imports
import 'theme/theme_constants.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';
// Constants
import 'app_constants.dart';

void main() {
  // Ensure environment variables are available (optional check)
  const apiKey = String.fromEnvironment('API_KEY');
  const wsUrl = String.fromEnvironment('WS_BASE_URL');
  if (apiKey.isEmpty || wsUrl.isEmpty) {
    print("FATAL: API_KEY or WS_BASE_URL environment variable not provided during build.");
    // Handle error appropriately
  }

  runApp(
    MultiProvider(
      providers: [
        // --- Core Providers ---
        Provider<ApiClient>(create: (_) => ApiClient(), dispose: (_, client) => client.dispose()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        Provider<WebSocketService>(create: (_) => WebSocketService(), dispose: (_, service) => service.dispose()),

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

        // --- UI State Notifiers ---
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

// ThemeNotifier class (keep as is)
class ThemeNotifier with ChangeNotifier {
  ThemeData _themeData;
  ThemeNotifier() : _themeData = darkTheme();
  ThemeData getTheme() => _themeData;
  void setTheme(ThemeData themeData) { _themeData = themeData; notifyListeners(); }
  void toggleTheme() { _themeData = (_themeData == lightTheme()) ? darkTheme() : lightTheme(); notifyListeners(); }
  bool get isDarkMode => _themeData == darkTheme();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: AppConstants.appName,
          theme: themeNotifier.getTheme(),
          debugShowCheckedModeBanner: false,
          // The home logic remains the same, checking auth state
          home: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isTryingAutoLogin) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // Navigate to MainNavigationScreen if authenticated, else LoginScreen
              return authProvider.isAuthenticated
                  ? const MainNavigationScreen() // <-- Use the screen from its new file
                  : const LoginScreen(); // <-- Use screen from its new path
            },
          ),
          // Define named routes for easier navigation (optional but recommended)
          routes: {
            '/login': (context) => const LoginScreen(),
            '/main': (context) => const MainNavigationScreen(),
            // Define routes for other screens if needed, e.g.:
            // '/signup': (context) => const SignUpScreen(), // From screens/auth/
            // '/settings': (context) => const SettingsHomeScreen(), // From screens/settings/
            // ... etc
          },
          // Set initialRoute if using named routes extensively
          // initialRoute: '/', // Define what '/' maps to (e.g., the auth check)
        );
      },
    );
  }
}

// NOTE: The MainNavigationScreen widget and its state (_MainNavigationScreenState)
// have been MOVED to frontend/lib/screens/main_navigation_screen.dart