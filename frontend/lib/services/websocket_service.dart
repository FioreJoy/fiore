// frontend/lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
// Required for WebSocketException
import 'dart:math'; // Required for pow
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../app_constants.dart';
import 'api_endpoints.dart'; // For WS path structure

const String _apiKey = String.fromEnvironment('API_KEY');
const String _wsBaseUrlFromEnv = AppConstants.wsUrl;

/// Manages the WebSocket connection, message stream, and presence updates.
class WebSocketService {
  final String wsBaseUrl;
  final String apiKey = _apiKey;

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  final StreamController<Map<String, dynamic>> _rawMessagesController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get rawMessages => _rawMessagesController.stream;

  final StreamController<Map<String, int>> _onlineCountController = StreamController.broadcast();
  Stream<Map<String, int>> get onlineCounts => _onlineCountController.stream;

  final StreamController<String> _connectionStateController = StreamController.broadcast();
  Stream<String> get connectionState => _connectionStateController.stream;

  String? _currentRoomType;
  int? _currentRoomId;
  String? _currentToken;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WebSocketService({String? wsUrl})
      : wsBaseUrl = _wsBaseUrlFromEnv.isNotEmpty
      ? _wsBaseUrlFromEnv
      : throw Exception("WS_BASE_URL environment variable not set during build.") {
    if (apiKey.isEmpty) {
      const errorMessage = "API_KEY environment variable not set. WebSocketService cannot function.";
      print("FATAL ERROR: $errorMessage");
      throw Exception(errorMessage);
    }
    _connectionStateController.add('disconnected');
    print("WebSocketService initialized. Base URL: $wsBaseUrl, API Key: ${apiKey.substring(0, 5)}...");
  }

  bool get isConnected => _isConnected && _channel != null && _channel?.closeCode == null;

  void connect(String roomType, int roomId, String token) {
    final roomKey = _getRoomKey(roomType, roomId);
    if (roomKey == null) {
      print("WebSocketService: Invalid roomType or roomId for connection.");
      _handleDisconnect("Invalid room details");
      return;
    }

    if (_isConnecting) {
      print("WebSocketService: Already attempting to connect.");
      return;
    }

    if (isConnected && _currentRoomType == roomType && _currentRoomId == roomId && _currentToken == token) {
      print("WebSocketService: Already connected to $roomKey.");
      return;
    }

    if (isConnected) {
      disconnect(ws_status.normalClosure, "Client switching room/token");
    }

    _isConnecting = true;
    _currentRoomType = roomType;
    _currentRoomId = roomId;
    _currentToken = token;
    _isConnected = false;
    if (!_connectionStateController.isClosed) _connectionStateController.add('connecting');

    final wsPath = ApiEndpoints.websocketRoomPath(roomType, roomId);
    final url = Uri.parse('$wsBaseUrl$wsPath?token=${Uri.encodeComponent(token)}&api_key=${Uri.encodeComponent(apiKey)}');

    try {
      _channel = WebSocketChannel.connect(url);
      _isConnecting = false;

      _streamSubscription?.cancel();
      _streamSubscription = _channel!.stream.listen(
            (message) => _handleMessage(message),
        onDone: () {
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason ?? "No reason provided";
          print("WebSocketService: Disconnected (onDone). Code: $closeCode, Reason: $closeReason");
          _handleDisconnect("WebSocket disconnected by server");
          if (closeCode != ws_status.normalClosure && closeCode != ws_status.goingAway) {
            _scheduleReconnection();
          }
        },
        onError: (error, stackTrace) {
          print("WebSocketService: Stream Error: $error");
          if (kDebugMode) print(stackTrace);
          _handleDisconnect("WebSocket stream error: $error");
          _scheduleReconnection();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      if (!_connectionStateController.isClosed) _connectionStateController.add('connected');
    } catch (e, stackTrace) {
      print("WebSocketService: Connection failed: $e");
      if (kDebugMode) print(stackTrace);
      _isConnecting = false;
      _isConnected = false;
      _handleDisconnect("Connection initialization failed: $e");
      _scheduleReconnection();
    }
  }

  void disconnect([int? code, String? reason]) {
    if (_channel == null && !_isConnecting) {
      print("WebSocketService: Disconnect called but no active connection.");
      return;
    }
    _reconnectTimer?.cancel();
    _isConnecting = false;
    _channel?.sink.close(code ?? ws_status.normalClosure, reason);
    if (_isConnected || _isConnecting) {
      _handleDisconnect(reason ?? "Client initiated disconnect");
    }
  }

  void _handleDisconnect(String reason) {
    if (!_isConnected && !_isConnecting) {
      return;
    }

    print("WebSocketService: Handling disconnect. Reason: $reason");
    _isConnected = false;
    _currentRoomType = null;
    _currentRoomId = null;
    _currentToken = null;

    _streamSubscription?.cancel();
    try {
      _channel?.sink.close(ws_status.normalClosure, reason);
    } catch (e) {
      print("WebSocketService: Error closing channel: $e");
    }
    _channel = null;

    if (!_rawMessagesController.isClosed) _rawMessagesController.addError(Exception(reason));
    if (!_connectionStateController.isClosed) _connectionStateController.add('disconnected');
  }

  void _scheduleReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WebSocketService: Max reconnection attempts reached.");
      return;
    }

    _reconnectAttempts++;
    final delay = min(30, pow(2, _reconnectAttempts));
    print("WebSocketService: Attempting reconnection in ${delay.toStringAsFixed(0)} seconds...");

    _reconnectTimer = Timer(Duration(seconds: delay.toInt()), () {
      if (_currentRoomType != null && _currentRoomId != null && _currentToken != null) {
        connect(_currentRoomType!, _currentRoomId!, _currentToken!);
      }
    });
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      try {
        final decodedMessage = jsonDecode(message);
        _rawMessagesController.add(decodedMessage);
      } catch (e) {
        print("WebSocketService: Error decoding message: $e");
        if (!_rawMessagesController.isClosed) {
          _rawMessagesController.addError(Exception("Error decoding message: $e"));
        }
      }
    }
  }

  String? _getRoomKey(String roomType, int roomId) {
    return roomId != 0 ? '${roomType}_$roomId' : null;
  }

  void sendMessage(String message) {
    if (isConnected) {
      try {
        _channel?.sink.add(message);
      } catch (e) {
        print("WebSocketService: Error during send: $e");
        if (!_rawMessagesController.isClosed) {
          _rawMessagesController.addError(Exception("Error sending message: $e"));
        }
        _scheduleReconnection();
      }
    } else {
      print("WebSocketService: Cannot send message, not connected.");
      if (!_rawMessagesController.isClosed) {
        _rawMessagesController.addError(Exception("Cannot send message: Not connected."));
      }
    }
  }

  void dispose() {
    print("WebSocketService: Disposing service...");
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    try {
      _channel?.sink.close(1000, 'Client disconnecting');
    } catch (e) {
      print("WebSocketService: Dispose error: $e");
    }
    _rawMessagesController.close();
    _onlineCountController.close();
    _connectionStateController.close();
  }
}
