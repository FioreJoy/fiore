// frontend/lib/services/api/post_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for post-related API calls (excluding favorites).
class PostService {
  final ApiClient _apiClient;

  PostService(this._apiClient);

  // --- getPosts (no changes needed from previous version) ---
  Future<List<dynamic>> getPosts({
    String? token,
    int? communityId,
    int? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit, 'offset': offset,};
      if (communityId != null) queryParams['community_id'] = communityId;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _apiClient.get(
        ApiEndpoints.postsBase,
        token: token,
        queryParams: queryParams.map((key, value) => MapEntry(key, value.toString())),
      );
      return response as List<dynamic>;
    } catch (e) {
      print("PostService: Failed to fetch posts - $e");
      rethrow;
    }
  }

  // --- getTrendingPosts (no changes needed from previous version) ---
  // Future<List<dynamic>> getTrendingPosts({String? token}) async {
  //   try {
  //     final response = await _apiClient.get( ApiEndpoints.postsTrending, token: token, );
  //     return response as List<dynamic>;
  //   } catch (e) {
  //     print("PostService: Failed to fetch trending posts - $e");
  //     rethrow;
  //   }
  // }

  // --- createPost (no changes needed from previous version) ---
  Future<Map<String, dynamic>> createPost({
    required String token,
    required String title,
    required String content,
    int? communityId,
    File? image,
  }) async {
    try {
      final fields = {'title': title, 'content': content,};
      if (communityId != null) { fields['community_id'] = communityId.toString(); }
      List<http.MultipartFile>? files;
      if (image != null) { files = [await http.MultipartFile.fromPath('image', image.path)]; }

      final response = await _apiClient.multipartRequest(
        'POST', ApiEndpoints.postsBase, token: token, fields: fields, files: files,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("PostService: Failed to create post '$title' - $e");
      rethrow;
    }
  }

  // --- deletePost (no changes needed from previous version) ---
  Future<void> deletePost({ required String token, required int postId, }) async {
    try {
      await _apiClient.delete( ApiEndpoints.postDetail(postId), token: token,);
    } catch (e) {
      print("PostService: Failed to delete post $postId - $e");
      rethrow;
    }
  }
  Future<List<dynamic>> getTrendingPosts({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.postsTrending, // Use the trending endpoint
        token: token,
      );
      // Expects List<PostDisplay> from backend
      return response as List<dynamic>? ?? []; // Handle null defensively
    } catch (e) {
      print("PostService: Failed to fetch trending posts - $e");
      rethrow;
    }
  }
// --- Favorite methods REMOVED - Assumed handled by FavoriteService ---
// // Future<void> favoritePost(...) async { ... }
// // Future<void> unfavoritePost(...) async { ... }
}