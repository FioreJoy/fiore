// frontend/lib/services/api_endpoints.dart

/// Defines constants for API endpoint paths.
/// Using static constants helps avoid typos and centralizes URL management.
class ApiEndpoints {
  // Base URL is typically handled by the ApiClient using AppConstants or environment variables.
  // These constants represent the PATHS only.

  // --- Authentication ---
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String currentUser = '/auth/me'; // Used for GET (read), PUT (update), DELETE (delete)
  static const String changePassword = '/auth/me/password'; // Used for PUT

  // --- Users ---
  static const String userBase = '/users'; // Base for potential future user-specific actions (e.g., GET /users/{id})
  static const String currentUserCommunities = '/users/me/communities'; // GET joined communities
  static const String currentUserEvents = '/users/me/events'; // GET joined events

  // Blocking Endpoints (Adjust paths based on your actual backend implementation)
  static const String blockedUsers = '/users/me/blocked'; // GET list of blocked users
  static String blockUser(int userId) => '/users/me/block/$userId'; // POST to block a user
  static String unblockUser(int userId) => '/users/me/unblock/$userId'; // DELETE to unblock a user

  // --- Communities ---
  static const String communitiesBase = '/communities'; // GET (list all), POST (create new)
  static const String communitiesTrending = '/communities/trending'; // GET trending communities
  static String communityDetail(int id) => '/communities/$id/details'; // GET specific community details
  static String communityBaseId(int id) => '/communities/$id'; // Base for actions on a specific community (e.g., DELETE)
  static String communityJoin(int id) => '/communities/$id/join'; // POST to join
  static String communityLeave(int id) => '/communities/$id/leave'; // DELETE to leave
  static String communityAddPost(int communityId, int postId) => '/communities/$communityId/add_post/$postId'; // POST link post
  static String communityRemovePost(int communityId, int postId) => '/communities/$communityId/remove_post/$postId'; // DELETE link post
  static String communityCreateEvent(int communityId) => '/communities/$communityId/events'; // POST to create event in community
  static String communityListEvents(int communityId) => '/communities/$communityId/events'; // GET events for community

  // --- Events ---
  static const String eventsBase = '/events'; // Base path if needed for future event-only actions
  static String eventDetail(int id) => '/events/$id'; // GET (details), PUT (update), DELETE (delete)
  static String eventJoin(int id) => '/events/$id/join'; // POST to join event
  static String eventLeave(int id) => '/events/$id/leave'; // DELETE to leave event

  // --- Posts ---
  static const String postsBase = '/posts'; // GET (list all/filtered), POST (create new)
  static const String postsTrending = '/posts/trending'; // GET trending posts
  static String postDetail(int id) => '/posts/$id'; // GET (specific post - if needed), DELETE (delete post)
  // Add favorite endpoint if implemented, e.g.:
  // static String postFavorite(int id) => '/posts/$id/favorite'; // POST/DELETE

  // --- Replies ---
  static const String repliesBase = '/replies'; // POST (create new)
  static String repliesForPost(int postId) => '/replies/$postId'; // GET replies for a specific post
  static String replyDetail(int id) => '/replies/$id'; // DELETE reply
  // Add favorite endpoint if implemented, e.g.:
  // static String replyFavorite(int id) => '/replies/$id/favorite'; // POST/DELETE

  // --- Votes ---
  static const String votesBase = '/votes'; // POST (cast/update/remove vote)
  // GET endpoint for votes might not be commonly used directly by client

  // --- Chat ---
  static const String chatMessages = '/chat/messages'; // GET (fetch history), POST (send via HTTP)

  // --- Settings (Example Paths - Adjust to your actual backend routes) ---
  static const String notificationSettings = '/settings/notifications'; // GET, PUT
  // Add other settings endpoints as needed (e.g., /settings/privacy, /settings/account)
  // --- WebSocket ---
  // Path structure only, base URL handled separately.
  static String websocketRoomPath(String type, int id) => '/ws/$type/$id';
}
