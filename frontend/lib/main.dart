import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Core Imports ---
// AppConstants might be needed by app.dart, not directly here now.
// import 'core/constants/app_constants.dart';

// --- Data Layer Imports (API service classes - using their new file names) ---
import 'data/datasources/remote/api_client.dart';
import 'data/datasources/remote/websocket_service.dart';
import 'data/datasources/remote/auth_api.dart'; // File name changed
import 'data/datasources/remote/user_api.dart'; // File name changed
import 'data/datasources/remote/community_api.dart';
import 'data/datasources/remote/event_api.dart';
import 'data/datasources/remote/post_api.dart';
import 'data/datasources/remote/reply_api.dart';
import 'data/datasources/remote/vote_api.dart';
import 'data/datasources/remote/chat_api.dart';
import 'data/datasources/remote/settings_api.dart';
import 'data/datasources/remote/block_api.dart';
import 'data/datasources/remote/location_api.dart';
import 'data/datasources/remote/favorite_api.dart';
import 'data/datasources/remote/notification_api.dart';

// --- Presentation Layer (Providers) Imports ---
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'core/theme/theme_provider.dart';

// --- App Widget Import ---
import 'app.dart'; // Contains the MaterialApp

// --- Assume original class names (AuthService, UserService etc.) are still used INSIDE the _api.dart files ---
// These typedefs bridge the gap between old class names and new file names if class names weren't changed.
// If class names *were* changed (e.g. to AuthApi), then remove these typedefs and use the new class names directly.
typedef AuthApiService = AuthService;
typedef BlockApiService = BlockService;
typedef ChatApiService = ChatService;
typedef CommunityApiService = CommunityService;
typedef EventApiService = EventService;
typedef FavoriteApiService = FavoriteService;
typedef LocationApiService = LocationService;
typedef NotificationApiService = NotificationService;
typedef PostApiService = PostService;
typedef ReplyApiService = ReplyService;
typedef SettingsApiService = SettingsService;
typedef UserApiService = UserService;
typedef VoteApiService = VoteService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider(); // Initialize early
  final themeProvider = ThemeProvider(); // Initialize early
  // auto-login and theme loading are handled in their constructors

  runApp(
    MultiProvider(
      providers: [
        // Core Infrastructure
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, apiClient) => apiClient.dispose(),
        ),
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
          dispose: (_, wsService) => wsService.dispose(),
        ),
        Provider<LocationApiService>(
          // If LocationService class still exists in location_api.dart
          create: (_) => LocationApiService(),
        ),

        // API Service Providers (using typedefs for clarity or original class names)
        ProxyProvider<ApiClient, AuthApiService>(
          update: (_, apiClient, __) => AuthApiService(apiClient),
        ),
        ProxyProvider<ApiClient, UserApiService>(
          update: (_, apiClient, __) => UserApiService(apiClient),
        ),
        ProxyProvider<ApiClient, CommunityApiService>(
          update: (_, apiClient, __) => CommunityApiService(apiClient),
        ),
        ProxyProvider<ApiClient, EventApiService>(
          update: (_, apiClient, __) => EventApiService(apiClient),
        ),
        ProxyProvider<ApiClient, PostApiService>(
          update: (_, apiClient, __) => PostApiService(apiClient),
        ),
        ProxyProvider<ApiClient, ReplyApiService>(
          update: (_, apiClient, __) => ReplyApiService(apiClient),
        ),
        ProxyProvider<ApiClient, VoteApiService>(
          update: (_, apiClient, __) => VoteApiService(apiClient),
        ),
        ProxyProvider<ApiClient, FavoriteApiService>(
          update: (_, apiClient, __) => FavoriteApiService(apiClient),
        ),
        ProxyProvider<ApiClient, ChatApiService>(
          update: (_, apiClient, __) => ChatApiService(apiClient),
        ),
        ProxyProvider<ApiClient, SettingsApiService>(
          update: (_, apiClient, __) => SettingsApiService(apiClient),
        ),
        ProxyProvider<ApiClient, BlockApiService>(
          update: (_, apiClient, __) => BlockApiService(apiClient),
        ),
        ProxyProvider<ApiClient, NotificationApiService>(
          update: (_, apiClient, __) => NotificationApiService(apiClient),
        ),

        // App State Management Providers
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),

        ChangeNotifierProxyProvider2<NotificationApiService, AuthProvider,
            NotificationProvider>(
          create: (context) {
            final notificationService = context.read<NotificationApiService>();
            final authProviderForNotif = context.read<AuthProvider>();
            return NotificationProvider(
                notificationService, authProviderForNotif);
          },
          update: (_, notificationService, authProviderForNotif, previous) =>
              previous ??
              NotificationProvider(notificationService, authProviderForNotif),
        ),
      ],
      child: const FioreApp(),
    ),
  );
}
