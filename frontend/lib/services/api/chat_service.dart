import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../../models/chat_message_data.dart';
import '../api_client.dart';
import '../api_endpoints.dart';

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  /// Fetch chat messages
  Future<List<ChatMessageData>> getMessages({
    int? communityId,
    int? eventId,
    int limit = 50,
    int? beforeId,
  }) async {
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      if (communityId != null) 'community_id': communityId.toString(),
      if (eventId != null) 'event_id': eventId.toString(),
      if (beforeId != null) 'before_id': beforeId.toString(),
    };

    try {
      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response;
      if (data is List) {
        return data.map((json) => ChatMessageData.fromJson(json)).toList();
      } else {
        throw Exception('Unexpected response type from getMessages.');
      }
    } catch (e) {
      print('ChatService: Error fetching messages - $e');
      rethrow;
    }
  }

  /// Upload an attachment (e.g., image)
  Future<Map<String, dynamic>> uploadAttachment(File file) async {
    final uri = Uri.parse('${_apiClient.getBaseUrl()}${ApiEndpoints.uploadAttachment}');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_apiClient.getHeaders());

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final filePart = await http.MultipartFile.fromPath(
      'image',
      file.path,
      contentType: MediaType.parse(mimeType),
    );

    request.files.add(filePart);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('url') &&
            responseData.containsKey('type') &&
            responseData.containsKey('filename')) {
          return responseData;
        } else {
          throw Exception('Unexpected response format from upload.');
        }
      } else {
        throw Exception('Failed to upload attachment: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('ChatService: Error uploading attachment - $e');
      throw Exception('Error uploading attachment: $e');
    }
  }

  /// Send a chat message
  Future<Map<String, dynamic>> sendChatMessageHttp({
    required String content,
    int? communityId,
    int? eventId,
  }) async {
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError('Provide exactly one of communityId or eventId.');
    }

    final queryParams = <String, String>{};
    if (communityId != null) queryParams['community_id'] = communityId.toString();
    if (eventId != null) queryParams['event_id'] = eventId.toString();

    final endpoint = Uri.parse(ApiEndpoints.chatMessages)
        .replace(queryParameters: queryParams)
        .path;

    try {
      final response = await _apiClient.post(
        endpoint,
        body: {'content': content},
      );

      final data = response;
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw Exception('Unexpected response type from sendChatMessageHttp.');
      }
    } catch (e) {
      final room = communityId != null ? 'community $communityId' : 'event $eventId';
      print('ChatService: Failed to send message to $room - $e');
      rethrow;
    }
  }

  /// Fetch chat messages (alternative simpler version)
  Future<List<dynamic>> getChatMessages({
    int? communityId,
    int? eventId,
    int limit = 50,
    int? beforeId,
  }) async {
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError('Provide exactly one of communityId or eventId.');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (communityId != null) 'community_id': communityId.toString(),
      if (eventId != null) 'event_id': eventId.toString(),
      if (beforeId != null) 'before_id': beforeId.toString(),
    };

    try {
      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response;
      if (data is List) {
        return data;
      } else {
        throw Exception('Unexpected response type from getChatMessages.');
      }
    } catch (e) {
      final room = communityId != null ? 'community $communityId' : 'event $eventId';
      print('ChatService: Failed to fetch messages for $room - $e');
      rethrow;
    }
  }
}
