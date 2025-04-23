// frontend/lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Required for WebSocketException
import 'dart:math'; // Required for pow
import '../app_constants.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

// Use AppConstants only if wsBaseUrl isn't defined by environment
// import '../app_constants.dart';
import 'api_endpoints.dart'; // For WS path structure

// Define API Key and WS Base URL as constants (load from environment ideally)
// Compile using: flutter run --dart-define=API_KEY=YOUR_KEY --dart-define=WS_BASE_URL=ws://your-url
const String _apiKey = String.fromEnvironment('API_KEY');
const String _wsBaseUrlFromEnv = AppConstants.wsUrl;

/// Manages the WebSocket connection, message stream, and presence updates.
class WebSocketService {
  final String wsBaseUrl;
  final String apiKey = _apiKey;

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  // Controller for ALL raw incoming messages (parsed JSON maps)
  final StreamController<Map<String, dynamic>> _rawMessagesController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get rawMessages => _rawMessagesController.stream;

  // Controller specifically for online presence counts: Map<String roomKey, int onlineCount>
  final StreamController<Map<String, int>> _onlineCountController = StreamController.broadcast();
  Stream<Map<String, int>> get onlineCounts => _onlineCountController.stream;

  // Controller for connection state changes (e.g., 'connecting', 'connected', 'disconnected', 'error')
  final StreamController<String> _connectionStateController = StreamController.broadcast();
  Stream<String> get connectionState => _connectionStateController.stream;

  // Internal state
  String? _currentRoomKey; // Stores 'type_id' format, e.g., "community_1"
  String? _currentToken;   // Token used for the current connection
  bool _isConnected = false; // Reflects successful connection AND listener active
  bool _isConnecting = false; // Prevents multiple concurrent connection attempts
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5; // Limit reconnection attempts

  WebSocketService({String? wsUrl}) :
        wsBaseUrl = _wsBaseUrlFromEnv.isNotEmpty
            ? _wsBaseUrlFromEnv
            : throw Exception("WS_BASE_URL environment variable not set during build.") // Fail fast if not set
  {
    if (apiKey.isEmpty) {
      const errorMessage = "API_KEY environment variable not set. WebSocketService cannot function.";
      print("FATAL ERROR: $errorMessage");
      throw Exception(errorMessage);
    }
    _connectionStateController.add('disconnected'); // Initial state
    print("WebSocketService initialized. Base URL: $wsBaseUrl, API Key: ${apiKey.substring(0,5)}...");
  }

  // --- Public Getters ---
  bool get isConnected => _isConnected && _channel != null && _channel?.closeCode == null;
  String? get currentRoomKey => _currentRoomKey; // This now returns 'type_id'

  // --- Connection Management ---

  /// Connects to a specific WebSocket room (community or event).
  void connect(String roomType, int roomId, String token) {
    final targetRoomKey = getRoomKey(roomType, roomId); // Use helper for 'type_id' format
    if (targetRoomKey == null) {
      print("WebSocketService: Invalid roomType or roomId for connection.");
      _handleDisconnect("Invalid room details");
      return;
    }
    print("WebSocketService: Connect called for target room: $targetRoomKey");

    if (_isConnecting) { print("WebSocketService: Already attempting to connect."); return; }
    if (isConnected && _currentRoomKey == targetRoomKey && _currentToken == token) { print("WebSocketService: Already connected to $targetRoomKey."); return; }
    if (isConnected) { print("WebSocketService: Switching rooms. Disconnecting previous connection ($_currentRoomKey)..."); disconnect(ws_status.normalClosure, "Client switching room/token"); }

    _isConnecting = true;
    _currentRoomKey = targetRoomKey; // Store 'type_id' format
    _currentToken = token;
    _isConnected = false;
    if (!_connectionStateController.isClosed) _connectionStateController.add('connecting');
    print("WebSocketService: Set state to connecting for $_currentRoomKey...");

    // Construct URL with backend path format and query parameters
    final wsPath = ApiEndpoints.websocketRoomPath(roomType, roomId); // Gets '/ws/type/id'
    final url = Uri.parse('$wsBaseUrl$wsPath'
        '?token=${Uri.encodeComponent(token)}'
        '&api_key=${Uri.encodeComponent(apiKey)}');
    print("WebSocketService: Connecting WebSocket to actual URL: $url");

    try {
      // *** Initiate Connection ***
      _channel = WebSocketChannel.connect(url);
      print("WebSocketService: WebSocketChannel.connect called successfully for $url.");

      // *** Connection attempt initiated, listener setup next ***
      _isConnecting = false;

      _streamSubscription?.cancel(); // Cancel previous listener

      _streamSubscription = _channel!.stream.listen(
            (message) {
          // Set connected state on first message OR maybe immediately after listen attached?
          // Let's stick to setting it immediately after listen attached for responsiveness.
          _handleMessage(message);
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason ?? "No reason provided";
          print("WebSocketService: Disconnected (onDone). Room: $_currentRoomKey, Code: $closeCode, Reason: $closeReason");
          final disconnectedByKey = _currentRoomKey; // Capture key before clearing
          _handleDisconnect("WebSocket disconnected by server (onDone)");
          // Attempt to reconnect only if closure was unexpected
          if (closeCode != ws_status.normalClosure && closeCode != ws_status.goingAway) {
            // Pass the key it TRIED to connect to, even if _currentRoomKey is now null
            _scheduleReconnection(disconnectedByKey);
          }
        },
        onError: (error, stackTrace) {
          print("WebSocketService: Stream Error ($_currentRoomKey): $error");
          print(stackTrace);
          final errorRoomKey = _currentRoomKey; // Capture key
          _handleDisconnect("WebSocket stream error: $error");
          _scheduleReconnection(errorRoomKey); // Attempt to reconnect on stream errors
        },
        cancelOnError: true, // Stop listening after an error on the stream
      );
      print("WebSocketService: Listener attached for $_currentRoomKey.");

      // --- *** IMMEDIATE STATE UPDATE *** ---
      // If we reached here without an exception, assume connection is established
      // and listener is ready. Update state immediately.
      _isConnected = true;
      _reconnectAttempts = 0; // Reset attempts on new successful connection attempt
      _reconnectTimer?.cancel();
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add('connected');
        print("WebSocketService: Emitted 'connected' state for $_currentRoomKey.");
      } else {
        print("WebSocketService: Error - Connection state controller closed before emitting 'connected'.");
      }
      notifyListeners(); // If using ChangeNotifier
      // --- *** END IMMEDIATE STATE UPDATE *** ---

    } catch (e, stackTrace) {
      // Immediate error during WebSocketChannel.connect() or listener setup
      print("WebSocketService: Connection failed during initialization: $e");
      print(stackTrace);
      final failedRoomKey = _currentRoomKey; // Capture key before clearing
      // Ensure flags are reset even if connect object wasn't assigned
      _isConnecting = false;
      _isConnected = false;
      _handleDisconnect("Connection initialization failed: $e"); // Use handler for cleanup
      _scheduleReconnection(failedRoomKey); // Schedule retry after init failure
    }
  }

  /// Disconnects the current WebSocket connection.
  void disconnect([int? code, String? reason]) {
    if (_channel == null && !_isConnecting) {
      print("WebSocketService: Disconnect called but no active channel or connection attempt.");
      return;
    }
    print("WebSocketService: Closing connection for $_currentRoomKey... Code: ${code ?? 'Normal'}, Reason: ${reason ?? 'Client request'}");
    _reconnectTimer?.cancel(); // Prevent reconnection attempts if closing manually
    _isConnecting = false;
    _channel?.sink.close(code ?? ws_status.normalClosure, reason);
    // State cleanup will happen in onDone/onError via _handleDisconnect
    // Force state update if needed immediately (e.g., user clicks disconnect button)
    if (_isConnected || _isConnecting) {
      _handleDisconnect(reason ?? "Client initiated disconnect");
    }
  }


  /// Handles state cleanup and notification on disconnection or error.
  void _handleDisconnect(String reason) {
    // Check flags to prevent redundant calls if onDone/onError both trigger quickly
    if (!_isConnected && !_isConnecting) {
      print("WebSocketService: Redundant disconnect handling call ignored.");
      return;
    }

    print("WebSocketService: Handling disconnect for $_currentRoomKey. Reason: $reason");
    final disconnectedRoomKey = _currentRoomKey; // Store before clearing

    // Reset state immediately
    _isConnected = false;
    _isConnecting = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel = null; // Important to clear the channel reference
    _currentRoomKey = null;
    _currentToken = null; // Clear token associated with the closed connection

    // Notify UI about disconnection
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add('disconnected');
    }

    // Clear online count for the room that was disconnected
    if (disconnectedRoomKey != null && !_onlineCountController.isClosed) {
      _onlineCountController.add({disconnectedRoomKey: 0});
      print("WebSocketService: Cleared online count for $disconnectedRoomKey");
    }
    notifyListeners(); // If using ChangeNotifier
  }

  /// Schedules a reconnection attempt with exponential backoff.
  /// Needs the roomKey it should try to reconnect to.
  void _scheduleReconnection(String? roomKeyToReconnect) {
    if (_reconnectTimer?.isActive ?? false || _isConnecting || _isConnected) {
      print("WebSocketService: Skipping reconnection schedule (timer active, connecting, or connected).");
      return;
    }
    if (roomKeyToReconnect == null) {
      print("WebSocketService: Skipping reconnection schedule (no target room key provided).");
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WebSocketService: Max reconnection attempts reached for $roomKeyToReconnect. Stopping.");
      // Optionally emit a permanent failure state?
      _reconnectAttempts = 0; // Reset for future manual attempts
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = (pow(2, _reconnectAttempts) as num).clamp(2, 30).toInt();

    print("WebSocketService: Scheduling reconnection attempt #$_reconnectAttempts for $roomKeyToReconnect in $delaySeconds seconds...");
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      print("WebSocketService: Attempting reconnection (Attempt #$_reconnectAttempts) for $roomKeyToReconnect...");
      // Need the token associated with the FAILED connection attempt.
      // _currentToken might have been cleared or changed if user logged out/switched rooms.
      // Robust reconnection requires preserving the token/room details of the failed attempt.
      // For now, we'll assume _currentToken might still be valid if user hasn't logged out.
      if (_currentToken != null) {
        final parts = roomKeyToReconnect.split('_');
        if (parts.length == 2) {
          final roomType = parts[0]; final roomId = int.tryParse(parts[1]);
          if (roomId != null) {
            // Re-trigger connection ONLY if no other connection is active/connecting
            if (!isConnected && !_isConnecting) {
              print("WebSocketService: Retrying connection via schedule...");
              connect(roomType, roomId, _currentToken!);
            } else {
              print("WebSocketService: Reconnection cancelled, already connected/connecting to another room.");
              _reconnectAttempts = 0; // Reset attempts as state changed
            }
          } else { print("WebSocketService: Reconnect parse failed: Invalid room ID in key '$roomKeyToReconnect'"); _reconnectAttempts=0; }
        } else { print("WebSocketService: Reconnect parse failed: Invalid room key format '$roomKeyToReconnect'"); _reconnectAttempts=0;}
      } else {
        print("WebSocketService: Cannot reconnect - token missing.");
        _reconnectAttempts = 0; // Reset
      }
    });
  }

  /// Handles incoming WebSocket messages.
  void _handleMessage(dynamic message) {
    if (message is! String) { print("WS Service: Received non-string message: ${message.runtimeType}"); return; }
    print("WebSocketService: Received raw: $message");
    try {
      final data = json.decode(message) as Map<String, dynamic>;

      if (!_rawMessagesController.isClosed) { _rawMessagesController.add(data); }
      else { print("WS Service: Warning - Raw message controller closed."); return; } // Stop if closed

      // Handle Presence Updates
      if (data['type'] == 'presence_update' && data['room_key'] != null && data['online_count'] != null) {
        final String roomKey = data['room_key']; final int onlineCount = data['online_count'];
        print("WS Service: Parsed presence update for $roomKey: $onlineCount online.");
        if (!_onlineCountController.isClosed) { _onlineCountController.add({roomKey: onlineCount}); }
        else { print("WS Service: Warning - Online count controller closed."); }
      }
      // Handle Chat Messages (assuming they have message_id)
      else if (data.containsKey('message_id')) {
        print("WS Service: Identified chat message (ID: ${data['message_id']}).");
        // UI listener on rawMessages stream handles parsing & display
      }
      // Handle explicit Errors from backend
      else if (data['type'] == 'error' && data['error'] != null) {
        print("WS Service: Received error from backend WS: ${data['error']}");
        if (!_rawMessagesController.isClosed) { _rawMessagesController.addError(Exception("Backend WS Error: ${data['error']}")); }
      }
      // Handle other potential message types from backend
      else {
        print("WS Service: Received unknown message structure: $data");
      }
    } catch (e, stackTrace) {
      print("WS Service: Error parsing message '$message': $e"); print(stackTrace);
      if (!_rawMessagesController.isClosed) { _rawMessagesController.addError(FormatException("Invalid WS message format: $e")); }
    }
  }

  /// Sends a JSON encoded message over the WebSocket.
  void sendMessage(Map<String, dynamic> messageData) {
    if (!isConnected) { // Use the getter here
      final errorMsg = "Cannot send message: WebSocket not connected to $_currentRoomKey.";
      print("WebSocketService: $errorMsg");
      throw Exception(errorMsg);
    }
    try {
      final messageJson = json.encode(messageData);
      print("WebSocketService: Sending to $_currentRoomKey: $messageJson");
      _channel!.sink.add(messageJson); // Use null assertion as _isConnected check implies _channel != null
    } catch (e, stackTrace) {
      print("WebSocketService: Error encoding or sending message: $e"); print(stackTrace);
      _handleDisconnect("Error during send: $e");
      throw Exception("Failed to send message: $e");
    }
  }

  /// Closes resources when the service is permanently disposed.
  void dispose() {
    print("WebSocketService: Disposing...");
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    // Close sink gently first, then close controllers
    _channel?.sink.close(ws_status.goingAway).catchError((e) {
      print("WebSocketService: Error closing sink during dispose: $e");
    });
    _channel = null; // Ensure channel is cleared

    // Add checks before closing controllers
    if (!_rawMessagesController.isClosed) _rawMessagesController.close();
    if (!_onlineCountController.isClosed) _onlineCountController.close();
    if (!_connectionStateController.isClosed) _connectionStateController.close();

    print("WebSocketService: Resources disposed.");
  }

  // Helper to generate room key string (type_id format)
  String? getRoomKey(String? type, int? id) {
    if (type == null || id == null || id <= 0) return null;
    return "${type}_${id}";
  }

  // Helper for potential ChangeNotifier implementation
  void notifyListeners() {
    // If WebSocketService were a ChangeNotifier, call notifyListeners() here
    // Currently it uses Streams for state changes.
  }

} // End of WebSocketService