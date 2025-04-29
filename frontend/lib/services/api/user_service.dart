import '../api_client.dart';
import '../api_endpoints.dart';
// Import models if you create them (e.g., CommunityDisplay, EventDisplay, BlockedUserDisplay)
// import '../../models/community_display.dart';
// import '../../models/event_model.dart'; // Assuming EventModel is used
// import '../../models/blocked_user_display.dart';

/// Service responsible for user-related API calls (excluding auth/profile).
class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  /// Fetches the list of communities joined by the current user.
  /// Returns a list of Maps, expected to match CommunityDisplay schema.
  Future<List<dynamic>> getMyJoinedCommunities() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserCommunities,
      );
      // Backend returns List<CommunityDisplay> which gets decoded into List<dynamic> (List<Map<String, dynamic>>)
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch joined communities - $e");
      rethrow; // Let UI handle error
    }
  }

  /// Fetches the list of events joined by the current user.
  /// Returns a list of Maps, expected to match EventDisplay schema.
  Future<List<dynamic>> getMyJoinedEvents() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUserEvents, // Corrected endpoint name
      );
      // Backend returns List<EventDisplay> which gets decoded into List<dynamic> (List<Map<String, dynamic>>)
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch joined events - $e");
      rethrow;
    }
  }

  // --- Blocking Actions (Example Implementation) ---
  // Ensure backend endpoints match ApiEndpoints definitions

  /// Fetches the list of users blocked by the current user.
  /// Returns a list of Maps, expected to match BlockedUserDisplay schema.
  Future<List<dynamic>> getBlockedUsers() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.blockedUsers,
      );
      return response as List<dynamic>;
    } catch (e) {
      print("UserService: Failed to fetch blocked users - $e");
      rethrow;
    }
  }

  /// Blocks a specific user.
  Future<void> blockUser(int userIdToBlock) async {
    try {
      await _apiClient.post( // Assuming POST to block
        ApiEndpoints.blockUser(userIdToBlock),
      );
      // Expects 200 OK or 204 No Content, _handleResponse handles success/error
    } catch (e) {
      print("UserService: Failed to block user $userIdToBlock - $e");
      rethrow;
    }
  }

  /// Unblocks a specific user.
  Future<void> unblockUser(int userIdToUnblock) async {
    try {
      await _apiClient.delete( // Assuming DELETE to unblock
        ApiEndpoints.unblockUser(userIdToUnblock),
      );
      // Expects 200 OK or 204 No Content
    } catch (e) {
      print("UserService: Failed to unblock user $userIdToUnblock - $e");
      rethrow;
    }
  }

// --- Add other user-related fetches if needed ---
// e.g., Future<Map<String, dynamic>> getPublicUserProfile(int userId) async { ... }
}
