// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

// --- Service Imports ---
import '../../services/api_client.dart'; // May not be needed directly if WebSocketService handles all
import '../../services/websocket_service.dart';
import '../../services/auth_provider.dart';
import '../../services/api/user_service.dart'; // To fetch communities
import '../../services/api/chat_service.dart'; // To fetch history
import '../../services/api/event_service.dart'; // To fetch event details if needed

// --- Model Imports ---
import '../../models/chat_message_data.dart';
import '../../models/event_model.dart'; // Keep for displaying selected event info
import '../../models/message_model.dart'; // Used by ChatMessageBubble

// --- Widget Imports ---
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/chat_event_card.dart'; // To display context if chatting in an event

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';

// --- Screen Imports ---
// Removed internal tab controller logic

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching main tabs

  // --- State Variables ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // For drawer control

  // IDs for the current chat context
  int? _selectedCommunityId;
  int? _selectedEventId; // If non-null, we are in an event chat room

  // Data & Loading States
  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = []; // User's joined communities
  EventModel? _selectedEventDetails; // Details of the event being chatted in

  bool _isLoadingMessages = false;
  bool _isLoadingCommunities = true;
  bool _isLoadingEventDetails = false; // For loading event card details
  bool _isSendingMessage = false;
  bool _canLoadMoreMessages = true; // Flag to prevent multiple pagination requests

  // Service Listeners / Subscriptions
  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;
  // Online count subscription might be needed if displaying it here
  // StreamSubscription? _onlineCountSubscription;


  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeChat(); // Load initial data
        _setupWebSocketListener(); // Start listening to WS service streams
      }
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    print("ChatScreen disposing...");
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    // _onlineCountSubscription?.cancel();
    // Note: WebSocket connection itself is managed by WebSocketService and disposed via Provider
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initializeChat() async {
    // Load communities first to allow selection
    await _loadUserCommunities();
    // If a community was selected/defaulted, load its messages and connect WS
    if (_selectedCommunityId != null && mounted) {
      // Set the chat context label initially
      _updateChatRoomLabel();
      // Load initial history for the default/selected community
      await _loadChatHistory(isInitialLoad: true);
      // Connect WebSocket for the selected community
      _connectWebSocket();
    }
  }

  // --- Service Listeners ---
  void _setupWebSocketListener() {
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);

    // Listen to ALL incoming raw messages
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) {
      if (!mounted) return;
      print("ChatScreen received WS message map: $messageMap");

      // Determine if it's a chat message for the CURRENTLY VIEWED room
      final currentKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
      final messageRoomKey = getRoomKey(messageMap['event_id'] != null ? 'event' : 'community', messageMap['event_id'] ?? messageMap['community_id']);

      if (messageMap.containsKey('message_id') && messageRoomKey == currentKey) {
        // It's a chat message for our current room
        try {
          final chatMessage = ChatMessageData.fromJson(messageMap);
          setState(() {
            // Avoid duplicates
            if (!_messages.any((m) => m.message_id == chatMessage.message_id)) {
              _messages.add(chatMessage);
              // Keep messages sorted by timestamp
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          });
        } catch (e) {
          print("ChatScreen: Error parsing incoming chat message: $e");
        }
      }
      // NOTE: Presence updates are handled by listening to wsService.onlineCounts separately if needed
      else if (messageMap['type'] == 'presence_update') {
        // Handled by onlineCounts stream listener (add below if needed)
        print("ChatScreen: Ignoring presence update in raw message listener.");
      }
      else {
        print("ChatScreen: Received WS message for different room or unknown type.");
      }

    }, onError: (error) {
      print("ChatScreen: Error on WS messages stream: $error");
      // Show error? Connection state stream handles general disconnects.
    });

    // Listen to connection state changes
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) {
      if (!mounted) return;
      print("ChatScreen: WS Connection State changed: $state");
      // Update UI based on state (e.g., show indicator, enable/disable input)
      // We also update button states directly in connect/disconnect methods
      setState(() {}); // Trigger rebuild to reflect potential state changes
    });

    // Optional: Listen to online counts if displayed on this screen
    // _onlineCountSubscription = wsService.onlineCounts.listen((countMap) {
    //    final currentKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
    //    if (currentKey != null && countMap.containsKey(currentKey)) {
    //       final count = countMap[currentKey];
    //       print("ChatScreen: Online count update for $currentKey: $count");
    //       // Update state variable holding the online count for the current room
    //       setState(() { _currentRoomOnlineCount = count; });
    //    }
    // });
  }

  // --- Data Fetching ---
  Future<void> _loadUserCommunities() async {
    if (!mounted) return;
    setState(() => _isLoadingCommunities = true);
    final userService = Provider.of<UserService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      setState(() { _isLoadingCommunities = false; _userCommunities = []; _selectedCommunityId = null; _selectedEventId = null; });
      return;
    }

    try {
      final communitiesData = await userService.getMyJoinedCommunities(authProvider.token!);
      if (!mounted) return;

      _userCommunities = List<Map<String, dynamic>>.from(communitiesData);
      int? initialCommunityId = _selectedCommunityId; // Preserve selection if possible

      if (_userCommunities.isNotEmpty && (initialCommunityId == null || !_userCommunities.any((c) => c['id'] == initialCommunityId))) {
        initialCommunityId = _userCommunities.first['id'] as int?;
      } else if (_userCommunities.isEmpty) {
        initialCommunityId = null;
      }

      setState(() {
        _selectedCommunityId = initialCommunityId;
        _isLoadingCommunities = false;
        _selectedEventId = null; // Reset event selection when communities load/reload
      });

    } catch (e) {
      if (!mounted) return;
      print('ChatScreen: Error loading communities: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading communities: $e')));
      setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async {
    // Determine current room context
    final String roomType = _selectedEventId != null ? 'event' : 'community';
    final int? roomId = _selectedEventId ?? _selectedCommunityId;

    if (!mounted || roomId == null) {
      print("ChatScreen: Cannot load history, no room selected.");
      setState(() { _messages = []; _isLoadingMessages = false; _canLoadMoreMessages = true; });
      return;
    }

    // Don't show full loading indicator for pagination
    if (isInitialLoad) {
      setState(() { _isLoadingMessages = true; _messages = []; _canLoadMoreMessages = true; });
    } else if (_isLoadingMessages || !_canLoadMoreMessages) {
      print("ChatScreen: Skipping load more messages (already loading or no more messages).");
      return; // Prevent concurrent loads or loading when no more exist
    } else {
      setState(() => _isLoadingMessages = true); // Indicate loading more
    }

    final chatService = Provider.of<ChatService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      setState(() { _isLoadingMessages = false; _messages = []; });
      return;
    }

    try {
      final List<dynamic> messagesData = await chatService.getChatMessages(
        token: authProvider.token!,
        communityId: roomType == 'community' ? roomId : null,
        eventId: roomType == 'event' ? roomId : null,
        limit: 50, // Fetch decent chunk
        beforeId: beforeMessageId,
      );

      if (!mounted) return;

      final newMessages = messagesData
          .map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>))
          .toList();

      // Sort oldest first for display
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        if (isInitialLoad) {
          _messages = newMessages;
        } else {
          // Prepend older messages
          _messages.insertAll(0, newMessages);
        }
        _isLoadingMessages = false;
        // If fewer messages than limit were returned, assume no more older ones
        _canLoadMoreMessages = newMessages.length >= 50;
      });

      // Scroll control after loading
      if (isInitialLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true)); // Jump to bottom on initial load
      } else {
        // Try to maintain scroll position (more complex, may need key-based approach)
        print("ChatScreen: Older messages loaded.");
      }

    } catch (e) {
      if (!mounted) return;
      print("ChatScreen: Error loading chat history: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      setState(() { _isLoadingMessages = false; });
    }
  }

  Future<void> _loadSelectedEventDetails() async {
    if (!mounted || _selectedEventId == null) return;

    setState(() => _isLoadingEventDetails = true);
    final eventService = Provider.of<EventService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; });
      return;
    }

    try {
      final eventData = await eventService.getEventDetails(_selectedEventId!, token: authProvider.token!);
      if (mounted) {
        setState(() {
          _selectedEventDetails = EventModel.fromJson(eventData);
          _isLoadingEventDetails = false;
        });
      }
    } catch (e) {
      print("ChatScreen: Error loading selected event details: $e");
      if (mounted) {
        setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; });
        // Optionally show error to user
      }
    }
  }


  // --- Scroll Listener for Pagination ---
  void _scrollListener() {
    // Load more when reaching near the top (e.g., first 100 pixels)
    if (_scrollController.position.pixels < 100 &&
        !_isLoadingMessages &&
        _canLoadMoreMessages) {
      final oldestMessageId = _messages.isNotEmpty ? _messages.first.message_id : null;
      if (oldestMessageId != null) {
        print("ChatScreen: Reached top, loading older messages before ID: $oldestMessageId");
        _loadChatHistory(beforeMessageId: oldestMessageId);
      }
    }
  }

  // --- WebSocket Connection Control ---
  void _connectWebSocket() {
    final String? roomType = _selectedEventId != null ? 'event' : 'community';
    final int? roomId = _selectedEventId ?? _selectedCommunityId;
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    if (roomId != null && token != null) {
      Provider.of<WebSocketService>(context, listen: false).connect(roomType!, roomId, token);
    } else {
      print("ChatScreen: Cannot connect WebSocket - room or token missing.");
    }
  }

  void _disconnectWebSocket() {
    Provider.of<WebSocketService>(context, listen: false).disconnect();
  }

  // --- UI Actions ---
  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // Close drawer
    } else {
      _scaffoldKey.currentState?.openDrawer(); // Open drawer
    }
    setState(() => _isDrawerOpen = !_isDrawerOpen); // Toggle state if needed elsewhere
  }

  // Called when a community is selected from the drawer
  void _selectCommunity(int id) {
    if (_selectedCommunityId == id && _selectedEventId == null) {
      Navigator.of(context).pop(); // Close drawer if same community tapped
      return;
    }
    if (!mounted) return;

    print("ChatScreen: Switching to Community $id");
    setState(() {
      _selectedCommunityId = id;
      _selectedEventId = null; // Ensure event context is cleared
      _messages = []; // Clear messages immediately
      _selectedEventDetails = null;
      _isLoadingMessages = true; // Show loading for messages
      _canLoadMoreMessages = true; // Reset pagination flag
    });
    Navigator.of(context).pop(); // Close drawer
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true); // Load history for new community
    _connectWebSocket(); // Connect WS for the new community room
  }

  // Called when an event is selected (e.g., from EventListScreen or notification)
  // This might be called via Navigator arguments or a Provider/state management solution
  void selectEvent(int eventId, int communityId) {
    if (_selectedEventId == eventId) return; // Already viewing this event chat
    if (!mounted) return;

    print("ChatScreen: Switching to Event $eventId (Community $communityId)");
    setState(() {
      _selectedCommunityId = communityId; // Ensure parent community is set
      _selectedEventId = eventId;
      _messages = [];
      _selectedEventDetails = null; // Clear previous event details
      _isLoadingMessages = true;
      _isLoadingEventDetails = true; // Load details for the card
      _canLoadMoreMessages = true;
    });
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true); // Load event chat history
    _loadSelectedEventDetails(); // Load details for the header card
    _connectWebSocket(); // Connect WS for the event room
  }

  // Selects the main community chat (deselects any event)
  void selectCommunityChat() {
    if (_selectedEventId == null) return; // Already viewing community chat
    if (!mounted) return;

    print("ChatScreen: Switching back to Community $_selectedCommunityId chat");
    setState(() {
      _selectedEventId = null;
      _selectedEventDetails = null;
      _messages = [];
      _isLoadingMessages = true;
      _canLoadMoreMessages = true;
    });
    _updateChatRoomLabel();
    _loadChatHistory(isInitialLoad: true); // Load community chat history
    _connectWebSocket(); // Connect WS for the community room
  }

  void _updateChatRoomLabel() {
    // Update UI - This might be better handled via setState in the build method directly
    // based on _selectedCommunityId and _selectedEventId
  }


  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !mounted || _isSendingMessage) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return; // Should be logged in

    final wsService = Provider.of<WebSocketService>(context, listen: false);

    // Ensure connected to the correct room before sending
    final currentKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
    if (wsService.currentRoomKey != currentKey || !wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not connected to this chat room.'), backgroundColor: Colors.orange));
      // Optionally attempt to connect here
      // _connectWebSocket();
      return;
    }

    setState(() => _isSendingMessage = true);

    try {
      // Backend expects JSON like {"content": "..."}
      final messagePayload = jsonEncode({"content": messageText});
      wsService.sendMessage(messagePayload); // Send via WebSocketService
      _messageController.clear(); // Clear input on successful send attempt

    } catch (e) {
      print("ChatScreen: Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }


  // --- UI Build Methods ---

  void _scrollToBottom([bool jump = false]) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (jump) {
          _scrollController.jumpTo(maxScroll);
        } else {
          // Only auto-scroll smoothly if near the bottom
          final currentScroll = _scrollController.position.pixels;
          if ((maxScroll - currentScroll) < 200) { // Adjust threshold as needed
            _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        }
      }
    });
  }

  String _getAppBarTitle() {
    if (_selectedEventId != null && _selectedEventDetails != null) {
      return _selectedEventDetails!.title; // Event Title
    } else if (_selectedCommunityId != null) {
      final community = _userCommunities.firstWhereOrNull((c) => c['id'] == _selectedCommunityId);
      return community?['name'] ?? 'Community Chat'; // Community Name
    } else {
      return 'Chat'; // Default
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Listen to auth provider to potentially show login view if logged out
    final authProvider = Provider.of<AuthProvider>(context);
    // Listen to WS Service for connection state ONLY if needed for UI indication beyond buttons
    // final wsService = Provider.of<WebSocketService>(context);

    return Scaffold(
      key: _scaffoldKey, // Assign key for drawer control
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.menu), // Standard drawer icon
            tooltip: "Select Community",
            onPressed: _toggleDrawer // Use specific toggle function
        ),
        // Add actions if needed (e.g., search messages, room info)
        actions: [
          // Example: Show connection status icon
          // Padding(
          //   padding: const EdgeInsets.only(right: 16.0),
          //   child: Icon(
          //      wsService.isConnected ? Icons.wifi : Icons.wifi_off,
          //      color: wsService.isConnected ? Colors.green : Colors.grey,
          //      size: 20,
          //    ),
          // )
        ],
      ),
      drawer: _buildDrawer(isDark), // Add the drawer widget
      body: !authProvider.isAuthenticated
          ? _buildNotLoggedInView(isDark) // Show if logged out
          : Column(
        children: [
          // Optional: Loading indicator for initial community load
          if (_isLoadingCommunities)
            const LinearProgressIndicator(minHeight: 2),

          // Display Event Context Card if chatting in an event room
          if (_selectedEventId != null)
            _buildSelectedEventCardContainer(isDark, authProvider.userId),

          // Message List Area
          Expanded(
            child: _buildMessagesListContainer(isDark, authProvider.userId ?? ''),
          ),

          // Message Input Area
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  // --- Helper Build Methods ---

  // Build Community Selection Drawer
  Widget _buildDrawer(bool isDark) {
    // Similar implementation to previous version, using _userCommunities
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.8)),
            child: Text('Select Community', style: Theme.of(context).primaryTextTheme.headlineMedium),
          ),
          Expanded(
            child: _isLoadingCommunities
                ? const Center(child: CircularProgressIndicator())
                : _userCommunities.isEmpty
                ? const Center(child: Text('No communities joined yet.'))
                : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _userCommunities.length,
              itemBuilder: (context, index) {
                final community = _userCommunities[index];
                final communityIdInt = community['id'] as int;
                // Check if this is the selected context (community chat, not event chat)
                final isSelected = (_selectedCommunityId == communityIdInt && _selectedEventId == null);
                final String? logoUrl = community['logo_url'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? ThemeConstants.accentColor : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                    backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
                    child: logoUrl == null ? Text((community['name'] as String)[0].toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold)) : null,
                  ),
                  title: Text(community['name'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedTileColor: ThemeConstants.accentColor.withOpacity(0.1),
                  onTap: () => _selectCommunity(communityIdInt),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile( // Optional: Go to communities screen
            leading: const Icon(Icons.list_alt),
            title: const Text('Manage Communities'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Navigate to CommunitiesScreen
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to Manage Communities')));
            },
          ),
        ],
      ),
    );
  }

  // Build Event Context Card (when chatting in an event)
  Widget _buildSelectedEventCardContainer(bool isDark, String? currentUserId) {
    if (_isLoadingEventDetails) {
      return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: LinearProgressIndicator(minHeight: 2)));
    }
    if (_selectedEventDetails == null) {
      // Optionally show a placeholder if details couldn't load
      return const SizedBox.shrink();
    }

    // Event found, display the card
    final event = _selectedEventDetails!; // Use ! because we checked for null
    final bool isJoined = currentUserId != null && event.participants.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        // Optional: Add a slight background or border to differentiate
        // color: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.shade50,
        // borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
      ),
      child: ChatEventCard( // Use the existing widget
        event: event,
        isJoined: isJoined, // Reflects current participation status
        isSelected: true, // It's the active context
        onTap: () {
          // Maybe navigate to full event details screen?
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped event card: ${event.title}')));
        },
        // Join/Leave button on the card might be redundant if managed elsewhere, but can keep
        onJoin: () { /* Handle join/leave if needed */ },
        showJoinButton: false, // Hide join button on this context card? Your choice.
        // Add a button to switch back to community chat
        trailingWidget: TextButton(
          onPressed: selectCommunityChat, // Call function to switch context
          child: const Text('View Community Chat'),
        ),
      ),
    );
  }

  // Build Message List Container (Handles loading/empty states)
  Widget _buildMessagesListContainer(bool isDark, String currentUserId) {
    // Show loading indicator at the top if fetching older messages
    bool showTopLoader = _isLoadingMessages && _messages.isNotEmpty;

    return Column(
      children: [
        if (showTopLoader)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        Expanded(
          child: (_isLoadingMessages && _messages.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(child: Text('No messages yet.', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)))
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final messageData = _messages[index];
              final bool isCurrentUserMessage = currentUserId.isNotEmpty && (messageData.user_id.toString() == currentUserId);

              // Adapt ChatMessageData to MessageModel if ChatMessageBubble expects it
              final displayMessage = MessageModel(
                id: messageData.message_id.toString(), userId: messageData.user_id.toString(),
                username: isCurrentUserMessage ? "Me" : messageData.username, content: messageData.content,
                timestamp: messageData.timestamp, isCurrentUser: isCurrentUserMessage,
              );
              return ChatMessageBubble(message: displayMessage);
            },
          ),
        ),
      ],
    );
  }

  // Build Message Input Row
  Widget _buildMessageInput(bool isDark) {
    // Use Consumer to get WebSocket connection state for enabling/disabling input
    return Consumer<WebSocketService>(
        builder: (context, wsService, child) {
          // Can only send if WS is connected to the currently selected room
          final currentKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
          final bool canSend = wsService.isConnected && wsService.currentRoomKey == currentKey;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
                color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: canSend ? 'Type a message...' : 'Connect to chat...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: canSend ? (_) => _sendMessage() : null,
                      enabled: canSend && !_isSendingMessage, // Enable only if connected and not sending
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: canSend ? ThemeConstants.accentColor : Colors.grey, // Dim if cannot send
                    child: _isSendingMessage
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.white, // Always white for contrast
                      tooltip: "Send Message",
                      onPressed: canSend ? _sendMessage : null, // Enable only if connected
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // Build Not Logged In View
  Widget _buildNotLoggedInView(bool isDark) { /* ... keep original ... */ }

  // Helper to generate room key string
  String? getRoomKey(String? type, int? id) {
    if (type == null || id == null || id <= 0) return null;
    return "${type}_${id}";
  }

} // End of _ChatScreenState
