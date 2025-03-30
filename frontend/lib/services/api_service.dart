// services/api_service.dart
import 'dart:convert';
import 'dart:async'; // For StreamController
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart'; // Import WebSocket
import 'package:web_socket_channel/status.dart' as status; // For close codes
import '../app_constants.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';
import '../models/message_model.dart'; // Assuming MessageModel exists
import '../models/chat_message_data.dart';
import '../models/event_model.dart';
class ApiService {
  // Use ws:// or wss:// for WebSocket URL
  final String baseUrl = AppConstants.baseUrl.replaceFirst('http', 'http'); // Keep HTTP for API
  final String wsBaseUrl = AppConstants.baseUrl.replaceFirst('http', 'ws');

  WebSocketChannel? _channel;
  // Ensure StreamController uses the correct ChatMessageData model
  StreamController<ChatMessageData> _messageStreamController = StreamController.broadcast();

  Stream<ChatMessageData> get messages => _messageStreamController.stream;

  // --- WebSocket Methods ---
   void connectWebSocket(String roomType, int roomId, String? token) {
     disconnectWebSocket();
     final url = '$wsBaseUrl/ws/$roomType/$roomId';
     print('Attempting to connect WebSocket: $url');
     try {
       _channel = WebSocketChannel.connect(Uri.parse(url));
       _channel!.stream.listen(
         (message) {
           print('WebSocket Received: $message');
           try {
              final decoded = jsonDecode(message);
              // Ensure ChatMessageData.fromJson is called correctly
              final chatMessage = ChatMessageData.fromJson(decoded);
              if (!_messageStreamController.isClosed) {
                  _messageStreamController.add(chatMessage);
              }
           } catch (e) {
              print('Error decoding WebSocket message: $e');
           }
         },
         onDone: () { /* ... */ },
         onError: (error) { /* ... */ },
         cancelOnError: true,
       );
       print('WebSocket connected successfully.');
     } catch (e) {
         print('WebSocket connection failed: $e');
          if (!_messageStreamController.isClosed) {
             _messageStreamController.addError('WebSocket Connection Failed: $e');
          }
     }
   }

   void disconnectWebSocket() {
     if (_channel != null) {
       print('Closing WebSocket connection...');
       _channel!.sink.close(status.goingAway);
       _channel = null;
     }
   }

   void sendWebSocketMessage(String message) {
     if (_channel != null && _channel?.closeCode == null) {
        print('WebSocket Sending: $message');
       _channel!.sink.add(message);
     } else {
         print('WebSocket not connected, cannot send message.');
     }
   }

  // --- Helper for HTTP ---
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
     print("Response Status: ${response.statusCode}");
     print("Response Body: ${response.body}"); // Log the raw body

    if (response.statusCode >= 200 && response.statusCode < 300) {
       if (response.body.isEmpty) {
            // Handle cases like 204 No Content
            if (response.statusCode == 204) return {"message": "Operation successful (No Content)"};
            return {}; // Return empty map for other empty bodies
       }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print('JSON Decode Error: $e');
        throw Exception('Failed to parse JSON response. Body: ${response.body}');
      }
    } else {
      String detail = 'Unknown error';
      try {
         if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            detail = errorBody['detail'] ?? response.body; // Use raw body if detail key is missing
         } else {
             detail = response.reasonPhrase ?? 'Status code ${response.statusCode}';
         }
      } catch (e) {
        detail = response.body.isNotEmpty ? response.body : 'Status code ${response.statusCode}';
      }
      print('API Error: ${response.statusCode} - $detail');
      throw Exception('Request failed: $detail'); // Throw with detail
    }
  }

  // --- Auth ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$baseUrl/login';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> signup(
      String name,
      String username,
      String email,
      String password,
      String gender,
      String currentLocation, // Expects POINT string like '(lon,lat)'
      String college,
      List<String> interests,
      Uint8List? imageBytes,
      String? imageFileName) async {
    final url = Uri.parse('$baseUrl/signup');
    var request = http.MultipartRequest('POST', url);

    request.fields['name'] = name;
    request.fields['username'] = username;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['gender'] = gender;
    request.fields['current_location'] = currentLocation;
    request.fields['college'] = college;
    // Send interests as separate fields if backend expects List[str] = Form(...)
    interests.asMap().forEach((index, interest) {
       request.fields['interests[$index]'] = interest;
    });
    // Alternatively, if backend expects a JSON string:
    // request.fields['interests'] = jsonEncode(interests);

    if (imageBytes != null && imageFileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFileName,
          contentType: MediaType('image', _getFileExtension(imageFileName)),
        ),
      );
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  String _getFileExtension(String fileName) {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      // Basic check for common image types
      const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
      return validExtensions.contains(ext) ? ext : 'jpeg'; // Default
    } catch (e) {
      return 'jpeg'; // Default
    }
  }

  Future<Map<String, dynamic>> fetchUserDetails(String token) async {
    final url = Uri.parse('$baseUrl/me');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response); // Use handler
  }

  // --- Posts ---
  Future<List<dynamic>> fetchPosts(String? token, {int? communityId, int? userId}) async {
    // Build query parameters
    final Map<String, String> queryParams = {};
    if (communityId != null) queryParams['community_id'] = communityId.toString();
    if (userId != null) queryParams['user_id'] = userId.toString();

    final url = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    print("Fetching posts from URL: $url");

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(url, headers: headers);
    final data = await _handleResponse(response);
    return (data['posts'] as List<dynamic>?) ?? [];
  }

   Future<List<dynamic>> fetchTrendingPosts(String? token) async {
    final url = Uri.parse('$baseUrl/posts/trending');
    print("Fetching trending posts from URL: $url");
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(url, headers: headers);
    final data = await _handleResponse(response);
    return (data['posts'] as List<dynamic>?) ?? [];
  }


  Future<Map<String, dynamic>> createPost(
      String title, String content, int? communityId, String token) async {
    final url = '$baseUrl/posts';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'title': title,
        'content': content,
        'community_id': communityId,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deletePost(String postId, String token) async {
    final url = '$baseUrl/posts/$postId';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
     // Delete returns 204 No Content on success typically
     if (response.statusCode == 204) {
       return {"message": "Post deleted successfully"};
     }
     return _handleResponse(response); // Handle potential errors
  }

  // --- Communities ---
   Future<List<dynamic>> fetchCommunities(String? token) async {
    final url = Uri.parse('$baseUrl/communities');
     print("Fetching communities from URL: $url");
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(url, headers: headers);
    final data = await _handleResponse(response);
    return (data['communities'] as List<dynamic>?) ?? [];
  }

   Future<List<dynamic>> fetchTrendingCommunities(String? token) async {
    final url = Uri.parse('$baseUrl/communities/trending');
    print("Fetching trending communities from URL: $url");
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(url, headers: headers);
    final data = await _handleResponse(response);
    return (data['communities'] as List<dynamic>?) ?? [];
  }

   Future<Map<String, dynamic>> fetchCommunityDetails(String communityId, String? token) async {
    final url = Uri.parse('$baseUrl/communities/$communityId/details');
    print("Fetching community details from URL: $url");
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createCommunity(String name, String? description, String primaryLocation, String? interest, String token) async {
      final url = '$baseUrl/communities';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'name': name,
          'description': description, // Now optional
          'primary_location': primaryLocation,
          'interest': interest, // Added interest
        }),
      );
      return _handleResponse(response);
   }

  Future<Map<String, dynamic>> deleteCommunity(String communityId, String token) async {
    final url = '$baseUrl/communities/$communityId';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
      if (response.statusCode == 204) {
       return {"message": "Community deleted successfully"};
     }
    return _handleResponse(response);
  }

  // --- Voting (Unified Endpoint Call) ---
  Future<Map<String, dynamic>> vote(
      {int? postId, int? replyId, required bool voteType, required String token}) async {
    final url = '$baseUrl/votes';
    final Map<String, dynamic> body = {'vote_type': voteType};
    if (postId != null) body['post_id'] = postId;
    if (replyId != null) body['reply_id'] = replyId;

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // --- Replies ---
  Future<Map<String, dynamic>> createReply(
      int postId, String content, int? parentReplyId, String token) async {
    final url = '$baseUrl/replies';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'post_id': postId,
        'content': content,
        'parent_reply_id': parentReplyId,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> fetchReplies(String postId, String? token) async {
    final url = '$baseUrl/replies/$postId';
     print("Fetching replies from URL: $url");
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(Uri.parse(url), headers: headers);
    final data = await _handleResponse(response);
    return (data['replies'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> deleteReply(String replyId, String token) async {
    final url = '$baseUrl/replies/$replyId';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
      if (response.statusCode == 204) {
       return {"message": "Reply deleted successfully"};
     }
    return _handleResponse(response);
  }

  // --- Membership, Favorites, Community Posts (Methods already provided seem okay, ensure token is passed) ---
    Future<Map<String, dynamic>> joinCommunity(String communityId, String token) async {
    final url = '$baseUrl/communities/$communityId/join';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> leaveCommunity(String communityId, String token) async {
    final url = '$baseUrl/communities/$communityId/leave';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> favoritePost(String postId, String token) async {
    final url = '$baseUrl/posts/$postId/favorite';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> unfavoritePost(String postId, String token) async {
    final url = '$baseUrl/posts/$postId/unfavorite';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> favoriteReply(String replyId, String token) async {
    final url = '$baseUrl/replies/$replyId/favorite';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> unfavoriteReply(String replyId, String token) async {
    final url = '$baseUrl/replies/$replyId/unfavorite';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> addPostToCommunity(
      String communityId, String postId, String token) async {
    final url = '$baseUrl/communities/$communityId/add_post/$postId';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'}, // Make sure auth is checked backend-side
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> removePostFromCommunity(
      String communityId, String postId, String token) async {
    final url = '$baseUrl/communities/$communityId/remove_post/$postId';
    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'}, // Make sure auth is checked backend-side
    );
    return _handleResponse(response);
  }

   // --- Chat (HTTP Methods) ---
   Future<List<dynamic>> fetchChatMessages({int? communityId, int? eventId, int? beforeId, int limit = 50, String? token}) async {
      final Map<String, String> queryParams = {'limit': limit.toString()};
      if (communityId != null) queryParams['community_id'] = communityId.toString();
      if (eventId != null) queryParams['event_id'] = eventId.toString(); // Corrected variable name
      if (beforeId != null) queryParams['before_id'] = beforeId.toString();

      final url = Uri.parse('$baseUrl/chat/messages').replace(queryParameters: queryParams);
      print("Fetching chat messages from URL: $url");

      final Map<String, String> headers = {};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(url, headers: headers);
      final data = await _handleResponse(response);
      return (data['messages'] as List<dynamic>?) ?? [];
   }

    Future<Map<String, dynamic>> sendChatMessageHttp(String content, int? communityId, int? eventId, String token) async {
       final url = Uri.parse('$baseUrl/chat/messages');
       final Map<String, String> queryParams = {};
       if (communityId != null) queryParams['community_id'] = communityId.toString();
       if (eventId != null) queryParams['event_id'] = eventId.toString(); // Corrected variable name

       final response = await http.post(
         url.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null), // Add query params if present
         headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
         body: jsonEncode({'content': content}),
       );
       return _handleResponse(response);
     }

  Future<EventModel> createEvent(
      int communityId, String title, String? description, String location,
      DateTime eventTimestamp, int maxParticipants, String token) async {
    final url = '$baseUrl/communities/$communityId/events';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'location': location,
        'event_timestamp': eventTimestamp.toUtc().toIso8601String(), // Send as UTC ISO string
        'max_participants': maxParticipants,
      }),
    );
    final data = await _handleResponse(response);
    return EventModel.fromJson(data); // Assuming EventModel.fromJson exists
  }

  Future<List<EventModel>> fetchCommunityEvents(int communityId, String? token) async {
    final url = '$baseUrl/communities/$communityId/events';
    final Map<String, String> headers = {};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(Uri.parse(url), headers: headers);
    final data = await _handleResponse(response); // _handleResponse returns Map<String, dynamic>
    // Assuming the API returns a list under a key, e.g., "events"
    final eventList = data['events'] as List<dynamic>? ?? [];
    return eventList.map((eventJson) => EventModel.fromJson(eventJson)).toList();
  }

  Future<EventModel> fetchEventDetails(int eventId, String? token) async {
    final url = '$baseUrl/events/$eventId';
     final Map<String, String> headers = {};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(Uri.parse(url), headers: headers);
    final data = await _handleResponse(response);
    return EventModel.fromJson(data);
  }

  Future<EventModel> updateEvent(int eventId, Map<String, dynamic> updateData, String token) async {
     // Filter out null values from updateData before sending if needed
     updateData.removeWhere((key, value) => value == null);
     // Convert DateTime to ISO string if present
     if (updateData.containsKey('event_timestamp') && updateData['event_timestamp'] is DateTime) {
        updateData['event_timestamp'] = (updateData['event_timestamp'] as DateTime).toUtc().toIso8601String();
     }

     final url = '$baseUrl/events/$eventId';
     final response = await http.put(
       Uri.parse(url),
       headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
       body: jsonEncode(updateData),
     );
     final data = await _handleResponse(response);
     return EventModel.fromJson(data);
   }

   Future<Map<String, dynamic>> deleteEvent(int eventId, String token) async {
     final url = '$baseUrl/events/$eventId';
     final response = await http.delete(
       Uri.parse(url),
       headers: {'Authorization': 'Bearer $token'},
     );
     if (response.statusCode == 204) {
       return {"message": "Event deleted successfully"};
     }
     return _handleResponse(response);
   }

   Future<Map<String, dynamic>> joinEvent(String eventId, String token) async {
     // Assuming backend takes String ID, adjust if it takes int
     final url = '$baseUrl/events/$eventId/join';
     final response = await http.post(
       Uri.parse(url),
       headers: {'Authorization': 'Bearer $token'},
     );
     return _handleResponse(response);
   }

   Future<Map<String, dynamic>> leaveEvent(String eventId, String token) async {
      // Assuming backend takes String ID, adjust if it takes int
     final url = '$baseUrl/events/$eventId/leave';
     final response = await http.delete(
       Uri.parse(url),
       headers: {'Authorization': 'Bearer $token'},
     );
     return _handleResponse(response);
   }

  // --- Cleanup ---
  void dispose() {
    disconnectWebSocket();
     if (!_messageStreamController.isClosed) { // Check before closing
        _messageStreamController.close();
     }
    print("ApiService disposed.");
  }
}

// --- Mock Methods (Keep for reference or testing, but comment out) ---
/*
Future<List<dynamic>> fetchMessages(String chatroomId, String? token) async {
  print("Mock Fetching messages for $chatroomId");
  await Future.delayed(const Duration(milliseconds: 500));
  return MessageModel.getMockMessages().map((m) => {
    'id': m.id,
    'user_id': m.userId,
    'username': m.username,
    'content': m.content,
    'timestamp': m.timestamp.toIso8601String(),
    'is_current_user': m.isCurrentUser,
    'reactions': m.reactions,
    'image_url': m.imageUrl,
  }).toList();
}

Future<Map<String, dynamic>> sendMessage(
    String chatroomId, String message, String token) async {
  print("Mock Sending message '$message' to $chatroomId");
  await Future.delayed(const Duration(milliseconds: 300));
  return {
    'message': 'Message sent successfully (mock)',
    'message_id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
  };
}
*/