// frontend/lib/services/api/chat_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';
// Import ChatMessageData model if created

/// Service responsible for HTTP-based chat actions
/// (fetching history, potentially sending as fallback).
/// Real-time messaging is handled by WebSocketService.
class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  /// Fetches historical chat messages for a specific community or event room.
  /// Requires authentication token and API Key.
  ///
  /// Provide exactly one of [communityId] or [eventId].
  /// [limit] specifies the maximum number of messages to fetch.
  /// [beforeId] can be used for pagination (fetches messages older than this ID).
  Future<List<dynamic>> getChatMessages({
    required String token,
    int? communityId,
    int? eventId,
    int limit = 50,
    int? beforeId,
  }) async {
    // Validate input: Ensure exactly one ID is provided
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError("Must provide exactly one of communityId or eventId.");
    }

    try {
      final queryParams = <String, String>{ // Use String keys and values for query
        'limit': limit.toString(),
      };
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (eventId != null) queryParams['event_id'] = eventId.toString();
      if (beforeId != null) queryParams['before_id'] = beforeId.toString();

      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        token: token,
        queryParams: queryParams,
      );
      // Expects List<ChatMessageData> from backend
      return response as List<dynamic>;
    } catch (e) {
      final room = communityId != null ? "community $communityId" : "event $eventId";
      print("ChatService: Failed to fetch messages for $room - $e");
      rethrow;
    }
  }

  /// Sends a chat message via HTTP POST.
  /// This might be used as a fallback if WebSocket fails, or if needed for other reasons.
  /// Requires authentication token and API Key.
  ///
  /// Provide exactly one of [communityId] or [eventId].
  Future<Map<String, dynamic>> sendChatMessageHttp({
    required String token,
    required String content,
    int? communityId,
    int? eventId,
  }) async {
    // Validate input: Ensure exactly one ID is provided
    if (!((communityId != null && eventId == null) || (communityId == null && eventId != null))) {
      throw ArgumentError("Must provide exactly one of communityId or eventId for sending message.");
    }

    try {
       final queryParams = <String, String>{};
       if (communityId != null) queryParams['community_id'] = communityId.toString();
       if (eventId != null) queryParams['event_id'] = eventId.toString();

       // Construct endpoint with query parameters
       final endpoint = Uri.parse(ApiEndpoints.chatMessages).replace(queryParameters: queryParams).path;
       // Query parameters are part of the path now for POST/PUT/DELETE if done this way,
       // Alternatively, keep them in queryParams map and pass to apiClient.post if it supports it.
       // Let's assume query params are needed for the POST endpoint structure based on backend router:
       // POST /chat/messages?community_id=X or POST /chat/messages?event_id=X

      final response = await _apiClient.post(
        endpoint, // Send endpoint path with query params appended
        token: token,
        body: {'content': content}, // JSON body with message content
        // queryParams: queryParams // Pass queryParams if apiClient.post supports it directly
      );
      // Expects the created ChatMessageData as response
      return response as Map<String, dynamic>;
    } catch (e) {
       final room = communityId != null ? "community $communityId" : "event $eventId";
      print("ChatService: Failed to send HTTP message to $room - $e");
      rethrow;
    }
  }
}
