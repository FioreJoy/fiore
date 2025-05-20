// frontend/lib/services/api/post_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import './api_client.dart';
import './api_endpoints.dart'; // Ensure this defines postsTrending and a base for feed

class PostService {
  final ApiClient _apiClient;

  PostService(this._apiClient);

  Future<List<dynamic>> getPosts({
    String? token,
    int? communityId,
    int? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (communityId != null) queryParams['community_id'] = communityId;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _apiClient.get(
        ApiEndpoints.postsBase,
        token: token,
        queryParams:
            queryParams.map((key, value) => MapEntry(key, value.toString())),
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      //print("PostService: Failed to fetch posts - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getTrendingPosts(
      {String? token, int limit = 20, int offset = 0}) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString()
      };
      final response = await _apiClient.get(
        ApiEndpoints
            .postsTrending, // Ensure this is defined correctly in ApiEndpoints
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      //print("PostService: Failed to fetch trending posts - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getFollowingFeed({
    required String token,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString()
      };
      // Ensure ApiEndpoints.feedFollowing exists or define the string directly
      // static const String feedFollowing = '/feed/following';
      final response = await _apiClient.get(
        ApiEndpoints
            .feedFollowing, // Use the correct endpoint from ApiEndpoints
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      //print("PostService: Failed to fetch following feed - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String token,
    required String title,
    required String content,
    int? communityId,
    List<File>? images,
  }) async {
    try {
      final fields = {'title': title, 'content': content};
      if (communityId != null) {
        fields['community_id'] = communityId.toString();
      }

      List<http.MultipartFile>? filesToUpload;
      if (images != null && images.isNotEmpty) {
        filesToUpload = [];
        for (var imageFile in images) {
          String? mimeType;
          final extension = imageFile.path.split('.').last.toLowerCase();
          if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          } else if (extension == 'png'){
            mimeType = 'image/png';}
          else if (extension == 'gif') {mimeType = 'image/gif';}

          filesToUpload.add(await http.MultipartFile.fromPath(
            'files',
            imageFile.path,
            contentType: mimeType != null ? MediaType.parse(mimeType) : null,
          ));
        }
      }

      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.postsBase,
        token: token,
        fields: fields,
        files: filesToUpload,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      //print("PostService: Failed to create post '$title' - $e");
      rethrow;
    }
  }

  Future<void> deletePost({
    required String token,
    required int postId,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.postDetail(postId),
        token: token,
      );
    } catch (e) {
      //print("PostService: Failed to delete post $postId - $e");
      rethrow;
    }
  }
}

// Make sure ApiEndpoints.dart has:
// static const String feedFollowing = '/feed/following';
