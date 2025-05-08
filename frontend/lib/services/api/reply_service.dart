// frontend/lib/services/api/reply_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for reply-related API calls (excluding favorites).
class ReplyService {
  final ApiClient _apiClient;

  ReplyService(this._apiClient);

  // --- getRepliesForPost (no changes needed from previous version) ---
  Future<List<dynamic>> getRepliesForPost(int postId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.repliesForPost(postId), token: token,
      );
      return response as List<dynamic>;
    } catch (e) {
      print("ReplyService: Failed to fetch replies for post $postId - $e");
      rethrow;
    }
  }

  // --- createReply (no changes needed from previous version) ---
  Future<Map<String, dynamic>> createReply({
    required String token,
    required int postId,
    required String content,
    int? parentReplyId,
  }) async {
    try {
      final body = {'post_id': postId, 'content': content,};
      if (parentReplyId != null) { body['parent_reply_id'] = parentReplyId; }
      final response = await _apiClient.post(
        ApiEndpoints.repliesBase, token: token, body: body,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("ReplyService: Failed to create reply for post $postId - $e");
      rethrow;
    }
  }

  // --- deleteReply (no changes needed from previous version) ---
  Future<void> deleteReply({ required String token, required int replyId, }) async {
    try {
      await _apiClient.delete( ApiEndpoints.replyDetail(replyId), token: token,);
    } catch (e) {
      print("ReplyService: Failed to delete reply $replyId - $e");
      rethrow;
    }
  }

// --- Favorite methods REMOVED - Assumed handled by FavoriteService ---
// // Future<void> favoriteReply(...) async { ... }
// // Future<void> unfavoriteReply(...) async { ... }
}