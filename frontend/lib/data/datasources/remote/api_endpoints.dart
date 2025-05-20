// frontend/lib/services/api_endpoints.dart

/// Defines constants for API endpoint paths.
class ApiEndpoints {
  // Base URL is handled by ApiClient

  // --- Authentication ---
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String currentUser = '/auth/me';
  static const String changePassword = '/auth/me/password';

  // --- Users ---
  static const String userBase = '/users';
  static String userProfile(int userId) => '/users/$userId';
  static const String currentUserCommunities = '/users/me/communities';
  static const String currentUserEvents = '/users/me/events';
  static const String currentUserStats = '/users/me/stats';

  static String followUser(int userIdToFollow) =>
      '/users/$userIdToFollow/follow';
  static String unfollowUser(int userIdToUnfollow) =>
      '/users/$userIdToUnfollow/follow';
  static String followers(int userId) => '/users/$userId/followers';
  static String following(int userId) => '/users/$userId/following';

  static const String blockedUsers = '/users/me/blocked';
  static String blockUser(int userId) => '/users/me/block/$userId';
  static String unblockUser(int userId) => '/users/me/unblock/$userId';

  // --- Communities ---
  static const String communitiesBase = '/communities';
  static const String communitiesTrending = '/communities/trending';
  static String communityBaseId(int id) => '/communities/$id';
  static String communityDetail(int id) => '/communities/$id/details';
  static String communityJoin(int id) => '/communities/$id/join';
  static String communityLeave(int id) => '/communities/$id/leave';
  static String communityUpdateLogo(int id) => '/communities/$id/logo';
  static String communityPostLink(int communityId, int postId) =>
      '/communities/$communityId/posts/$postId';
  static String communityCreateEvent(int communityId) =>
      '/communities/$communityId/events';
  static String communityListEvents(int communityId) =>
      '/communities/$communityId/events';

  // --- Events ---
  static const String eventsBase = '/events';
  static String eventDetail(int id) => '/events/$id';
  static String eventJoin(int id) => '/events/$id/join';
  static String eventLeave(int id) => '/events/$id/leave';

  // --- Posts ---
  static const String postsBase = '/posts';
  static const String postsTrending = '/posts/trending';
  static String postDetail(int id) => '/posts/$id';
  static String postFavorite(int id) => '/posts/$id/favorite';

  // --- Replies ---
  static const String repliesBase = '/replies';
  static String repliesForPost(int postId) => '/replies/$postId';
  static String replyDetail(int id) => '/replies/$id';
  static String replyFavorite(int id) => '/replies/$id/favorite';

  // --- Votes ---
  static const String votesBase = '/votes';

  // --- Chat ---
  static const String chatMessages = '/chat/messages';

  // --- Settings ---
  static const String notificationSettings = '/settings/notifications';

  // --- Notifications (NEWLY ADDED SECTION) ---
  static const String notificationsBase = '/notifications'; // For GET list
  static const String notificationsRead =
      '/notifications/read'; // For POST to mark as read/unread
  static const String notificationsReadAll =
      '/notifications/read-all'; // For POST to mark all as read
  static const String notificationsUnreadCount =
      '/notifications/unread-count'; // For GET unread count
  static const String notificationsDeviceTokens =
      '/notifications/device-tokens'; // POST to register, DELETE to unregister
  // --- End Notifications Section ---

  // --- Location ---
  static String nearbyEvents = '/location/events/nearby';
  static String nearbyUsers = '/location/users/nearby';
  static String nearbyCommunities = '/location/communities/nearby';

  // --- WebSocket ---
  static String websocketRoomPath(String type, int id) => '/ws/$type/$id';

  static const String feedFollowing = '/feed/following';

  // --- GraphQL ---
  static const String graphql = '/graphql';
}
