// frontend/lib/services/api/post_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';
// Import PostDisplay model if created

/// Service responsible for post-related API calls.
class PostService {
  final ApiClient _apiClient;

  PostService(this._apiClient);

  /// Fetches a list of posts, potentially filtered.
  /// Requires API Key. User token might be optional for public viewing.
  Future<List<dynamic>> getPosts({
    String? token,
    int? communityId,
    int? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{ // Use dynamic for potential non-string values before conversion
        'limit': limit,
        'offset': offset,
      };
      if (communityId != null) queryParams['community_id'] = communityId;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _apiClient.get(
        ApiEndpoints.postsBase,
        token: token, // Pass token if provided/needed
        queryParams: queryParams.map((key, value) => MapEntry(key, value.toString())), // Convert all to string for query
      );
      return response as List<dynamic>; // Expects List<PostDisplay>
    } catch (e) {
      print("PostService: Failed to fetch posts - $e");
      rethrow;
    }
  }

  /// Fetches a list of trending posts.
  /// Requires API Key. User token might be optional.
  Future<List<dynamic>> getTrendingPosts({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.postsTrending,
        token: token, // Pass token if provided/needed
      );
      return response as List<dynamic>; // Expects List<PostDisplay>
    } catch (e) {
      print("PostService: Failed to fetch trending posts - $e");
      rethrow;
    }
  }

  // /// Fetches details for a single post (if needed).
  // Future<Map<String, dynamic>> getPostDetails(int postId, {String? token}) async {
  //   try {
  //     final response = await _apiClient.get(
  //       ApiEndpoints.postDetail(postId),
  //       token: token,
  //     );
  //     return response as Map<String, dynamic>; // Expects PostDisplay
  //   } catch (e) {
  //     print("PostService: Failed to fetch post details for ID $postId - $e");
  //     rethrow;
  //   }
  // }

  /// Creates a new post. Requires user authentication.
  Future<Map<String, dynamic>> createPost({
    required String token,
    required String title,
    required String content,
    int? communityId, // Optional community to post into
    File? image, // Optional image file
  }) async {
    try {
      final fields = {
        'title': title,
        'content': content,
      };
      if (communityId != null) {
        fields['community_id'] = communityId.toString();
      }

      List<http.MultipartFile>? files;
      if (image != null) {
        files = [await http.MultipartFile.fromPath('image', image.path)];
      }

      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.postsBase,
        token: token, // Auth token required
        fields: fields,
        files: files,
      );
      return response as Map<String, dynamic>; // Expects created PostDisplay
    } catch (e) {
      print("PostService: Failed to create post '$title' - $e");
      rethrow;
    }
  }

  /// Deletes a post. Requires user authentication (author).
  Future<void> deletePost({
    required String token,
    required int postId,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.postDetail(postId), // Use endpoint for specific post ID
        token: token,
      );
      // Expects 204 No Content
    } catch (e) {
      print("PostService: Failed to delete post $postId - $e");
      rethrow;
    }
  }

  // --- Add Post Favorite/Unfavorite methods if backend supports them ---
  // Example:
  // Future<void> favoritePost(int postId, String token) async {
  //   try {
  //     await _apiClient.post(ApiEndpoints.postFavorite(postId), token: token);
  //   } catch (e) { rethrow; }
  // }
  // Future<void> unfavoritePost(int postId, String token) async {
  //   try {
  //     await _apiClient.delete(ApiEndpoints.postFavorite(postId), token: token);
  //   } catch (e) { rethrow; }
  // }
}
