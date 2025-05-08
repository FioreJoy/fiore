// frontend/lib/services/api/user_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for user-related API calls (fetching profiles, followers, etc.).
/// Excludes direct auth actions (login, signup, profile update - handled by AuthService).
class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  /// Fetches the public profile data for a specific user, including graph counts.
  /// Auth token is optional but needed to determine viewer's follow status.
  Future<Map<String, dynamic>> getUserProfile(int userId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.userProfile(userId),
        token: token, // Pass token to get viewer-specific data (e.g., is_following)
      );
      // Backend returns UserDisplay schema (including counts and potentially is_following)
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch user profile for $userId - $e");
      rethrow;
    }
  }

  /// Fetches the list of communities joined by the CURRENT authenticated user.
  /// Requires auth token.
  Future<List<dynamic>> getMyJoinedCommunities(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserCommunities,
        token: token,
      );
      // Backend returns List<CommunityDisplay>
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch joined communities - $e");
      rethrow;
    }
  }

  /// Fetches the list of events joined by the CURRENT authenticated user.
  /// Requires auth token.
  Future<List<dynamic>> getMyJoinedEvents(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserEvents,
        token: token,
      );
      // Backend returns List<EventDisplay>
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch joined events - $e");
      rethrow;
    }
  }

  /// Fetches statistics for the CURRENT authenticated user.
  /// Requires auth token.
  Future<Map<String, dynamic>> getMyStats(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserStats,
        token: token,
      );
      // Backend returns UserStats schema
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch user stats - $e");
      rethrow;
    }
  }

  /// Follows a target user. Requires auth token.
  Future<Map<String, dynamic>> followUser(String token, int userIdToFollow) async {
    try {
      // Use POST to the specific user's follow endpoint
      final response = await _apiClient.post(
        ApiEndpoints.followUser(userIdToFollow),
        token: token,
      );
      // Expects response like {'message': ..., 'success': ..., 'new_follower_count': ...}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to follow user $userIdToFollow - $e");
      rethrow;
    }
  }

  /// Unfollows a target user. Requires auth token.
  Future<Map<String, dynamic>> unfollowUser(String token, int userIdToUnfollow) async {
    try {
      // Use DELETE to the specific user's follow endpoint
      final response = await _apiClient.delete(
        ApiEndpoints.unfollowUser(userIdToUnfollow), // Same endpoint as follow, different method
        token: token,
      );
      // Expects response like {'message': ..., 'success': ..., 'new_follower_count': ...}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("UserService: Failed to unfollow user $userIdToUnfollow - $e");
      rethrow;
    }
  }

  /// Fetches the list of users following a target user.
  /// Auth token optional (for potential future viewer-specific info).
  Future<List<dynamic>> getFollowers(int userId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.followers(userId),
        token: token,
      );
      // Expects List<UserBase> or List<FollowerInfo>
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch followers for user $userId - $e");
      rethrow;
    }
  }

  /// Fetches the list of users a target user is following.
  /// Auth token optional.
  Future<List<dynamic>> getFollowing(int userId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.following(userId),
        token: token,
      );
      // Expects List<UserBase> or List<FollowerInfo>
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch following for user $userId - $e");
      rethrow;
    }
  }

// Note: Blocking methods are likely in BlockService now
}