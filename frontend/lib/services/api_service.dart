// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'dart:io'; // For File type
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:web_socket_channel/web_socket_channel.dart'; // Existing WS
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async'; // For StreamController

import '../app_constants.dart';
import '../models/event_model.dart';
import '../models/chat_message_data.dart';
// Import other models as needed (e.g., PostDisplay, CommunityDisplay, UserDisplay etc.)

class ApiService {
  final String baseUrl = AppConstants.baseUrl; // Use base URL without port for standard deploy

  // WebSocket related properties
  WebSocketChannel? _channel;
  StreamController<ChatMessageData> _messageController = StreamController.broadcast();
  Stream<ChatMessageData> get messages => _messageController.stream;
  bool _isConnecting = false;
  String? _currentWsToken;
  String? _currentWsRoomType;
  int? _currentWsRoomId;

  void disposeWebSocket() {
    _channel?.sink.close(status.goingAway);
    _messageController.close(); // Close the stream controller
    _channel = null;
    _isConnecting = false;
    _currentWsToken = null;
    _currentWsRoomId = null;
    _currentWsRoomType = null;
    // Recreate controller if service is reused (depends on Provider scope)
    if (_messageController.isClosed) {
      _messageController = StreamController.broadcast();
    }
  }


  // --- Helper for Headers ---
  Map<String, String> _getAuthHeaders(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Authentication ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body); // Expecting {token, user_id, image_url?}
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print("Login Error: $e");
      throw Exception('Network error during login: $e');
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String gender,
    required String currentLocation, // Assuming "(lon,lat)" format
    required String college,
    required List<String> interests,
    File? image, // Accept File object
    // Token not usually needed for signup itself
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    var request = http.MultipartRequest('POST', url);

    // Add text fields
    request.fields['name'] = name;
    request.fields['username'] = username;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['gender'] = gender;
    request.fields['current_location'] = currentLocation;
    request.fields['college'] = college;
    // Send interests as multiple form fields with the same key
    for (String interest in interests) {
      request.fields['interests'] = interest;
    }


    // Add image file if provided
    if (image != null) {
      try {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // Field name expected by backend
            image.path,
            contentType: MediaType('image', image.path.split('.').last), // Guess content type
          ),
        );
      } catch (e) {
        print("Error attaching image file: $e");
        // Decide how to handle: fail signup or continue without image?
        // For now, we let it continue, backend handles missing image path.
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body); // Expecting {token, user_id, image_url?}
      } else {
        print('Signup failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Signup failed');
        } catch(_){ // Handle cases where body is not valid JSON
          throw Exception('Signup failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Signup network error: $e');
      throw Exception('Network error during signup: $e');
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String? token) async {
    if (token == null) throw Exception('Authentication token is missing');
    final url = Uri.parse('$baseUrl/auth/me');
    try {
      final response = await http.get(
        url,
        headers: _getAuthHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body); // Expect UserDisplay schema
      } else {
        throw Exception('Failed to load user data (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch User Error: $e");
      throw Exception('Network error fetching user data: $e');
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String token,
    String? name,
    String? username,
    String? gender,
    String? currentLocation, // Send "(lon,lat)" string
    String? college,
    List<String>? interests,
    File? image,
  }) async {
    final url = Uri.parse('$baseUrl/auth/me');
    var request = http.MultipartRequest('PUT', url);

    // Add headers
    request.headers['Authorization'] = 'Bearer $token';
    // Content-Type is set automatically for multipart

    // Add text fields that are not null
    if (name != null) request.fields['name'] = name;
    if (username != null) request.fields['username'] = username;
    if (gender != null) request.fields['gender'] = gender;
    if (currentLocation != null) request.fields['current_location'] = currentLocation;
    if (college != null) request.fields['college'] = college;
    if (interests != null) {
      // Backend expects multiple 'interests' fields for a list
      for (String interest in interests) {
        request.fields['interests'] = interest;
      }
    }

    // Add image file if provided
    if (image != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath('image', image.path,
            contentType: MediaType('image', image.path.split('.').last)));
      } catch (e) {
        print("Error attaching profile image file: $e");
        // Decide how to handle: fail or continue without image?
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body); // Backend returns updated UserDisplay
      } else {
        print('Update Profile failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to update profile');
        } catch(_){
          throw Exception('Update profile failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Update Profile network error: $e');
      throw Exception('Network error during profile update: $e');
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword, String token) async {
    final url = Uri.parse('$baseUrl/auth/me/password');
    try {
      final response = await http.put(
        url,
        headers: _getAuthHeaders(token), // Uses helper
        body: json.encode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 204) { // Expect 204 No Content on success
        print('Change Password failed: ${response.statusCode} ${response.body}');
        String detail = 'Failed to change password';
        try {
          final errorBody = json.decode(response.body);
          detail = errorBody['detail'] ?? detail;
        } catch (_) {}
        throw Exception(detail);
      }
      // Success, no return needed
    } catch (e) {
      print("Change Password Error: $e");
      throw Exception('Network error changing password: $e');
    }
  }

  Future<void> deleteAccount(String token) async {
    final url = Uri.parse('$baseUrl/auth/me');
    try {
      final response = await http.delete(
        url,
        headers: _getAuthHeaders(token), // No Content-Type needed for DELETE usually
      );

      if (response.statusCode != 204) {
        print('Delete Account failed: ${response.statusCode} ${response.body}');
        String detail = 'Failed to delete account';
        try {
          final errorBody = json.decode(response.body);
          detail = errorBody['detail'] ?? detail;
        } catch (_) {}
        throw Exception(detail);
      }
      // Success, no return needed
    } catch (e) {
      print("Delete Account Error: $e");
      throw Exception('Network error deleting account: $e');
    }
  }

  // --- Posts ---
  Future<List<dynamic>> fetchPosts(String? token, {int? communityId, int? userId, int limit = 20, int offset = 0}) async {
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (communityId != null) queryParams['community_id'] = communityId.toString();
    if (userId != null) queryParams['user_id'] = userId.toString();

    final url = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams);

    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of PostDisplay
      } else {
        throw Exception('Failed to load posts (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Posts Error: $e");
      throw Exception('Network error fetching posts: $e');
    }
  }

  Future<List<dynamic>> fetchTrendingPosts(String? token) async {
    final url = Uri.parse('$baseUrl/posts/trending');
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of PostDisplay
      } else {
        throw Exception('Failed to load trending posts (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Trending Posts Error: $e");
      throw Exception('Network error fetching trending posts: $e');
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    int? communityId,
    File? image, // Add image file
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/posts');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['content'] = content;
    if (communityId != null) {
      request.fields['community_id'] = communityId.toString();
    }
    if (image != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath('image', image.path,
            contentType: MediaType('image', image.path.split('.').last)));
      } catch (e) {
        print("Error attaching post image file: $e");
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) { // Expect 201 Created
        return json.decode(response.body); // Expect PostDisplay
      } else {
        print('Create Post failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to create post');
        } catch(_){
          throw Exception('Create post failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Create Post network error: $e');
      throw Exception('Network error during post creation: $e');
    }
  }

  // --- Communities ---
  Future<List<dynamic>> fetchCommunities(String? token) async {
    final url = Uri.parse('$baseUrl/communities');
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of CommunityDisplay
      } else {
        throw Exception('Failed to load communities (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Communities Error: $e");
      throw Exception('Network error fetching communities: $e');
    }
  }

  Future<List<dynamic>> fetchTrendingCommunities(String? token) async {
    final url = Uri.parse('$baseUrl/communities/trending');
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of CommunityDisplay
      } else {
        throw Exception('Failed to load trending communities (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Trending Communities Error: $e");
      throw Exception('Network error fetching trending communities: $e');
    }
  }

  Future<Map<String, dynamic>> createCommunity({ // Named parameters
    required String name,
    String? description,
    required String primaryLocation, // e.g., "(lon,lat)"
    required String interest,
    File? logo, // Add logo file
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/communities');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;
    if (description != null) request.fields['description'] = description;
    request.fields['primary_location'] = primaryLocation;
    request.fields['interest'] = interest;

    if (logo != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath('logo', logo.path, // Field name 'logo'
            contentType: MediaType('image', logo.path.split('.').last)));
      } catch (e) {
        print("Error attaching community logo file: $e");
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) { // Expect 201 Created
        return json.decode(response.body); // Expect CommunityDisplay
      } else {
        print('Create Community failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to create community');
        } catch(_){
          throw Exception('Create community failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Create Community network error: $e');
      throw Exception('Network error during community creation: $e');
    }
  }

  Future<void> joinCommunity(String communityId, String token) async {
    final url = Uri.parse('$baseUrl/communities/$communityId/join');
    try {
      final response = await http.post(url, headers: _getAuthHeaders(token));
      if (response.statusCode != 200) { // Expect 200 OK
        throw Exception('Failed to join community (${response.statusCode})');
      }
    } catch (e) {
      print("Join Community Error: $e");
      throw Exception('Network error joining community: $e');
    }
  }

  Future<void> leaveCommunity(String communityId, String token) async {
    final url = Uri.parse('$baseUrl/communities/$communityId/leave');
    try {
      final response = await http.delete(url, headers: _getAuthHeaders(token));
      if (response.statusCode != 200) { // Expect 200 OK
        throw Exception('Failed to leave community (${response.statusCode})');
      }
    } catch (e) {
      print("Leave Community Error: $e");
      throw Exception('Network error leaving community: $e');
    }
  }

  // --- Events ---
  Future<List<EventModel>> fetchCommunityEvents(int communityId, String token) async {
    final url = Uri.parse('$baseUrl/communities/$communityId/events');
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => EventModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load community events (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Community Events Error: $e");
      throw Exception('Network error fetching community events: $e');
    }
  }

  Future<EventModel> createEvent({ // Named params
    required int communityId,
    required String title,
    String? description,
    required String location,
    required DateTime eventTimestamp,
    required int maxParticipants,
    File? image, // Add image file
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/communities/$communityId/events'); // Endpoint under community
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;
    request.fields['location'] = location;
    request.fields['event_timestamp'] = eventTimestamp.toUtc().toIso8601String(); // Send ISO string
    request.fields['max_participants'] = maxParticipants.toString();

    if (image != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath('image', image.path,
            contentType: MediaType('image', image.path.split('.').last)));
      } catch (e) {
        print("Error attaching event image file: $e");
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) { // Expect 201 Created
        return EventModel.fromJson(json.decode(response.body)); // Expect EventDisplay
      } else {
        print('Create Event failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to create event');
        } catch(_){
          throw Exception('Create event failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Create Event network error: $e');
      throw Exception('Network error during event creation: $e');
    }
  }

  Future<void> joinEvent(String eventId, String token) async {
    final url = Uri.parse('$baseUrl/events/$eventId/join');
    try {
      final response = await http.post(url, headers: _getAuthHeaders(token));
      if (response.statusCode != 200) { // Expect 200 OK
        // Check for specific error like "Event is full"
        String detail = 'Failed to join event';
        try {
          final errorBody = json.decode(response.body);
          detail = errorBody['detail'] ?? detail;
        } catch (_) {}
        throw Exception('$detail (${response.statusCode})');
      }
    } catch (e) {
      print("Join Event Error: $e");
      // Rethrow the specific exception if it was parsed
      if (e is Exception && e.toString().contains("Event is full")) {
        throw e;
      }
      throw Exception('Network error joining event: $e');
    }
  }

  Future<void> leaveEvent(String eventId, String token) async {
    final url = Uri.parse('$baseUrl/events/$eventId/leave');
    try {
      final response = await http.delete(url, headers: _getAuthHeaders(token));
      if (response.statusCode != 200) { // Expect 200 OK
        throw Exception('Failed to leave event (${response.statusCode})');
      }
    } catch (e) {
      print("Leave Event Error: $e");
      throw Exception('Network error leaving event: $e');
    }
  }

  // --- Chat & WebSockets ---
  Future<List<ChatMessageData>> fetchChatMessages({
    int? communityId,
    int? eventId,
    required String token,
    int limit = 50,
    int? beforeId,
  }) async {
    final Map<String, String> queryParams = {'limit': limit.toString()};
    if (communityId != null) queryParams['community_id'] = communityId.toString();
    if (eventId != null) queryParams['event_id'] = eventId.toString();
    if (beforeId != null) queryParams['before_id'] = beforeId.toString();

    final url = Uri.parse('$baseUrl/chat/messages').replace(queryParameters: queryParams);
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => ChatMessageData.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load chat messages (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Chat Messages Error: $e");
      throw Exception('Network error fetching chat messages: $e');
    }
  }

  // Method to send via HTTP (potentially as fallback or primary if WS fails)
  Future<ChatMessageData> sendChatMessageHttp({
    required String content,
    int? communityId,
    int? eventId,
    required String token,
  }) async {
    final Map<String, String> queryParams = {};
    if (communityId != null) queryParams['community_id'] = communityId.toString();
    if (eventId != null) queryParams['event_id'] = eventId.toString();

    final url = Uri.parse('$baseUrl/chat/messages').replace(queryParameters: queryParams);
    try {
      final response = await http.post(
        url,
        headers: _getAuthHeaders(token),
        body: json.encode({'content': content}),
      );
      if (response.statusCode == 201) { // Expect 201 Created
        return ChatMessageData.fromJson(json.decode(response.body));
      } else {
        print('Send Chat HTTP failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to send message');
        } catch(_){
          throw Exception('Send message failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Send Chat HTTP network error: $e');
      throw Exception('Network error sending message: $e');
    }
  }


  // WebSocket Connection Logic (Using web_socket_channel)
  // NOTE: This uses the existing library. Switching to Socket.IO would replace this.
  void connectWebSocket(String roomType, int roomId, String? token) {
    if (_isConnecting || (_channel != null && _channel?.closeCode == null)) {
      // Avoid reconnecting if already connected or connecting
      // Or if the target room is the same
      if (_currentWsRoomType == roomType && _currentWsRoomId == roomId) {
        print("WebSocket already connected/connecting to $roomType $roomId.");
        return;
      } else {
        // Switching rooms, disconnect existing first
        print("Switching WebSocket room... disconnecting previous.");
        disconnectWebSocket();
      }
    }
    if (token == null) {
      print("WebSocket connection aborted: Token is missing.");
      return;
    }

    _isConnecting = true;
    _currentWsToken = token;
    _currentWsRoomType = roomType;
    _currentWsRoomId = roomId;

    // Construct WS URL (replace ws:// if using secure backend wss://)
    // Pass token as query parameter for backend auth
    final wsBaseUrl = baseUrl.replaceFirst('http', 'ws');
    final url = Uri.parse('$wsBaseUrl/ws/$roomType/$roomId?token=$token');
    print("Connecting WebSocket to: $url");

    try {
      _channel = WebSocketChannel.connect(url);
      _isConnecting = false;
      print("WebSocket connection established to $roomType $roomId.");

      _channel!.stream.listen(
            (message) {
          // print("WS Received: $message");
          try {
            final data = json.decode(message);
            final chatMessage = ChatMessageData.fromJson(data);
            // Add safety check: ensure controller is not closed
            if (!_messageController.isClosed) {
              _messageController.add(chatMessage);
            }
          } catch (e) {
            print("Error parsing WebSocket message: $e");
            if (!_messageController.isClosed) {
              _messageController.addError(e); // Propagate error
            }
          }
        },
        onDone: () {
          print("WebSocket disconnected (onDone). Close Code: ${_channel?.closeCode}");
          if (!_messageController.isClosed) {
            _messageController.addError(Exception("WebSocket disconnected")); // Notify listeners
          }
          _channel = null; // Clear channel state
          _isConnecting = false;
          // Optional: Implement reconnection logic here if needed
          // _scheduleReconnection();
        },
        onError: (error) {
          print("WebSocket error: $error");
          if (!_messageController.isClosed) {
            _messageController.addError(error);
          }
          _channel = null; // Clear channel state
          _isConnecting = false;
          // Optional: Implement reconnection logic here
          // _scheduleReconnection();
        },
        cancelOnError: false, // Keep listening even after an error? Maybe true better?
      );
    } catch (e) {
      print("WebSocket connection failed: $e");
      _isConnecting = false;
      if (!_messageController.isClosed) {
        _messageController.addError(e);
      }
      // Handle connection error (e.g., schedule retry)
    }
  }

  void disconnectWebSocket() {
    if (_channel != null) {
      print("Closing WebSocket connection...");
      _channel?.sink.close(status.normalClosure);
      _channel = null;
    }
    _isConnecting = false; // Reset connection flag
    _currentWsRoomType = null;
    _currentWsRoomId = null;
    // Don't clear token here, might be needed for next connection attempt
  }

  void sendWebSocketMessage(String messageJson) {
    if (_channel != null && _channel?.closeCode == null) {
      // print("WS Sending: $messageJson");
      _channel!.sink.add(messageJson);
    } else {
      print("Cannot send message: WebSocket not connected.");
      // Optionally throw an error or try fallback to HTTP
      // throw Exception("WebSocket not connected");
      // Fallback Example (Consider carefully if this is desired behavior):
      // _fallbackSendHttp(messageJson);
    }
  }

  // Example fallback (use with caution, might double-send)
  // void _fallbackSendHttp(String messageJson) async {
  //    try {
  //       final content = json.decode(messageJson)['content'];
  //       if (content != null && _currentWsToken != null && (_currentWsRoomId != null || _currentWsCommunityId != null)) { // Need community ID too
  //          print("WebSocket failed, falling back to HTTP POST...");
  //          await sendChatMessageHttp(
  //             content: content,
  //             // Determine community/event ID based on current state
  //             communityId: _currentWsRoomType == 'community' ? _currentWsRoomId : null, // Needs logic
  //             eventId: _currentWsRoomType == 'event' ? _currentWsRoomId : null,
  //             token: _currentWsToken!,
  //          );
  //       }
  //    } catch (e) {
  //       print("Fallback HTTP send failed: $e");
  //    }
  // }


  // --- Replies ---
  Future<List<dynamic>> fetchRepliesForPost(int postId, String? token) async {
    final url = Uri.parse('$baseUrl/replies/$postId');
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of ReplyDisplay
      } else {
        throw Exception('Failed to load replies (${response.statusCode})');
      }
    } catch (e) {
      print("Fetch Replies Error: $e");
      throw Exception('Network error fetching replies: $e');
    }
  }

  Future<Map<String, dynamic>> createReply({
    required int postId,
    required String content,
    int? parentReplyId,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/replies');
    try {
      final response = await http.post(
        url,
        headers: _getAuthHeaders(token),
        body: json.encode({
          'post_id': postId,
          'content': content,
          'parent_reply_id': parentReplyId, // Will be null if not provided
        }),
      );
      if (response.statusCode == 201) { // Expect 201 Created
        return json.decode(response.body); // Expect ReplyDisplay
      } else {
        print('Create Reply failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to create reply');
        } catch(_){
          throw Exception('Create reply failed with status code ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Create Reply network error: $e');
      throw Exception('Network error creating reply: $e');
    }
  }

  // --- Votes ---
  Future<void> castVote({
    int? postId,
    int? replyId,
    required bool voteType, // true=upvote, false=downvote
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/votes');
    if ((postId == null && replyId == null) || (postId != null && replyId != null)) {
      throw ArgumentError("Must provide exactly one of postId or replyId");
    }
    try {
      final response = await http.post(
        url,
        headers: _getAuthHeaders(token),
        body: json.encode({
          'post_id': postId,
          'reply_id': replyId,
          'vote_type': voteType,
        }),
      );
      if (response.statusCode != 200) { // Expect 200 OK
        print('Vote failed: ${response.statusCode} ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          throw Exception(errorBody['detail'] ?? 'Failed to cast vote');
        } catch(_){
          throw Exception('Vote failed with status code ${response.statusCode}');
        }
      }
      // Success, response body might contain updated counts or status message
      // print("Vote response: ${response.body}");
    } catch (e) {
      print('Cast Vote network error: $e');
      throw Exception('Network error casting vote: $e');
    }
  }

  // --- Settings Endpoints ---
  Future<Map<String, dynamic>> getNotificationSettings(String token) async {
    final url = Uri.parse('$baseUrl/settings/notifications'); // ADJUST ENDPOINT AS NEEDED
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load notification settings (${response.statusCode})');
      }
    } catch (e) {
      print("Get Notification Settings Error: $e");
      throw Exception('Network error getting notification settings: $e');
    }
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings, String token) async {
    final url = Uri.parse('$baseUrl/settings/notifications'); // ADJUST ENDPOINT AS NEEDED
    try {
      final response = await http.put(
        url,
        headers: _getAuthHeaders(token),
        body: json.encode(settings),
      );
      if (response.statusCode != 200) { // Or 204
        throw Exception('Failed to update notification settings (${response.statusCode})');
      }
    } catch (e) {
      print("Update Notification Settings Error: $e");
      throw Exception('Network error updating notification settings: $e');
    }
  }

  // --- Blocking Endpoints ---
  Future<List<dynamic>> getBlockedUsers(String token) async {
    final url = Uri.parse('$baseUrl/users/me/blocked'); // ADJUST ENDPOINT AS NEEDED
    try {
      final response = await http.get(url, headers: _getAuthHeaders(token));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List; // Expect list of BlockedUserDisplay
      } else {
        throw Exception('Failed to load blocked users (${response.statusCode})');
      }
    } catch (e) {
      print("Get Blocked Users Error: $e");
      throw Exception('Network error getting blocked users: $e');
    }
  }

  Future<void> blockUser(int userIdToBlock, String token) async {
    final url = Uri.parse('$baseUrl/users/me/block/$userIdToBlock'); // ADJUST ENDPOINT AS NEEDED
    try {
      final response = await http.post(url, headers: _getAuthHeaders(token)); // POST to block
      if (response.statusCode != 200 && response.statusCode != 204) { // Allow OK or No Content
        throw Exception('Failed to block user (${response.statusCode})');
      }
    } catch (e) {
      print("Block User Error: $e");
      throw Exception('Network error blocking user: $e');
    }
  }

  Future<void> unblockUser(int userIdToUnblock, String token) async {
    final url = Uri.parse('$baseUrl/users/me/unblock/$userIdToUnblock'); // ADJUST ENDPOINT AS NEEDED
    try {
      final response = await http.delete(url, headers: _getAuthHeaders(token)); // DELETE to unblock
      if (response.statusCode != 200 && response.statusCode != 204) { // Allow OK or No Content
        throw Exception('Failed to unblock user (${response.statusCode})');
      }
    } catch (e) {
      print("Unblock User Error: $e");
      throw Exception('Network error unblocking user: $e');
    }
  }


} // End of ApiService class