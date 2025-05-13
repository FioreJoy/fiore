// frontend/lib/services/api/user_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';

class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  /// Fetches the public profile data for a specific user, including graph counts and viewer's follow status.
  Future<Map<String, dynamic>> getUserProfile(int userId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.userProfile(userId),
        token: token, // Token for backend to determine 'is_following' by viewer
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch user profile for $userId - $e");
      rethrow;
    }
  }

  /// Fetches the list of communities joined by the CURRENT authenticated user.
  Future<List<dynamic>> getMyJoinedCommunities(String token, {int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get(
        ApiEndpoints.currentUserCommunities,
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("UserService: Failed to fetch joined communities - $e");
      rethrow;
    }
  }

  /// Fetches the list of events joined by the CURRENT authenticated user.
  Future<List<dynamic>> getMyJoinedEvents(String token, {int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get(
        ApiEndpoints.currentUserEvents,
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("UserService: Failed to fetch joined events - $e");
      rethrow;
    }
  }

  /// Fetches statistics for the CURRENT authenticated user.
  Future<Map<String, dynamic>> getMyStats(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserStats,
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch user stats - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> followUser(String token, int userIdToFollow) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.followUser(userIdToFollow),
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to follow user $userIdToFollow - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> unfollowUser(String token, int userIdToUnfollow) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.unfollowUser(userIdToUnfollow),
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to unfollow user $userIdToUnfollow - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getFollowers(int userId, {String? token, int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get(
        ApiEndpoints.followers(userId),
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("UserService: Failed to fetch followers for user $userId - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getFollowing(int userId, {String? token, int limit = 50, int offset = 0}) async {
    try {
      final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
      final response = await _apiClient.get(
        ApiEndpoints.following(userId),
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("UserService: Failed to fetch following for user $userId - $e");
      rethrow;
    }
  }
  // Placeholder for fetching a user's own posts - backend needs /users/{user_id}/posts or similar
  Future<List<dynamic>> getUserPosts(int userId, {String? token, int limit = 10, int offset = 0}) async {
    print("UserService: getUserPosts called for user $userId (token: ${token != null}, limit: $limit, offset: $offset). Needs backend endpoint /users/{id}/posts.");
    // final queryParams = {'limit': limit.toString(), 'offset': offset.toString()};
    // final response = await _apiClient.get(ApiEndpoints.userPosts(userId), token: token, queryParams: queryParams);
    // return response as List<dynamic>? ?? [];
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate
    return []; // Return empty for now
  }
}