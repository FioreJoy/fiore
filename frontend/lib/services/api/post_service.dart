// frontend/lib/services/api/post_service.dart
import 'dart:convert'; // For jsonEncode
import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
import '../api_client.dart';
import '../api_endpoints.dart'; // Make sure ApiEndpoints is imported
// Import PostDisplay or PostModel if created

/// Service responsible for post-related API calls.
class PostService {
  final ApiClient _apiClient;

  PostService(this._apiClient);

  /// Fetches a list of posts, potentially filtered.
  Future<List<dynamic>> getPosts({
    int? communityId,
    int? userId,
    int limit = 20,
    int offset = 0,
    String? sortBy, // Optional sort parameter (e.g., 'latest', 'trending')
  }) async {
    try {
      final queryParams = <String, String>{ // Ensure values are strings
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (sortBy != null) queryParams['sort_by'] = sortBy; // Add sortBy if provided

      final response = await _apiClient.get(
        ApiEndpoints.postsBase,
        queryParameters: queryParams, // Pass the map directly
      );

      // Assuming _apiClient.get returns ResponseWrapper or similar with body string
      final data = response.body;
      if (data == null) {
        throw Exception('API response body is null');
      }
      final List<dynamic> decoded = jsonDecode(data);
      return decoded; // Expects List<PostDisplay>
    } catch (e) {
      print("PostService: Failed to fetch posts - $e");
      rethrow;
    }
  }

  /// Fetches a list of trending posts.
  Future<List<dynamic>> getTrendingPosts() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.postsTrending,
      );

      final data = response.body;
      if (data == null) {
        throw Exception('API response body is null');
      }
      final List<dynamic> decoded = jsonDecode(data);
      return decoded;
    } catch (e) {
      print("PostService: Failed to fetch trending posts - $e");
      rethrow;
    }
  }

  /// Creates a new post.
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    int? communityId,
    File? image,
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

      final streamedResponse = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.postsBase,
        fields: fields,
        files: files,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to create post (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print("PostService: Failed to create post '$title' - $e");
      rethrow;
    }
  }

  /// Deletes a post.
  Future<void> deletePost({
    required int postId,
  }) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.postDetail(postId),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete post (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print("PostService: Failed to delete post $postId - $e");
      rethrow;
    }
  }

  /// Submits a vote (upvote/downvote) for a post.
  Future<void> vote({
    required int postId,
    required bool voteType, // true for upvote, false for downvote
  }) async {
    try {
      // <<< FIX: Construct the URL string directly >>>
      // TODO: Verify this URL structure matches your backend API endpoint for voting
      final String voteEndpoint = '${ApiEndpoints.postsBase}/$postId/vote';

      final String voteTypeString = voteType ? 'up' : 'down';

      final response = await _apiClient.post(
        voteEndpoint, // Use the constructed endpoint string
        body: jsonEncode({
          'vote_type': voteTypeString,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to vote on post (${response.statusCode}): ${response.body}');
      }
      print("PostService: Vote successful for post $postId (type: $voteTypeString)");
    } catch (e) {
      print("PostService: Failed to vote on post $postId - $e");
      rethrow;
    }
  }
}