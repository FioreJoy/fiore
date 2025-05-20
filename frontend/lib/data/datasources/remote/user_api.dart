// frontend/lib/data/datasources/remote/user_api.dart
import './api_client.dart';
import './api_endpoints.dart'; // ApiEndpoints is correctly imported from its new location

class UserService { // Assuming original class name was UserService
  final ApiClient _apiClient;

  UserService(this._apiClient);

  Future<Map<String, dynamic>> getUserProfile(int userId, {String? token}) async {
    try {
      final response = await _apiClient.get( ApiEndpoints.userProfile(userId), token: token,);
      return response as Map<String, dynamic>;
    } catch (e) { /* print("UserService: Failed to fetch profile for $userId - $e"); */ rethrow; }
  }

  Future<List<dynamic>> getMyJoinedCommunities(String token, {int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get( ApiEndpoints.currentUserCommunities, token: token, queryParams: queryParams,);
      return response as List<dynamic>? ?? [];
    } catch (e) { /* print("UserService: Failed to fetch joined communities - $e"); */ rethrow; }
  }

  Future<List<dynamic>> getMyJoinedEvents(String token, {int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get( ApiEndpoints.currentUserEvents, token: token, queryParams: queryParams,);
      return response as List<dynamic>? ?? [];
    } catch (e) { /* print("UserService: Failed to fetch joined events - $e"); */ rethrow; }
  }

  Future<Map<String, dynamic>> getMyStats(String token) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.currentUserStats, token: token,);
      return response as Map<String, dynamic>;
    } catch (e) { /* print("UserService: Failed to fetch user stats - $e"); */ rethrow; }
  }

  Future<Map<String, dynamic>> followUser(String token, int userIdToFollow) async { /* ...unchanged... */ try { final response = await _apiClient.post( ApiEndpoints.followUser(userIdToFollow), token: token,); return response as Map<String, dynamic>; } catch (e) { rethrow;}}
  Future<Map<String, dynamic>> unfollowUser(String token, int userIdToUnfollow) async { /* ...unchanged... */ try { final response = await _apiClient.delete( ApiEndpoints.unfollowUser(userIdToUnfollow), token: token,); return response as Map<String, dynamic>; } catch (e) { rethrow;}}
  Future<List<dynamic>> getFollowers(int userId, {String? token, int limit = 50, int offset = 0}) async { /* ...unchanged... */ try { final queryParams = {'limit': limit.toString(), 'offset': offset.toString()}; final response = await _apiClient.get(ApiEndpoints.followers(userId), token: token, queryParams: queryParams,); return response as List<dynamic>? ?? [];} catch (e) { rethrow;}}
  Future<List<dynamic>> getFollowing(int userId, {String? token, int limit = 50, int offset = 0}) async { /* ...unchanged... */ try { final queryParams = {'limit': limit.toString(), 'offset': offset.toString()}; final response = await _apiClient.get(ApiEndpoints.following(userId), token: token, queryParams: queryParams,); return response as List<dynamic>? ?? [];} catch (e) { rethrow;}}

  // This method likely requires a backend endpoint /users/{user_id}/posts
  Future<List<dynamic>> getUserPosts(int userId, {String? token, int limit = 10, int offset = 0}) async {
    // print("UserService: getUserPosts for user $userId"); // Debug
    try {
      // final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      // For now, using the generic /posts endpoint filtered by user_id if the backend supports it,
      // otherwise, this would need its own specific endpoint like ApiEndpoints.userPosts(userId)
      // final String endpoint = ApiEndpoints.userPosts(userId); // This endpoint is not defined
      final String endpoint = '${ApiEndpoints.postsBase}?user_id=$userId&limit=$limit&offset=$offset';
      final response = await _apiClient.get(endpoint, token: token /* queryParams can be built into endpoint */);
      return response as List<dynamic>? ?? [];
    } catch (e) { /* print("UserService: Failed getUserPosts for $userId: $e"); */ rethrow;}
  }

  // --- STUBBED METHODS - REQUIRE BACKEND IMPLEMENTATION ---
  Future<List<dynamic>> getUserCommunities(int userId, {String? token, int limit = 20, int offset = 0}) async {
    // print("UserService STUB: Fetching communities for user $userId. Requires backend /users/$userId/communities");
    // This would call: await _apiClient.get(ApiEndpoints.userCommunities(userId), token: token, queryParams: {...});
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate API call
    return []; // Return empty list as backend endpoint is not yet defined/confirmed
  }

  Future<List<dynamic>> getUserEvents(int userId, {String? token, int limit = 20, int offset = 0}) async {
    // print("UserService STUB: Fetching events for user $userId. Requires backend /users/$userId/events");
    // This would call: await _apiClient.get(ApiEndpoints.userEvents(userId), token: token, queryParams: {...});
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate API call
    return []; // Return empty list
  }
// --- END STUBBED METHODS ---
}