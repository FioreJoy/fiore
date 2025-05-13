// frontend/lib/services/api/chat_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
import 'package:http_parser/http_parser.dart'; // For MediaType

import '../api_client.dart';
import '../api_endpoints.dart';

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  Future<List<dynamic>> getChatMessages({
    required String token,
    int? communityId,
    int? eventId,
    int limit = 50,
    int? beforeId,
  }) async {
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError("ChatService Error: Must provide exactly one of communityId or eventId.");
    }
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (eventId != null) queryParams['event_id'] = eventId.toString();
      if (beforeId != null) queryParams['before_id'] = beforeId.toString();

      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      final room = communityId != null ? "community $communityId" : "event $eventId";
      print("ChatService: Failed to fetch messages for $room - $e");
      rethrow;
    }
  }

  // --- NEW METHOD: Send Chat Message via HTTP (for text + optional media) ---
  /// Sends a chat message via HTTP, allowing for text and file attachments.
  /// The backend is expected to save the message and then broadcast it via WebSocket.
  Future<Map<String, dynamic>> sendChatMessageWithMedia({
    required String token,
    required String content,
    int? communityId,
    int? eventId,
    List<File>? files, // List of files to upload
  }) async {
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError("ChatService Error: Must provide exactly one of communityId or eventId for sending message.");
    }
    if (content.trim().isEmpty && (files == null || files.isEmpty)) {
      throw ArgumentError("ChatService Error: Message content or files must be provided.");
    }

    try {
      final fields = {'content': content.trim()};
      // Add community_id or event_id to query params as backend expects them there for POST
      final queryParams = <String, String>{};
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (eventId != null) queryParams['event_id'] = eventId.toString();

      List<http.MultipartFile>? filesToUpload;
      if (files != null && files.isNotEmpty) {
        filesToUpload = [];
        for (var file in files) {
          String? mimeType;
          final extension = file.path.split('.').last.toLowerCase();
          if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
          else if (extension == 'png') mimeType = 'image/png';
          else if (extension == 'gif') mimeType = 'image/gif';
          // Add more types if needed

          filesToUpload.add(await http.MultipartFile.fromPath(
            'files', // Backend expects a list under the key 'files'
            file.path,
            contentType: mimeType != null ? MediaType.parse(mimeType) : null,
          ));
        }
      }

      // Construct the endpoint URL with query parameters
      final uri = Uri.parse('${_apiClient.baseUrl}${ApiEndpoints.chatMessages}')
          .replace(queryParameters: queryParams);

      // Use ApiClient's multipartRequest for consistency, passing the full URI
      // Note: multipartRequest in ApiClient needs to be able to take a full Uri or build it
      // For now, let's assume we pass endpoint string and it appends query params.
      // If ApiClient.multipartRequest needs an update to handle queryParams, that's a separate step.
      // Let's assume ApiClient.multipartRequest can handle an endpoint string and we can append query params to it.
      // Or, more simply, the backend `POST /chat/messages` might accept community_id/event_id in the form fields too.
      // Let's assume they are sent as query parameters as per the existing GET.

      String endpointWithParams = ApiEndpoints.chatMessages;
      if (queryParams.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParams).query;
        endpointWithParams += '?$queryString';
      }

      print("ChatService: Sending HTTP chat message to $endpointWithParams with fields: $fields, files: ${filesToUpload?.length ?? 0}");

      final response = await _apiClient.multipartRequest(
        'POST',
        endpointWithParams, // Endpoint now includes query params
        token: token,
        fields: fields,
        files: filesToUpload,
      );
      // Backend /chat/messages POST returns the created ChatMessageData
      return response as Map<String, dynamic>;
    } catch (e) {
      final room = communityId != null ? "community $communityId" : "event $eventId";
      print("ChatService: Failed to send HTTP chat message for $room - $e");
      rethrow;
    }
  }
// --- END NEW METHOD ---
}