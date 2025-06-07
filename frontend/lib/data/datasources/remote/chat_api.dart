// frontend/lib/data/datasources/remote/chat_api.dart
import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
import 'package:http_parser/http_parser.dart'; // For MediaType

import './api_client.dart';
import './api_endpoints.dart';

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  /// Fetches chat messages. Can be for a community, an event, or a DM.
  Future<List<dynamic>> getChatMessages({
    required String token,
    int? communityId,
    int? eventId,
    int? dmWithUserId, // New parameter for DMs
    int limit = 50,
    int? beforeId,
  }) async {
    // Validate that exactly one context (community, event, or DM) is provided
    int providedContexts = 0;
    if (communityId != null) providedContexts++;
    if (eventId != null) providedContexts++;
    if (dmWithUserId != null) providedContexts++;

    if (providedContexts != 1) {
      throw ArgumentError(
          "ChatService Error: Must provide exactly one of communityId, eventId, or dmWithUserId.");
    }

    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (communityId != null) {
        queryParams['community_id'] = communityId.toString();
      }
      if (eventId != null) {
        queryParams['event_id'] = eventId.toString();
      }
      if (dmWithUserId != null) {
        queryParams['dm_with_user_id'] = dmWithUserId.toString();
      }
      if (beforeId != null) {
        queryParams['before_id'] = beforeId.toString();
      }

      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      String roomInfo = "unknown source";
      if (communityId != null) roomInfo = "community $communityId";
      else if (eventId != null) roomInfo = "event $eventId";
      else if (dmWithUserId != null) roomInfo = "DM with user $dmWithUserId";
      print("ChatService: Failed to fetch messages for $roomInfo - $e");
      rethrow;
    }
  }

  /// Sends a chat message via HTTP (text + optional media).
  /// Can be a community, event, or DM message.
  Future<Map<String, dynamic>> sendChatMessageWithMedia({
    required String token,
    required String content,
    int? communityId,
    int? eventId,
    int? dmRecipientUserId, // New parameter for DMs
    List<File>? files,
  }) async {
    int providedContexts = 0;
    if (communityId != null) providedContexts++;
    if (eventId != null) providedContexts++;
    if (dmRecipientUserId != null) providedContexts++;

    if (providedContexts != 1) {
      throw ArgumentError(
          "ChatService Error: Must provide exactly one of communityId, eventId, or dmRecipientUserId for sending message.");
    }
    if (content.trim().isEmpty && (files == null || files.isEmpty)) {
      throw ArgumentError(
          "ChatService Error: Message content or files must be provided.");
    }

    try {
      // --- All text fields go into the 'fields' map for multipart request ---
      final fields = {'content': content.trim()};
      if (communityId != null) fields['community_id'] = communityId.toString();
      if (eventId != null) fields['event_id'] = eventId.toString();
      if (dmRecipientUserId != null) fields['dm_recipient_user_id'] = dmRecipientUserId.toString();

      List<http.MultipartFile>? filesToUpload;
      if (files != null && files.isNotEmpty) {
        filesToUpload = [];
        for (var file in files) {
          String? mimeType;
          final extension = file.path.split('.').last.toLowerCase();
          if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
          else if (extension == 'png') mimeType = 'image/png';
          else if (extension == 'gif') mimeType = 'image/gif';

          filesToUpload.add(await http.MultipartFile.fromPath(
            'files', // Backend expects a list under the key 'files'
            file.path,
            contentType: mimeType != null ? MediaType.parse(mimeType) : null,
          ));
        }
      }

      // The endpoint is the same for all types, parameters differentiate it.
      // No query parameters needed for POST if IDs are in form fields.
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.chatMessages,
        token: token,
        fields: fields, // All context IDs now go into fields
        files: filesToUpload,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      String roomInfo = "unknown source";
      if (communityId != null) roomInfo = "community $communityId";
      else if (eventId != null) roomInfo = "event $eventId";
      else if (dmRecipientUserId != null) roomInfo = "DM to user $dmRecipientUserId";
      print("ChatService: Failed to send HTTP chat message for $roomInfo - $e");
      rethrow;
    }
  }
}