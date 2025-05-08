// frontend/lib/services/api/vote_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for casting/removing votes on posts or replies.
class VoteService {
  final ApiClient _apiClient;

  VoteService(this._apiClient);

  /// Casts, updates, or removes a vote on a specific post or reply item.
  ///
  /// The backend determines the exact action (create, update, delete) based
  /// on the provided `voteType` and the user's existing vote status for the item.
  ///
  /// Args:
  ///   token: The user's authentication token.
  ///   postId: The ID of the post to vote on (if applicable).
  ///   replyId: The ID of the reply to vote on (if applicable).
  ///   voteType: `true` for an upvote action, `false` for a downvote action.
  ///
  /// Returns:
  ///   A Map containing the result message, success status, and updated vote counts
  ///   for the target item (e.g., {'message': 'Vote removed', 'success': true, 'new_counts': {'upvotes': 10, 'downvotes': 1}}).
  ///
  /// Throws:
  ///   ArgumentError if neither postId nor replyId is provided.
  ///   Exception if the API call fails.
  Future<Map<String, dynamic>> castOrRemoveVote({
    required String token,
    int? postId,
    int? replyId,
    required bool voteType, // The action the user performed (true=up, false=down)
  }) async {
    // Validate that exactly one target ID is provided
    if (!((postId != null && replyId == null) || (postId == null && replyId != null))) {
      throw ArgumentError("VoteService Error: Provide exactly one of postId or replyId.");
    }

    // Prepare the request body according to the backend schema (schemas.VoteCreate)
    final body = {
      'post_id': postId,   // Will be null if replyId is provided
      'reply_id': replyId, // Will be null if postId is provided
      'vote_type': voteType,
    };

    try {
      print("VoteService: Sending vote action -> postId: $postId, replyId: $replyId, voteType: $voteType");
      // Call the single POST endpoint defined in ApiEndpoints
      final response = await _apiClient.post(
        ApiEndpoints.votesBase,
        token: token, // Auth token is required
        body: body,
      );
      print("VoteService: Response received -> $response");

      // The backend response should indicate success and include updated counts
      // Expecting Map<String, dynamic> like {'message':..., 'success':..., 'new_counts':{...}}
      if (response is Map<String, dynamic>) {
        return response;
      } else {
        // Handle unexpected response format from backend
        print("VoteService Error: Unexpected response format from vote endpoint: $response");
        throw Exception("Unexpected response format after voting.");
      }
    } catch (e) {
      // Log the error and rethrow for UI handling
      final target = postId != null ? "post $postId" : "reply $replyId";
      print("VoteService: Failed to process vote on $target - $e");
      rethrow;
    }
  }
}