// frontend/lib/services/api/reply_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';
// Import ReplyDisplay model if created

/// Service responsible for reply-related API calls.
class ReplyService {
  final ApiClient _apiClient;

  ReplyService(this._apiClient);

  /// Fetches replies for a specific post.
  /// Requires API Key. User token might be optional for public viewing.
  Future<List<dynamic>> getRepliesForPost(int postId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.repliesForPost(postId),
        token: token, // Pass token if provided/needed
      );
      return response as List<dynamic>; // Expects List<ReplyDisplay>
    } catch (e) {
      print("ReplyService: Failed to fetch replies for post $postId - $e");
      rethrow;
    }
  }

  /// Creates a new reply to a post. Requires user authentication.
  Future<Map<String, dynamic>> createReply({
    required String token,
    required int postId,
    required String content,
    int? parentReplyId, // Optional ID of the reply being replied to
  }) async {
    try {
      final body = {
        'post_id': postId,
        'content': content,
      };
      // Add parent_reply_id to the body only if it's provided
      if (parentReplyId != null) {
        body['parent_reply_id'] = parentReplyId;
      }

      final response = await _apiClient.post(
        ApiEndpoints.repliesBase,
        token: token, // Auth token required
        body: body,
      );
      return response as Map<String, dynamic>; // Expects created ReplyDisplay
    } catch (e) {
      print("ReplyService: Failed to create reply for post $postId - $e");
      rethrow;
    }
  }

  /// Deletes a reply. Requires user authentication (author).
  Future<void> deleteReply({
    required String token,
    required int replyId,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.replyDetail(replyId), // Use endpoint for specific reply ID
        token: token,
      );
      // Expects 204 No Content
    } catch (e) {
      print("ReplyService: Failed to delete reply $replyId - $e");
      rethrow;
    }
  }

  // --- Add Reply Favorite/Unfavorite methods if backend supports them ---
  // Example:
  // Future<void> favoriteReply(int replyId, String token) async {
  //   try {
  //     await _apiClient.post(ApiEndpoints.replyFavorite(replyId), token: token);
  //   } catch (e) { rethrow; }
  // }
  // Future<void> unfavoriteReply(int replyId, String token) async {
  //   try {
  //     await _apiClient.delete(ApiEndpoints.replyFavorite(replyId), token: token);
  //   } catch (e) { rethrow; }
  // }
}
