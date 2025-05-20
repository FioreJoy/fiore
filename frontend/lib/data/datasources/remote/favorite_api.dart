// frontend/lib/services/api/favorite_service.dart

import './api_client.dart';
import './api_endpoints.dart';

/// Service responsible for managing user favorites for posts and replies.
class FavoriteService {
  final ApiClient _apiClient;

  FavoriteService(this._apiClient);

  /// Adds a post or reply to the user's favorites.
  ///
  /// Provide exactly one of [postId] or [replyId].
  /// Returns the backend response, expected to include success status and new counts.
  Future<Map<String, dynamic>> addFavorite({
    required String token,
    int? postId,
    int? replyId,
  }) async {
    if (!((postId != null && replyId == null) ||
        (postId == null && replyId != null))) {
      throw ArgumentError(
          "FavoriteService Error: Provide exactly one of postId or replyId.");
    }

    final String endpoint = postId != null
        ? ApiEndpoints.postFavorite(postId)
        : ApiEndpoints.replyFavorite(replyId!); // Use ! as one must be non-null

    final String targetType = postId != null ? "post" : "reply";
    final int targetId = postId ?? replyId!;

    try {
      //print("FavoriteService: Adding favorite -> ${targetType}Id: $targetId");
      // Use POST to add a favorite relationship
      final response = await _apiClient.post(
        endpoint,
        token: token,
        // Body might not be needed if IDs are in the path, depends on backend endpoint
        // body: {}, // Send empty body if required by POST standard
      );
      //print("FavoriteService: Response received -> $response");

      if (response is Map<String, dynamic>) {
        return response;
      } else if (response == null) {
        // Handle potential 204 No Content or similar empty success response
        //print("FavoriteService: Favorite added successfully (empty response).");
        // Return a standard success structure if backend gives empty response
        return {
          "message": "Favorited successfully",
          "success": true,
          "new_counts": {}
        }; // Counts might need separate fetch
      } else {
        //print("FavoriteService Error: Unexpected response format from favorite endpoint: $response");
        throw Exception("Unexpected response format after favoriting.");
      }
    } catch (e) {
      //print("FavoriteService: Failed to add favorite for $targetType $targetId - $e");
      rethrow;
    }
  }

  /// Removes a post or reply from the user's favorites.
  ///
  /// Provide exactly one of [postId] or [replyId].
  /// Returns the backend response, expected to include success status and new counts.
  Future<Map<String, dynamic>> removeFavorite({
    required String token,
    int? postId,
    int? replyId,
  }) async {
    if (!((postId != null && replyId == null) ||
        (postId == null && replyId != null))) {
      throw ArgumentError(
          "FavoriteService Error: Provide exactly one of postId or replyId.");
    }

    final String endpoint = postId != null
        ? ApiEndpoints.postFavorite(
            postId) // Same endpoint, different method (DELETE)
        : ApiEndpoints.replyFavorite(replyId!);

    final String targetType = postId != null ? "post" : "reply";
    final int targetId = postId ?? replyId!;

    try {
      //print("FavoriteService: Removing favorite -> ${targetType}Id: $targetId");
      // Use DELETE to remove a favorite relationship
      final response = await _apiClient.delete(
        endpoint,
        token: token,
      );
      //print("FavoriteService: Response received -> $response");

      if (response is Map<String, dynamic>) {
        return response;
      } else if (response == null) {
        // Handle potential 204 No Content or similar empty success response
        //print("FavoriteService: Favorite removed successfully (empty response).");
        // Return a standard success structure
        return {
          "message": "Unfavorited successfully",
          "success": true,
          "new_counts": {}
        }; // Counts might need separate fetch
      } else {
        //print("FavoriteService Error: Unexpected response format from unfavorite endpoint: $response");
        throw Exception("Unexpected response format after unfavoriting.");
      }
    } catch (e) {
      //print("FavoriteService: Failed to remove favorite for $targetType $targetId - $e");
      rethrow;
    }
  }
}
