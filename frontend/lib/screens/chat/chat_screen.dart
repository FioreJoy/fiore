// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'dart:io'; // For File type
import 'dart:convert'; // For jsonEncode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// --- Service Imports (Using Relative Paths) ---
import '../../services/websocket_service.dart';
import '../../services/auth_provider.dart';
import '../../services/api/user_service.dart';
import '../../services/api/chat_service.dart';
import '../../services/api/event_service.dart';

// --- Model Imports (Using Relative Paths) ---
import '../../models/chat_message_data.dart';
import '../../models/event_model.dart'; // Assuming this exists and is correct

// --- Widget Imports (Using Relative Paths) ---
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/chat_event_card.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart'; // Assuming this exists

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching main tabs

  // --- State Variables ---
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Current chat context
  int? _selectedCommunityId;
  int? _selectedEventId;

  // Data & Loading States
  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = []; // Stores {'id': int, 'name': String, 'logo_url': String?}
  EventModel? _selectedEventDetails;
  bool _isLoadingMessages = false;
  bool _isLoadingCommunities = true;
  bool _isLoadingEventDetails = false;
  bool _canLoadMoreMessages = true;

  // Listeners for global WebSocketService streams
  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;

  // Feature States
  bool _showEmojiPicker = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  File? _pickedFile;
  String? _uploadingFileName;


  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeChat(); // Loads communities, then connects WS if possible
        _initSpeech();
      }
    });
    _scrollController.addListener(_scrollListener);
    _focusNode.addListener(() {
      // Hide emoji picker when text field gains focus
      if (_focusNode.hasFocus && _showEmojiPicker && mounted) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  @override
  void dispose() {
    print("ChatScreen disposing...");
    _textController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _focusNode.dispose();
    _cancelWebSocketListeners(); // Cancel listeners
    // Don't dispose the global WS service here, Provider handles it
    _speechToText.cancel();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initializeChat() async {
    await _loadUserCommunities();
    if (_selectedCommunityId != null && mounted) {
      // A community was selected (or defaulted after load)
      _updateChatRoomLabel();
      await _loadChatHistory(isInitialLoad: true);
      _connectAndListenWebSocket(); // Attempt connection
    } else if (mounted) {
      // No communities or none selected initially
      setState(() {
        _isLoadingMessages = false; // Ensure loading stops
        _messages = []; // Clear any potential stale messages
      });
    }
    // Setup listeners regardless of initial connection success
    _setupWebSocketListeners();
  }

  // --- WebSocket Connection and Listening ---
  void _connectAndListenWebSocket() {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? token = authProvider.token;
    final String roomType = _selectedEventId != null ? 'event' : 'community';
    final int? roomId = _selectedEventId ?? _selectedCommunityId;

    if (roomId == null || token == null) {
      print("ChatScreen: Cannot connect WebSocket - missing roomId or token.");
      if (mounted) setState((){}); // Update UI to show disconnected state
      return;
    }

    // Get the global WebSocketService instance provided in main.dart
    final wsService = Provider.of<WebSocketService>(context, listen: false);

    print("ChatScreen: Calling wsService.connect for $roomType $roomId");
    // Call the connect method on the global instance
    wsService.connect(roomType, roomId, token);

    // Listeners are set up in _setupWebSocketListeners
    // Trigger a rebuild to update UI elements based on connection attempt/state
    if (mounted) setState(() {});
  }

  void _setupWebSocketListeners() {
    if (!mounted) return;
    _cancelWebSocketListeners(); // Cancel existing before creating new ones

    final wsService = Provider.of<WebSocketService>(context, listen: false);

    // Listen to the rawMessages stream from the global service
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) {
      if (!mounted) return;
      // Ensure it's a map before processing
      final currentScreenKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
      final messageRoomKey = getRoomKey(messageMap['event_id'] != null ? 'event' : 'community', messageMap['event_id'] ?? messageMap['community_id']);

      // Process only if the message is for the currently displayed room
      if (messageRoomKey == currentScreenKey && messageMap.containsKey('message_id')) {
        try {
          final newMessage = ChatMessageData.fromJson(messageMap);
          // Avoid duplicates if server echoes back (check messageId)
          bool alreadyExists = _messages.any((m) => m.messageId == newMessage.messageId);
          if (!alreadyExists) {
            setState(() => _messages.add(newMessage)); // Add to the end
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        } catch (e) { print("ChatScreen: Error parsing WS message JSON: $e"); }
      } else if (messageMap.containsKey('error')) {
        print("ChatScreen: WS Server Error: ${messageMap['error']}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat Error: ${messageMap['error']}')));
      } else if (messageRoomKey != currentScreenKey) {
        // Silently ignore messages for other rooms in this screen instance
        // print("ChatScreen: Ignored message for different room ($messageRoomKey vs $currentScreenKey)");
      }
        }, onError: (error) {
      print("ChatScreen: Error on WS messages stream: $error");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat connection error: $error')));
      if (mounted) setState((){}); // Update UI state
    });

    // Listen to connection state changes
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) {
      if (!mounted) return;
      print("ChatScreen: WS Connection State changed: $state");
      setState(() {}); // Rebuild to update based on connection state
    });
  }


  void _disconnectWebSocket() {
    if(mounted){
      final wsService = Provider.of<WebSocketService>(context, listen: false);
      wsService.disconnect(); // Call disconnect on the global service
    }
  }

  void _cancelWebSocketListeners() {
    print("ChatScreen: Cancelling WS listeners.");
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    _wsMessagesSubscription = null;
    _wsConnectionStateSubscription = null;
  }

  // --- Speech Recognition Logic ---
  void _initSpeech() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _speechEnabled = await _speechToText.initialize(
            onError: (errorNotification) => print('Speech recognition error: ${errorNotification.errorMsg}'),
            onStatus: (status) {
              print('Speech recognition status: $status');
              if (status == 'notListening' || status == 'done') {
                if (mounted) setState(() => _isListening = false);
              }
            }
        );
        if (mounted) setState(() {});
        print("Speech recognition initialized: $_speechEnabled");
      } else {
        print("Microphone permission denied");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied.')));
      }
    } catch (e) {
      print("Error initializing speech: $e");
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  void _startListening() async {
    if (!_speechEnabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech recognition not available.'))); return; }
    if (_isListening) return;
    if (mounted) setState(() => _isListening = true);
    // Ensure mic is stopped before starting new listen session
    await _speechToText.stop();
    await _speechToText.listen( onResult: _onSpeechResult, listenFor: const Duration(seconds: 30), pauseFor: const Duration(seconds: 3), partialResults: true, localeId: 'en_US');
  }

  void _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    // State update handled by onStatus callback
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _textController.text = result.recognizedWords;
        _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
        // Don't set _isListening = false here, wait for onStatus 'notListening' or 'done'
      });
    }
  }


  // --- Data Fetching ---
  Future<void> _loadUserCommunities() async {
    if (!mounted) return;
    setState(() => _isLoadingCommunities = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Create service instance with the ApiClient from AuthProvider
    final userService = UserService(authProvider.apiClient);

    if (!authProvider.isAuthenticated) {
      if (mounted) setState(() { _isLoadingCommunities = false; _userCommunities = []; _selectedCommunityId = null; _selectedEventId = null; });
      return;
    }

    try {
      // Get communities - expect List<dynamic> which should contain maps
      final List<dynamic> communitiesData = await userService.getMyJoinedCommunities(); // No token needed
      if (!mounted) return;

      // Process into the expected format, ensuring correct types
      _userCommunities = communitiesData.map((item) {
        if (item is Map<String, dynamic>) {
          // Attempt to get logo_url which should be pre-generated by the service/backend if possible
          return {
            'id': item['id'] as int? ?? 0,
            'name': item['name'] as String? ?? 'Unknown',
            'logo_url': item['logo_url'] as String?, // Use the provided URL
          };
        }
        return <String, dynamic>{}; // Return empty map if item is not a map
      }).where((item) => item.isNotEmpty && item['id'] != 0).toList(); // Filter out invalid items

      int? initialCommunityId = _selectedCommunityId;

      // Default to first community if none selected or previous selection is gone
      if (_userCommunities.isNotEmpty && (initialCommunityId == null || !_userCommunities.any((c) => c['id'] == initialCommunityId))) {
        initialCommunityId = _userCommunities.first['id'] as int?;
      } else if (_userCommunities.isEmpty) {
        initialCommunityId = null; // No communities, select nothing
      }

      // Update state only if selection changed or still loading
      if (mounted && (_selectedCommunityId != initialCommunityId || _isLoadingCommunities)) {
        setState(() {
          _selectedCommunityId = initialCommunityId;
          _isLoadingCommunities = false; // Set loading false here
          if (_selectedCommunityId != null) {
            // Reset event selection when community changes
            _selectedEventId = null;
            _selectedEventDetails = null;
          }
        });
      } else if (mounted) {
        // Ensure loading is false even if selection didn't change
        setState(() { _isLoadingCommunities = false; });
      }

    } catch (e) {
      if (!mounted) return;
      print('ChatScreen: Error loading communities: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading communities: $e')));
      if (mounted) setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async {
    final String roomType = _selectedEventId != null ? 'event' : 'community';
    final int? roomId = _selectedEventId ?? _selectedCommunityId;

    if (!mounted || roomId == null) {
      if (mounted) setState(() { _messages = []; _isLoadingMessages = false; _canLoadMoreMessages = true; });
      return;
    }

    if (isInitialLoad) {
      if (mounted) setState(() { _isLoadingMessages = true; _messages.clear(); _canLoadMoreMessages = true; });
    } else if (_isLoadingMessages || !_canLoadMoreMessages) {
      return; // Prevent multiple loads or loading when no more messages
    } else {
      if (mounted) setState(() => _isLoadingMessages = true);
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (mounted) setState(() { _isLoadingMessages = false; _messages = []; });
      return;
    }
    final chatService = ChatService(authProvider.apiClient); // Use correct ApiClient

    try {
      // Expect List<ChatMessageData> from service
      final List<ChatMessageData> newMessages = await chatService.getMessages(
        communityId: roomType == 'community' ? roomId : null,
        eventId: roomType == 'event' ? roomId : null,
        limit: 50, beforeId: beforeMessageId, // No token needed
      );
      if (!mounted) return;

      setState(() {
        if (isInitialLoad) {
          _messages = newMessages.reversed.toList(); // Replace existing messages
        } else {
          _messages.insertAll(0, newMessages.reversed); // Prepend older messages
        }
        _isLoadingMessages = false;
        _canLoadMoreMessages = newMessages.length >= 50; // Check if more might exist
      });

      if (isInitialLoad) {
        // Scroll after the frame builds
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
      }
    } catch (e) {
      if (!mounted) return;
      print("ChatScreen: Error loading chat history: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadSelectedEventDetails() async {
    if (!mounted || _selectedEventId == null) return;
    setState(() => _isLoadingEventDetails = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eventService = EventService(authProvider.apiClient); // Use correct ApiClient
    if (!authProvider.isAuthenticated) {
      if (mounted) setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; });
      return;
    }
    try {
      // Expect Map<String, dynamic> from service
      final eventData = await eventService.getEventDetails(_selectedEventId!); // No token needed
      if (mounted) {
        setState(() {
          // Parse into EventModel
          _selectedEventDetails = EventModel.fromJson(eventData);
          _isLoadingEventDetails = false;
        });
      }
    } catch (e) {
      print("ChatScreen: Error loading selected event details: $e");
      if (mounted) {
        setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load event details.')));
      }
    }
  }

  // --- Scroll Listener ---
  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    // Load more when near the top (e.g., within 100 pixels)
    if (_scrollController.position.pixels < 100 && !_isLoadingMessages && _canLoadMoreMessages) {
      final oldestMessageId = _messages.isNotEmpty ? _messages.first.messageId : null;
      if (oldestMessageId != null) {
        print("ChatScreen: Reached top, loading older messages before ID: $oldestMessageId");
        _loadChatHistory(beforeMessageId: oldestMessageId);
      }
    }
  }

  // --- Scroll to Bottom ---
  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (jump) {
          _scrollController.jumpTo(maxScroll);
        } else {
          // Only auto-scroll if near the bottom or list is short
          final currentScroll = _scrollController.position.pixels;
          if ((maxScroll - currentScroll) < 200 || _messages.length < 10) {
            _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        }
      }
    });
  }

  // --- UI Actions ---
  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  void _selectCommunity(int id) {
    if (_selectedCommunityId == id && _selectedEventId == null) {
      Navigator.of(context).pop(); return; // Already selected
    }
    if (!mounted) return;
    // Disconnect/Cancel listeners before changing context
    _cancelWebSocketListeners();
    setState(() {
      _selectedCommunityId = id;
      _selectedEventId = null; _selectedEventDetails = null;
      _messages.clear(); _isLoadingMessages = true; _canLoadMoreMessages = true;
      _pickedFile = null; _uploadingFileName = null; _showEmojiPicker = false;
    });
    Navigator.of(context).pop(); // Close drawer
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true); // Fetch history for new room
    _connectAndListenWebSocket(); // Connect WS for new room
  }

  void selectEvent(int eventId, int communityId) {
    if (_selectedEventId == eventId) return;
    if (!mounted) return;
    _cancelWebSocketListeners();
    setState(() {
      _selectedCommunityId = communityId; _selectedEventId = eventId;
      _messages.clear(); _selectedEventDetails = null;
      _isLoadingMessages = true; _isLoadingEventDetails = true; _canLoadMoreMessages = true;
      _pickedFile = null; _uploadingFileName = null; _showEmojiPicker = false;
    });
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true);
    _loadSelectedEventDetails();
    _connectAndListenWebSocket();
  }

  void selectCommunityChat() {
    if (_selectedEventId == null) return; // Already in community chat
    if (!mounted) return;
    _cancelWebSocketListeners();
    setState(() {
      _selectedEventId = null; _selectedEventDetails = null;
      _messages.clear(); _isLoadingMessages = true; _canLoadMoreMessages = true;
      _pickedFile = null; _uploadingFileName = null; _showEmojiPicker = false;
    });
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true);
    _connectAndListenWebSocket();
  }

  void _updateChatRoomLabel() { if (mounted) setState(() {}); } // Trigger rebuild for AppBar title

  // --- Pick Attachment ---
  Future<void> _pickAttachment() async {
    PermissionStatus status;
    if (Platform.isIOS || Platform.isAndroid) {
      status = await Permission.storage.request(); // Request permission
    } else {
      status = PermissionStatus.granted; // Assume granted for desktop
    }

    if (!status.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage/Photo permission required.')));
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        const maxSizeInBytes = 25 * 1024 * 1024; // 25MB limit
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        if (fileSize > maxSizeInBytes) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large (Max 25MB).')));
          return;
        }

        if (mounted) {
          setState(() {
            _pickedFile = file;
            _showEmojiPicker = false; // Hide emoji picker
            _focusNode.unfocus(); // Hide keyboard
          });
        }
      } else {
        print("File picking cancelled.");
      }
    } catch (e) {
      print("Error picking file: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }


  // --- Send Message ---
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final fileToSend = _pickedFile; // Cache file before clearing state

    if (text.isEmpty && fileToSend == null) return; // Nothing to send
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.')));
      return;
    }

    // Get the global WebSocketService instance
    final wsService = Provider.of<WebSocketService>(context, listen: false);

    if (!wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not connected.'), backgroundColor: Colors.orange));
      // Optionally try to reconnect?
      // _connectAndListenWebSocket();
      return;
    }

    // Attachment Upload Logic
    String? attachmentUrl;
    String? attachmentType;
    String? attachmentFilename;
    if (fileToSend != null) {
      if (mounted) setState(() { _uploadingFileName = fileToSend.path.split(Platform.pathSeparator).last; _pickedFile = null; });
      try {
        final chatService = ChatService(authProvider.apiClient); // Use correct ApiClient instance
        final uploadResult = await chatService.uploadAttachment(fileToSend); // Assume this exists
        attachmentUrl = uploadResult['url'] as String?;
        attachmentType = uploadResult['type'] as String?;
        attachmentFilename = uploadResult['filename'] as String?;
        if (attachmentUrl == null || attachmentType == null || attachmentFilename == null) throw Exception("Invalid upload response keys");
        print("Attachment uploaded: $attachmentUrl");
      } catch (e) {
        print("Error uploading attachment: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
          setState(() { _uploadingFileName = null; _pickedFile = fileToSend; }); // Restore file selection on failure
        }
        return; // Stop send if upload failed
      } finally {
        // Clear uploading indicator only if we aren't restoring the file
        if (mounted && _pickedFile != fileToSend) {
          setState(() { _uploadingFileName = null; });
        }
      }
    }

    // Prepare and Send message
    final Map<String, dynamic> messagePayload = {
      'content': text, // Send text even if only attachment exists
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (attachmentFilename != null) 'attachment_filename': attachmentFilename,
    };

    try {
      final jsonPayload = jsonEncode(messagePayload);
      print("WS Sending Payload: $jsonPayload");
      wsService.sendMessage(jsonPayload); // Use the global service instance
      if (mounted) {
        _textController.clear();
        // _pickedFile was already cleared when starting upload
      }
    } catch (e) {
      print("ChatScreen: Error sending message via WebSocket: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e'), backgroundColor: Colors.red));
        if (fileToSend != null && attachmentUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File uploaded, but message send failed.'), backgroundColor: Colors.orange));
        }
      }
    }
  }


  // --- Helper Build Methods ---
  Widget _buildDrawer(bool isDark) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.8)),
            child: Text('Select Community', style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ),
          Expanded(
            child: _isLoadingCommunities
                ? const Center(child: CircularProgressIndicator())
                : _userCommunities.isEmpty
                ? const Center(child: Padding( padding: EdgeInsets.all(16.0), child: Text('Join a community to start chatting!', textAlign: TextAlign.center)))
                : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _userCommunities.length,
              itemBuilder: (context, index) {
                final community = _userCommunities[index];
                final int communityIdInt = community['id'] ?? 0;
                final String communityName = community['name'] ?? 'Unknown';
                final String? logoUrl = community['logo_url'];
                final bool isSelected = (_selectedCommunityId == communityIdInt && _selectedEventId == null);

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                    child: logoUrl == null || logoUrl.isEmpty ? Text( communityName.isNotEmpty ? communityName[0].toUpperCase() : '?', style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)) : null,
                  ),
                  title: Text(communityName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  onTap: () => _selectCommunity(communityIdInt),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create/Manage Communities'), // Combined action
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to a screen that allows creating or managing joined communities
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to Manage Communities (Not Implemented)')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEventCardContainer(bool isDark) {
    if (_selectedEventId == null) return const SizedBox.shrink();
    if (_isLoadingEventDetails) return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator(minHeight: 2));
    if (_selectedEventDetails == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration( color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.red.shade100) ),
        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Expanded(child: Text("Could not load event details.", style: TextStyle(color: Colors.redAccent))), TextButton( onPressed: selectCommunityChat, child: const Text('Back to Community'), ), ], ),
      );
    }

    final event = _selectedEventDetails!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final int? currentUserId = authProvider.userId; // Get int? ID
    // Assuming event.participants is List<int>
    final bool isJoined = currentUserId != null && event.participants.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration( border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))) ),
      child: ChatEventCard(
        event: event,
        isJoined: isJoined,
        isSelected: true, // This card indicates the current chat context
        onTap: () { /* Maybe navigate to full event details? */ },
        onJoin: () { /* Optional join/leave directly from card? */ },
        showJoinButton: false, // Usually false when it's the active chat context
        trailingWidget: TextButton(
          onPressed: selectCommunityChat,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          child: const Text('Back to Community Chat'),
        ),
      ),
    );
  }

  Widget _buildMessagesListContainer(bool isDark, int? currentUserId) {
    bool showTopLoader = _isLoadingMessages && _messages.isNotEmpty;
    return Column(
      children: [
        if (showTopLoader) const Padding( padding: EdgeInsets.symmetric(vertical: 8.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))), ),
        Expanded(
          child: (_isLoadingMessages && _messages.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(child: Text('No messages yet in this chat.', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)))
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final messageData = _messages[index];
              return ChatMessageBubble(
                message: messageData,
                currentUserId: currentUserId, // Pass int?
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(bool isDark) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return const SizedBox.shrink();

    // Watch the global service for connection state changes
    final wsService = context.watch<WebSocketService>();
    final bool isWsConnected = wsService.isConnected;

    final defaultIconColor = Theme.of(context).iconTheme.color ?? Colors.grey;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Input is enabled only if connected AND a specific chat room is selected
    final bool inputEnabled = isWsConnected && (_selectedCommunityId != null || _selectedEventId != null);
    final bool canSendMessage = inputEnabled && (_textController.text.trim().isNotEmpty || _pickedFile != null || _uploadingFileName != null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [ BoxShadow( offset: const Offset(0, -1), blurRadius: 4, color: Colors.black.withOpacity(0.1), ), ],
      ),
      child: SafeArea(
        bottom: true, // Ensure padding at bottom
        top: false, // No padding needed at top
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Uploading Indicator
              if (_uploadingFileName != null)
                Padding( padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0), child: Row( children: [ const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 8), Expanded(child: Text('Uploading $_uploadingFileName...', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)), ], ), ),
              // Picked File Preview
              if (_pickedFile != null && _uploadingFileName == null)
                Padding( padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0), child: Container( padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration( border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(4) ), child: Row( children: [ Icon(Icons.attach_file, size: 18, color: defaultIconColor), const SizedBox(width: 8), Expanded(child: Text(_pickedFile!.path.split(Platform.pathSeparator).last, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)), IconButton( icon: Icon(Icons.close, size: 18, color: defaultIconColor), onPressed: () { if (mounted) setState(() => _pickedFile = null);}, tooltip: 'Remove', padding: EdgeInsets.zero, constraints: const BoxConstraints(), visualDensity: VisualDensity.compact ), ], ), ), ),
              // Main Input Row
              Row( crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton( // Emoji Button
                  icon: Icon( _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined, color: defaultIconColor.withOpacity(inputEnabled ? 1.0 : 0.5), ),
                  tooltip: _showEmojiPicker ? "Keyboard" : "Emoji",
                  onPressed: !inputEnabled ? null : () {
                    if (!_showEmojiPicker) { _focusNode.unfocus(); Future.delayed(const Duration(milliseconds: 100), () { if (mounted) setState(() => _showEmojiPicker = true); }); }
                    else { if (mounted) setState(() => _showEmojiPicker = false); Future.delayed(const Duration(milliseconds: 100), () { _focusNode.requestFocus(); }); }
                  },
                ),
                Expanded( child: TextField( // Text Field
                  enabled: inputEnabled,
                  controller: _textController, focusNode: _focusNode,
                  decoration: InputDecoration( hintText: inputEnabled ? 'Type message...' : (wsService.isConnected ? 'Select room...' : 'Connecting...'), border: InputBorder.none, filled: true, fillColor: (isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100).withOpacity(inputEnabled ? 1.0 : 0.5), contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0), isDense: true, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), ),
                  textCapitalization: TextCapitalization.sentences, minLines: 1, maxLines: 5,
                  onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); },
                  onSubmitted: (_) => canSendMessage ? _sendMessage() : null,
                  textInputAction: TextInputAction.send,
                )),
                if (_speechEnabled) IconButton( // Voice Button
                  icon: Icon( _isListening ? Icons.mic_off_outlined : Icons.mic_none_outlined, color: _isListening ? primaryColor.withOpacity(inputEnabled ? 1.0 : 0.5) : defaultIconColor.withOpacity(inputEnabled ? 1.0 : 0.5), ),
                  onPressed: !inputEnabled ? null : (_isListening ? _stopListening : _startListening),
                  tooltip: _isListening ? 'Stop' : 'Voice input',
                ),
                IconButton( // Attach Button
                  icon: Icon( Icons.attach_file_outlined, color: defaultIconColor.withOpacity(inputEnabled ? 1.0 : 0.5), ),
                  onPressed: !inputEnabled || _uploadingFileName != null ? null : _pickAttachment,
                  tooltip: 'Attach file',
                ),
                IconButton( // Send Button
                  icon: Icon( Icons.send_outlined, color: primaryColor.withOpacity(canSendMessage ? 1.0 : 0.5), ),
                  onPressed: canSendMessage ? _sendMessage : null,
                  tooltip: 'Send',
                ),
              ]),
            ]),
      ),
    );
  }

  Widget _buildNotLoggedInView(bool isDark) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon( Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400, ),
            const SizedBox(height: 20),
            Text( 'Login to Chat', style: theme.textTheme.headlineSmall?.copyWith( fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, ), textAlign: TextAlign.center, ),
            const SizedBox(height: 8),
            Text( 'Please log in to join conversations.', style: theme.textTheme.bodyMedium?.copyWith( color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, ), textAlign: TextAlign.center, ),
            const SizedBox(height: 30),
            ElevatedButton.icon( icon: const Icon(Icons.login), label: const Text('Go to Login'), onPressed: () { Navigator.of(context).pushNamedAndRemoveUntil( '/login', (route) => false ); }, style: ElevatedButton.styleFrom( backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), textStyle: const TextStyle(fontSize: 16), ), ),
          ],
        ),
      ),
    );
  }

  String? getRoomKey(String? type, int? id) {
    return type != null && id != null && id > 0 ? "${type}_$id" : null;
  }

  String _getAppBarTitle() {
    if (_selectedEventId != null && _selectedEventDetails != null) { return _selectedEventDetails!.title; }
    else if (_selectedCommunityId != null) { final community = _userCommunities.firstWhereOrNull((c) => c['id'] == _selectedCommunityId); return community?['name'] as String? ?? 'Community Chat'; }
    else if (_isLoadingCommunities || _isLoadingMessages) { return 'Loading Chat...'; }
    else { return 'Select Community'; }
  }


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>(); // Watch auth state changes
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    // Use int? for userId from AuthProvider
    final int? currentUserId = authProvider.userId;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.menu), tooltip: "Select Community", onPressed: _toggleDrawer),
        elevation: 0.5,
      ),
      drawer: _buildDrawer(isDark),
      body: !authProvider.isAuthenticated
          ? _buildNotLoggedInView(isDark)
          : Column(
        children: [
          // Event Context Card
          _buildSelectedEventCardContainer(isDark), // Doesn't need userId directly

          // Message List Area
          Expanded(
              child: GestureDetector(
                onTap: () { // Dismiss keyboard/emoji on list tap
                  _focusNode.unfocus();
                  if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false);
                },
                child: _buildMessagesListContainer(isDark, currentUserId), // Pass int? userId
              )),

          // Input Area
          _buildInputArea(isDark),

          // Emoji Picker
          Offstage(
            offstage: !_showEmojiPicker || keyboardVisible, // Hide if keyboard is visible
            child: SizedBox(
              height: keyboardVisible ? 0 : (isPortrait ? 270 : 180), // Adjust height
              child: EmojiPicker(
                textEditingController: _textController,
                onBackspacePressed: () {
                  // Manually handle backspace for controller
                  _textController.text = _textController.text.characters.skipLast(1).toString();
                  _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
                },
                config: Config(
                  height: isPortrait ? 270 : 180,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
                    columns: isPortrait ? 8 : 12,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  swapCategoryAndBottomBar: false,
                  skinToneConfig: const SkinToneConfig(enabled: false),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Theme.of(context).cardColor,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    iconColorSelected: Theme.of(context).colorScheme.primary,
                    iconColor: Theme.of(context).iconTheme.color ?? Colors.grey,
                    dividerColor: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: true, showBackspaceButton: true, showSearchViewButton: false,
                    backgroundColor: Colors.transparent, buttonColor: Colors.transparent, buttonIconColor: Colors.grey,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Theme.of(context).cardColor,
                    buttonColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} // End of _ChatScreenState