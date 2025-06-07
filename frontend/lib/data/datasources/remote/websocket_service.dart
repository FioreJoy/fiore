// frontend/lib/data/datasources/remote/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../app_constants.dart';

const String _apiKeyFromEnv = String.fromEnvironment('API_KEY', defaultValue: '');
const String _wsBaseUrl = AppConstants.wsUrl;

class WebSocketService with ChangeNotifier {
  final String wsUrl = _wsBaseUrl;
  final String apiKey = _apiKeyFromEnv;

  IO.Socket? _socket;

  final StreamController<Map<String, dynamic>> _rawMessagesController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get rawMessages => _rawMessagesController.stream;

  final StreamController<String> _connectionStateController = StreamController.broadcast();
  Stream<String> get connectionState => _connectionStateController.stream;

  String? _currentRoomKey;
  String? _currentTokenForConnection;
  String? _myUserIdForConnection;

  bool _isConnectedAndAuthenticated = false;
  bool _isAttemptingConnection = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 7;

  WebSocketService() {
    if (apiKey.isEmpty && kDebugMode) {
      print("WebSocketService WARN: API_KEY is empty. This might be required for WebSocket authentication on server.");
    }
    if (wsUrl.isEmpty) {
      final String errorMessage = "WS_BASE_URL (via AppConstants.wsUrl) is not set. WebSocketService cannot function.";
      print("FATAL ERROR: $errorMessage");
      if (!_connectionStateController.isClosed) _connectionStateController.add('error_configuration');
    } else {
      if (!_connectionStateController.isClosed) _connectionStateController.add('disconnected');
    }
    print("WebSocketService (Socket.IO Client): Initialized. Base URL: $wsUrl");
  }

  bool get isConnected => _isConnectedAndAuthenticated && _socket?.connected == true;
  String? get currentRoomKeyAttemptingOrConnected => _currentRoomKey;

  void connect(String roomType, int roomIdOrRecipientId, String token, String myUserId) {
    if (wsUrl.isEmpty) {
      print("WebSocketService Error: WS Base URL is not configured. Cannot connect.");
      if (!_connectionStateController.isClosed) _connectionStateController.add('error_configuration');
      return;
    }

    final targetRoomKey = _generateWsRoomKey(roomType, roomIdOrRecipientId, myUserId);

    if (targetRoomKey == null) {
      print("WebSocketService: Invalid roomType ('$roomType'), roomId/recipientId ('$roomIdOrRecipientId'), or myUserId ('$myUserId') for connection.");
      _handleSocketDisconnect("Invalid room parameters for connect call");
      return;
    }

    print("WebSocketService: connect() called. MyUID: $myUserId, TargetRoom: $targetRoomKey, Token: ${token.isNotEmpty ? "Present" : "MISSING!"}");

    if (_isAttemptingConnection && _currentRoomKey == targetRoomKey && _currentTokenForConnection == token && _myUserIdForConnection == myUserId) {
      print("WebSocketService: Already attempting to connect to $targetRoomKey with same params.");
      return;
    }

    if (isConnected && _currentRoomKey == targetRoomKey && _currentTokenForConnection == token && _myUserIdForConnection == myUserId) {
      print("WebSocketService: Already connected to $targetRoomKey with the same token. Ensuring room join.");
      _ensureJoinedToRoom(targetRoomKey);
      return;
    }

    if (_socket != null && (_socket!.connected || _isAttemptingConnection)) {
      print("WebSocketService: New connection request or param change. Disconnecting existing socket (if any) for $_currentRoomKey...");
      disconnect();
    }

    _isAttemptingConnection = true;
    _currentRoomKey = targetRoomKey;
    _currentTokenForConnection = token;
    _myUserIdForConnection = myUserId;
    _isConnectedAndAuthenticated = false;
    if (!_connectionStateController.isClosed) _connectionStateController.add('connecting');
    notifyListeners();

    final Map<String, dynamic> authPayload = {'token': token};
    if (apiKey.isNotEmpty) authPayload['api_key'] = apiKey;

    try {
      final String connectionUrl = '$wsUrl/sio';
      print("WebSocketService: Attempting IO.io connection to: $connectionUrl");

      _socket = IO.io(
          connectionUrl,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setAuth(authPayload)
              .build());

      _setupSocketEventListeners(myUserId);
      _socket!.connect();
      print("WebSocketService: IO.Socket.connect() called for target room $_currentRoomKey at $connectionUrl");

    } catch (e, s) {
      print("WebSocketService: CRITICAL Error initiating Socket.IO connection object: $e\n$s");
      _isAttemptingConnection = false;
      _handleSocketError("Connection initiation failed: $e");
    }
  }

  void _setupSocketEventListeners(String myUserIdForReconnectContext) {
    if (_socket == null) {
      print("WebSocketService Error: _setupSocketEventListeners called with null socket.");
      return;
    }
    _socket!.clearListeners();

    _socket!.onConnect((_) {
      print("WebSocketService: Socket.IO Connected! SID: ${_socket?.id}, Target Room: $_currentRoomKey");
      _isAttemptingConnection = false; _isConnectedAndAuthenticated = true;
      _reconnectAttempts = 0; _reconnectTimer?.cancel();
      if (!_connectionStateController.isClosed) _connectionStateController.add('connected');
      if (_currentRoomKey != null) {
        _ensureJoinedToRoom(_currentRoomKey!);
      }
      notifyListeners();
    });

    _socket!.on('connect_error', (data) {
      print("WebSocketService: Socket.IO Connection Error for $_currentRoomKey: $data");
      _isAttemptingConnection = false;
      _handleSocketError("Connection error: $data");
      _scheduleReconnection(_currentRoomKey, _currentTokenForConnection, myUserIdForReconnectContext);
    });

    _socket!.on('error', (data) {
      print("WebSocketService: Socket.IO Generic Error Event for $_currentRoomKey: $data");
      if (!_connectionStateController.isClosed) _connectionStateController.add('error_server: $data');
    });

    _socket!.onDisconnect((reason) {
      print("WebSocketService: Socket.IO Disconnected. Room: $_currentRoomKey, Reason: $reason");
      final String? roomKeyBeforeDisconnect = _currentRoomKey;
      final String? tokenBeforeDisconnect = _currentTokenForConnection;
      final String? myUserIdBeforeDisconnect = myUserIdForReconnectContext;

      _handleSocketDisconnect("Disconnected: $reason ($roomKeyBeforeDisconnect)");

      bool shouldReconnect = (reason != 'io client disconnect' && reason != 'io server disconnect');
      if (shouldReconnect) {
        _scheduleReconnection(roomKeyBeforeDisconnect, tokenBeforeDisconnect, myUserIdBeforeDisconnect);
      }
    });

    _socket!.on('new_message', (data) {
      if (data is Map<String, dynamic> && !_rawMessagesController.isClosed) {
        _rawMessagesController.add(data);
      } else if (data is String) {
        try {
          final Map<String,dynamic> parsedData = json.decode(data);
          if (!_rawMessagesController.isClosed) _rawMessagesController.add(parsedData);
        } catch (e) {print("WS: Error decoding string message $e for 'new_message'");}
      }
    });
    _socket!.on('room_joined', (data) => print("WS: Server confirmed room joined: $data"));
    _socket!.on('room_left', (data) => print("WS: Server confirmed room left: $data"));
    _socket!.on('room_join_error', (data) => print("WS ERROR joining room: $data"));
    _socket!.on('message_error', (data) => print("WS ERROR with message: $data"));
  }

  void _ensureJoinedToRoom(String roomKey) {
    if (_socket != null && _socket!.connected) {
      print("WebSocketService: Client emitting 'join_room' for $roomKey");
      _socket!.emit('join_room', {'room_key': roomKey});
    } else { print("WebSocketService: Cannot join room $roomKey, socket not connected.");}
  }

  void leaveCurrentRoomAndDisconnect() {
    if (_socket != null && _socket!.connected && _currentRoomKey != null) {
      print("WebSocketService: Emitting 'leave_room' for $_currentRoomKey and preparing to disconnect fully.");
      _socket!.emit('leave_room', {'room_key': _currentRoomKey});
    }
    disconnect();
  }

  void _handleSocketDisconnect(String reason) {
    print("WebSocketService: Handling full socket disconnect/cleanup. Reason: $reason");
    bool wasConnectedOrAttempting = _isConnectedAndAuthenticated || _isAttemptingConnection;

    _isConnectedAndAuthenticated = false; _isAttemptingConnection = false;
    _currentRoomKey = null; _currentTokenForConnection = null; _myUserIdForConnection = null;

    _socket?.dispose(); _socket = null;

    if (wasConnectedOrAttempting && !_connectionStateController.isClosed) {
      _connectionStateController.add('disconnected');
    }
    notifyListeners();
  }

  void _handleSocketError(String errorReason){
    print("WebSocketService: Handling socket error. Reason: $errorReason");
    _isConnectedAndAuthenticated = false; _isAttemptingConnection = false;
    _socket?.dispose(); _socket = null;
    if(!_connectionStateController.isClosed) _connectionStateController.add('error: $errorReason');
    notifyListeners();
  }

  void _scheduleReconnection(String? roomKeyToReconnect, String? tokenToUse, String? myUserIdForReconnect) {
    if (_reconnectTimer?.isActive ?? false || _isAttemptingConnection || isConnected) {
      print("WS Reconnect: Skipping, already active/connecting/connected or no user ID.");
      return;
    }
    if (roomKeyToReconnect == null || tokenToUse == null || myUserIdForReconnect == null || myUserIdForReconnect.isEmpty) {
      print("WS Reconnect: Skipping, crucial data missing (room: $roomKeyToReconnect, token: ${tokenToUse!=null}, myUID: $myUserIdForReconnect).");
      _reconnectAttempts = 0; return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WS Reconnect: Max attempts for $roomKeyToReconnect. Stopping.");
      _reconnectAttempts = 0;
      if(!_connectionStateController.isClosed) _connectionStateController.add('error_max_retries'); return;
    }

    _reconnectAttempts++;
    final delaySeconds = (pow(2, _reconnectAttempts-1) as num).clamp(2, 60).toInt();
    print("WS Reconnect: Attempt #${_reconnectAttempts} for $roomKeyToReconnect in $delaySeconds s (myUID: $myUserIdForReconnect)...");

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      print("WS Reconnect: Firing scheduled reconnection for $roomKeyToReconnect (myUID: $myUserIdForReconnect)...");
      final parts = roomKeyToReconnect.split('_');
      String type; int id;
      if (parts.length >= 2 && (parts[0] == 'community' || parts[0] == 'event')) {
        type = parts[0];
        id = int.tryParse(parts.last) ?? 0;
      } else if (parts.length == 3 && parts[0] == 'dm') {
        type = 'dm';
        final myIdParsed = int.tryParse(myUserIdForReconnect) ?? 0;
        final id1 = int.tryParse(parts[1]) ?? 0; final id2 = int.tryParse(parts[2]) ?? 0;
        id = (myIdParsed == id1) ? id2 : id1;
        if(id == 0 || myIdParsed == 0) { print("WS Reconnect ERROR: Could not determine recipient ID from $roomKeyToReconnect with myID $myUserIdForReconnect"); _reconnectAttempts = 0; return; }
      } else { print("WS Reconnect ERROR: Invalid roomKey '$roomKeyToReconnect'"); _reconnectAttempts = 0; return; }

      if (id > 0) {
        if (!isConnected && !_isAttemptingConnection) {
          print("WS Reconnect: Calling connect($type, $id, token, $myUserIdForReconnect)...");
          connect(type, id, tokenToUse, myUserIdForReconnect);
        } else { print("WS Reconnect: Cancelled, state changed (connected/connecting)."); _reconnectAttempts = 0;}
      } else { print("WS Reconnect ERROR: Could not parse valid ID for reconnection to $roomKeyToReconnect"); _reconnectAttempts = 0; }
    });
  }

  void disconnect() {
    print("WebSocketService: Manual disconnect called for current socket: ${_socket?.id}, room: $_currentRoomKey.");
    _reconnectTimer?.cancel(); _reconnectAttempts = 0;
    _isAttemptingConnection = false;
    if (_socket != null) {
      _socket!.disconnect();
    } else {
      _handleSocketDisconnect("Manual disconnect called on null socket.");
    }
  }

  void sendMessage(String eventName, Map<String, dynamic> messageData) {
    if (!isConnected) {
      final errorMsg = "Cannot send message: WebSocket not connected/authenticated to room $_currentRoomKey.";
      print("WebSocketService: $errorMsg");
      throw Exception(errorMsg);
    }
    try {
      _socket!.emit(eventName, messageData);
    } catch (e) {
      print("WebSocketService: Error emitting message event '$eventName': $e");
      throw Exception("Failed to send message: $e");
    }
  }

  String? _generateWsRoomKey(String type, int id, String myCurrentUserId) {
    if (myCurrentUserId.isEmpty) { print("WS_Service ERROR: myCurrentUserId is empty, cannot make DM room key."); return null; }
    final int? u1 = int.tryParse(myCurrentUserId);
    if (u1 == null) { print("WS_Service ERROR: myCurrentUserId '$myCurrentUserId' is not a valid int."); return null;}

    if (type == 'dm') {
      final int u2 = id;
      if (u1 == 0 || u2 == 0) {print("WS_Service ERROR: Zero user ID for DM room key ($u1, $u2)"); return null;}
      if (u1 == u2) {print("WS_Service ERROR: Cannot create DM room key with self ($u1, $u2)"); return null;}
      return (u1 < u2) ? "dm_${u1}_${u2}" : "dm_${u2}_${u1}";
    }
    return "${type}_$id";
  }

  @override
  void dispose() {
    print("WebSocketService: Disposing (Socket.IO client version)...");
    _reconnectTimer?.cancel();
    _socket?.dispose();
    if (!_rawMessagesController.isClosed) _rawMessagesController.close();
    if (!_connectionStateController.isClosed) _connectionStateController.close();
    super.dispose();
  }
}