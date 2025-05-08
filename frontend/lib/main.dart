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
import 'app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.loadToken();

  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()), // Removed dispose
        Provider<WebSocketService>(create: (_) => WebSocketService()), // Removed dispose
        Provider<LocationService>(create: (_) => LocationService()),

        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),

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
        ProxyProvider<ApiClient, FavoriteService>(update: (_, apiClient, __) => FavoriteService(apiClient)),

        ProxyProvider<ApiClient, NotificationService>(
          create: (context) {
            print("--- ProxyProvider: CREATE NotificationService ---");
            final apiClient = context.read<ApiClient>();
            if (apiClient == null) {
              print("  ERROR creating NotificationService: ApiClient is NULL!");
              throw StateError("ApiClient was null during NotificationService creation.");
            }
            final ns = NotificationService(apiClient);
            print("  NotificationService instance CREATED: ${ns.runtimeType}");
            return ns;
          },
          update: (context, apiClient, previous) {
            print("--- ProxyProvider: UPDATE NotificationService ---");
            if (apiClient == null) {
              print("  ERROR updating NotificationService: ApiClient is NULL!");
              throw StateError("ApiClient was null during NotificationService update.");
            }
            if (previous == null) {
              print("  previous NotificationService is null, creating new.");
              return NotificationService(apiClient);
            }
            print("  Re-using/creating NotificationService with (potentially new) ApiClient.");
            return NotificationService(apiClient);
          },
        ),

        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) {
            print("--- ChangeNotifierProxyProvider: CREATE NotificationProvider ---");
            NotificationService? notificationService;
            AuthProvider? authProviderInstance;
            try {
              notificationService = context.read<NotificationService>();
              print("  NotificationService read successfully: ${notificationService.runtimeType}");
            } catch (e, s) {
              print("  ERROR reading NotificationService in create: $e");
              print(s);
              throw StateError("Failed to read NotificationService during NotificationProvider create: $e");
            }

            try {
              authProviderInstance = context.read<AuthProvider>();
              print("  AuthProvider read successfully: ${authProviderInstance.runtimeType}");
            } catch (e, s) {
              print("  ERROR reading AuthProvider in create: $e");
              print(s);
              throw StateError("Failed to read AuthProvider during NotificationProvider create: $e");
            }

            print("  Dependencies read. Creating NotificationProvider instance...");
            final np = NotificationProvider(notificationService, authProviderInstance);
            print("  NotificationProvider instance CREATED: ${np.runtimeType}");
            return np;
          },
          update: (context, auth, previousProvider) {
            print("--- ChangeNotifierProxyProvider: UPDATE NotificationProvider ---");
            print("  AuthProvider changed. New auth state: ${auth.isAuthenticated}");
            NotificationService? notificationService;
            try {
              notificationService = context.read<NotificationService>();
              print("  NotificationService read successfully in update: ${notificationService.runtimeType}");
            } catch (e, s) {
              print("  ERROR reading NotificationService in update: $e");
              print(s);
              throw StateError("Failed to read NotificationService during NotificationProvider update: $e");
            }

            print("  Creating new NotificationProvider instance with updated auth.");
            return NotificationProvider(notificationService, auth);
          },
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
    print("--- MyApp BUILD ---");
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    print("  AuthProvider isLoading: ${authProvider.isLoading}, isAuthenticated: ${authProvider.isAuthenticated}");
    print("  ThemeProvider isLoading: ${themeProvider.isLoading}, themeMode: ${themeProvider.themeMode}");

    if (authProvider.isLoading || themeProvider.isLoading) {
      print("  MyApp: Showing loading indicator.");
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    print("  MyApp: Showing main content (Login or MainNavigationScreen).");
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
      },
    );
  }
}
