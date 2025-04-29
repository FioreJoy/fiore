// frontend/lib/services/api/block_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for managing user blocking.
class BlockService {
  final ApiClient _apiClient;

  BlockService(this._apiClient);

  /// Fetches the list of users blocked by the currently authenticated user.
  Future<List<dynamic>> getBlockedUsers() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.blockedUsers);
      return response as List<dynamic>;
    } catch (e) {
      print("BlockService: Failed to fetch blocked users - $e");
      rethrow;
    }
  }

  /// Blocks a user specified by [userIdToBlock].
  Future<void> blockUser({
    required int userIdToBlock,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.blockUser(userIdToBlock),
      );
    } catch (e) {
      print("BlockService: Failed to block user $userIdToBlock - $e");
      rethrow;
    }
  }

  /// Unblocks a user specified by [userIdToUnblock].
  Future<void> unblockUser({
    required int userIdToUnblock,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.unblockUser(userIdToUnblock),
      );
    } catch (e) {
      print("BlockService: Failed to unblock user $userIdToUnblock - $e");
      rethrow;
    }
  }
}
