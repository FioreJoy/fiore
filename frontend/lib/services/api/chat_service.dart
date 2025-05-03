// frontend/lib/services/api/chat_service.dart

import '../api_client.dart';
import '../api_endpoints.dart';
// Import ChatMessageData model if created (though service returns raw List<dynamic>)

/// Service responsible for HTTP-based chat actions (fetching history).
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
      throw ArgumentError("ChatService Error: Must provide exactly one of communityId or eventId.");
    }

    try {
      final queryParams = <String, String>{ // Use String keys and values for query
        'limit': limit.toString(),
      };
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (eventId != null) queryParams['event_id'] = eventId.toString();
      if (beforeId != null) queryParams['before_id'] = beforeId.toString();

      print("ChatService: Fetching messages with params: $queryParams"); // Debug log

      final response = await _apiClient.get(
        ApiEndpoints.chatMessages,
        token: token,
        queryParams: queryParams,
      );
      // Expects List<ChatMessageData> from backend, returned as List<dynamic>
      print("ChatService: Received ${response?.length ?? 0} messages."); // Debug log
      return response as List<dynamic>? ?? []; // Handle null response defensively
    } catch (e) {
      final room = communityId != null ? "community $communityId" : "event $eventId";
      print("ChatService: Failed to fetch messages for $room - $e");
      rethrow;
    }
  }

// Optional: Keep HTTP send method if needed as fallback or specific use case
// Future<Map<String, dynamic>> sendChatMessageHttp({ ... }) async { ... }
}