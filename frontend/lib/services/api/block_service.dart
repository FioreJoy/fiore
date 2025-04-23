// frontend/lib/services/api/block_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';
// Import BlockedUser model if created

/// Service responsible for managing user blocking.
class BlockService {
  final ApiClient _apiClient;

  BlockService(this._apiClient);

  /// Fetches the list of users blocked by the currently authenticated user.
  /// Requires authentication token and API Key.
  /// Returns a list of Maps representing blocked user information.
  Future<List<dynamic>> getBlockedUsers(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.blockedUsers, // Adjust endpoint if different
        token: token,
      );
      // Expects a List<BlockedUserDisplay> from backend
      return response as List<dynamic>;
    } catch (e) {
      print("BlockService: Failed to fetch blocked users - $e");
      rethrow;
    }
  }

  /// Blocks a user specified by [userIdToBlock].
  /// Requires authentication token and API Key.
  Future<void> blockUser({
    required String token,
    required int userIdToBlock,
  }) async {
    try {
      // Assuming a POST request to the specific user block endpoint
      await _apiClient.post(
        ApiEndpoints.blockUser(userIdToBlock), // Adjust endpoint if different
        token: token,
        // Body might not be required if ID is in path
      );
      // Expects 200 OK or 204 No Content
    } catch (e) {
      print("BlockService: Failed to block user $userIdToBlock - $e");
      rethrow;
    }
  }

  /// Unblocks a user specified by [userIdToUnblock].
  /// Requires authentication token and API Key.
  Future<void> unblockUser({
    required String token,
    required int userIdToUnblock,
  }) async {
    try {
      // Assuming a DELETE request to the specific user unblock endpoint
      await _apiClient.delete(
        ApiEndpoints.unblockUser(userIdToUnblock), // Adjust endpoint if different
        token: token,
      );
      // Expects 200 OK or 204 No Content
    } catch (e) {
      print("BlockService: Failed to unblock user $userIdToUnblock - $e");
      rethrow;
    }
  }
}
