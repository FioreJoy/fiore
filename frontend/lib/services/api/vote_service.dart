import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for casting votes on posts or replies.
class VoteService {
  final ApiClient _apiClient;

  VoteService(this._apiClient);

  /// Casts, updates, or removes a vote on a post or reply.
  /// Requires user authentication token and API Key.
  ///
  /// Set exactly one of [postId] or [replyId].
  /// [voteType] is true for an upvote, false for a downvote.
  /// The backend handles logic for creating, updating, or deleting the vote.
  Future<Map<String, dynamic>> castVote({
    int? postId,
    int? replyId,
    required bool voteType,
  }) async {
    // Basic validation: Ensure exactly one target is provided
    if (!((postId != null && replyId == null) || (postId == null && replyId != null))) {
      throw ArgumentError("Must provide exactly one of postId or replyId.");
    }

    try {
      final body = {
        'post_id': postId,
        'reply_id': replyId,
        'vote_type': voteType,
      };

      final response = await _apiClient.post(
        ApiEndpoints.votesBase, // Single endpoint handles create/update/delete
        body: body,
      );
      // Backend returns a message indicating action, decode it.
      return response as Map<String, dynamic>? ?? {}; // Return empty map if response was null (e.g., 204)
    } catch (e) {
      final target = postId != null ? "post $postId" : "reply $replyId";
      print("VoteService: Failed to cast vote on $target - $e");
      rethrow;
    }
  }

// Note: A dedicated GET endpoint for votes might not be necessary for the client,
// as vote counts are usually embedded in the PostDisplay/ReplyDisplay models.
// If needed, add a getVotes method here:
// Future<List<dynamic>> getVotes({int? postId, int? replyId}) async { ... }
}
