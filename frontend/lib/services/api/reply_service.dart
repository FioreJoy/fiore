// frontend/lib/services/api/reply_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
import 'package:http_parser/http_parser.dart'; // For MediaType

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for reply-related API calls (excluding favorites).
class ReplyService {
  final ApiClient _apiClient;

  ReplyService(this._apiClient);

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

  /// Creates a new reply, optionally with multiple media files.
  Future<Map<String, dynamic>> createReply({
    required String token,
    required int postId,
    required String content,
    int? parentReplyId,
    List<File>? images, // Changed from single File to List<File>
  }) async {
    try {
      // Backend expects Form data for text fields and files
      final fields = {
        'post_id': postId.toString(), // Ensure IDs are strings for form fields
        'content': content,
      };
      if (parentReplyId != null) {
        fields['parent_reply_id'] = parentReplyId.toString();
      }

      List<http.MultipartFile>? filesToUpload;
      if (images != null && images.isNotEmpty) {
        filesToUpload = [];
        for (var imageFile in images) {
          String? mimeType;
          final extension = imageFile.path.split('.').last.toLowerCase();
          if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
          else if (extension == 'png') mimeType = 'image/png';
          else if (extension == 'gif') mimeType = 'image/gif';

          filesToUpload.add(await http.MultipartFile.fromPath(
            'files', // Backend expects a list under the key 'files'
            imageFile.path,
            contentType: mimeType != null ? MediaType.parse(mimeType) : null,
          ));
        }
      }

      // Use multipartRequest from ApiClient
      final response = await _apiClient.multipartRequest(
        'POST', // Method
        ApiEndpoints.repliesBase, // Endpoint
        token: token,
        fields: fields,
        files: filesToUpload,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("ReplyService: Failed to create reply for post $postId - $e");
      rethrow;
    }
  }

  Future<void> deleteReply({ required String token, required int replyId, }) async {
    try {
      await _apiClient.delete( ApiEndpoints.replyDetail(replyId), token: token,);
    } catch (e) {
      print("ReplyService: Failed to delete reply $replyId - $e");
      rethrow;
    }
  }
}