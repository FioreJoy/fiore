// frontend/lib/services/api_endpoints.dart

/// Defines constants for API endpoint paths.
class ApiEndpoints {
  // Base URL is handled by ApiClient

  // --- Authentication ---
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String currentUser = '/auth/me'; // GET, PUT, DELETE user profile
  static const String changePassword = '/auth/me/password'; // PUT password

  // --- Users ---
  static const String userBase = '/users'; // Base path
  static String userProfile(int userId) => '/users/$userId'; // GET specific user profile
  static const String currentUserCommunities = '/users/me/communities'; // GET joined communities
  static const String currentUserEvents = '/users/me/events'; // GET joined events
  static const String currentUserStats = '/users/me/stats'; // GET user statistics

  // Follow/Unfollow
  static String followUser(int userIdToFollow) => '/users/$userIdToFollow/follow'; // POST to follow
  static String unfollowUser(int userIdToUnfollow) => '/users/$userIdToUnfollow/follow'; // DELETE to unfollow (Using same endpoint with different method)
  static String followers(int userId) => '/users/$userId/followers'; // GET followers list
  static String following(int userId) => '/users/$userId/following'; // GET following list

  // Blocking (Assuming previous definitions are correct)
  static const String blockedUsers = '/users/me/blocked'; // GET list
  static String blockUser(int userId) => '/users/me/block/$userId'; // POST
  static String unblockUser(int userId) => '/users/me/unblock/$userId'; // DELETE

  // --- Communities ---
  static const String communitiesBase = '/communities'; // GET (list all), POST (create new)
  static const String communitiesTrending = '/communities/trending'; // GET trending
  static String communityBaseId(int id) => '/communities/$id'; // DELETE specific community
  static String communityDetail(int id) => '/communities/$id/details'; // GET specific details + counts
  static String communityJoin(int id) => '/communities/$id/join'; // POST to join
  static String communityLeave(int id) => '/communities/$id/leave'; // DELETE to leave
  static String communityUpdateLogo(int id) => '/communities/$id/logo'; // POST to update logo
  // Community Posts Link (Use POST for adding, DELETE for removing)
  static String communityPostLink(int communityId, int postId) => '/communities/$communityId/posts/$postId';
  // Community Events
  static String communityCreateEvent(int communityId) => '/communities/$communityId/events'; // POST create
  static String communityListEvents(int communityId) => '/communities/$communityId/events'; // GET list

  // --- Events ---
  static const String eventsBase = '/events'; // Base path
  static String eventDetail(int id) => '/events/$id'; // GET (details), PUT (update), DELETE
  static String eventJoin(int id) => '/events/$id/join'; // POST join
  static String eventLeave(int id) => '/events/$id/leave'; // DELETE leave

  // --- Posts ---
  static const String postsBase = '/posts'; // GET (list/filtered), POST (create)
  static const String postsTrending = '/posts/trending'; // GET trending
  static String postDetail(int id) => '/posts/$id'; // DELETE post
  // Favorites (Use POST for adding, DELETE for removing)
  static String postFavorite(int id) => '/posts/$id/favorite';

  // --- Replies ---
  static const String repliesBase = '/replies'; // POST (create new)
  static String repliesForPost(int postId) => '/replies/$postId'; // GET replies for post
  static String replyDetail(int id) => '/replies/$id'; // DELETE reply
  // Favorites (Use POST for adding, DELETE for removing)
  static String replyFavorite(int id) => '/replies/$id/favorite';

  // --- Votes ---
  static const String votesBase = '/votes'; // POST (cast/update/remove vote)

  // --- Chat ---
  static const String chatMessages = '/chat/messages'; // GET history, POST send HTTP

  // --- Settings (Example Paths) ---
  static const String notificationSettings = '/settings/notifications'; // GET, PUT

  // --- WebSocket ---
  // Path structure only, base URL handled separately by WebSocketService
  static String websocketRoomPath(String type, int id) => '/ws/$type/$id';

  // --- GraphQL ---
  static const String graphql = '/graphql'; // Single endpoint for GraphQL
}