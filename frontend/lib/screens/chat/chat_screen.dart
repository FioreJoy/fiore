// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

//--- Import pages ----
import 'community_members.dart';
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
import '../../widgets/create_event_dialog.dart'; // For event creation dialog

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';

// Custom AnimatedRotation widget for compatibility with older Flutter versions
class AnimatedRotation extends StatelessWidget {
  final Widget child;
  final double turns;
  final Duration duration;
  final Curve curve;

  const AnimatedRotation({
    Key? key,
    required this.child,
    required this.turns,
    required this.duration,
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: turns),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 2 * 3.14159, // Convert turns to radians
          child: child,
        );
      },
      child: child,
    );
  }
}



// --- Screen Imports ---
// Removed internal tab controller logic

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true; // Keep state when switching main tabs

  // --- State Variables ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // For drawer control

  // Added for toggle buttons
  bool _showChatView = true; // True for chat, false for event creation

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

  // For attachment menu animations and state
  bool _showAttachments = false;
  final _attachmentAnimationDuration = const Duration(milliseconds: 300);

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

    // Add keyboard listener to close attachment menu when keyboard shows
    WidgetsBinding.instance.addObserver(this);
  }

  // Override the didChangeMetrics method from WidgetsBindingObserver
  @override
  void didChangeMetrics() {
    if (mounted && _showAttachments && MediaQuery.of(context).viewInsets.bottom > 0) {
      // Keyboard is visible, close attachment menu
      setState(() => _showAttachments = false);
    }
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

    // Remove keyboard observer
    WidgetsBinding.instance.removeObserver(this);

    // Note: WebSocket connection itself is managed by WebSocketService and disposed via Provider
    super.dispose();
  }

  void _showLeaveConfirmationDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Leave Community'),
        content: const Text(
            'Are you sure you want to leave this community? You will no longer receive messages from this group.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Leave Community not implemented yet')),
              );
            },
            child: const Text('LEAVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
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
      final messagePayload = {'content': messageText}; // Create Map
      wsService.sendMessage(messagePayload); // Send the Map
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

  // Build toggle buttons for Chat/Create Event
  Widget _buildToggleButtons(bool isDark) {
    if (_selectedCommunityId == null) {
      return const SizedBox.shrink(); // Don't show if no community is selected
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Row(
        children: [
          // Chat button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showChatView = true;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _showChatView
                      ? (isDark ? ThemeConstants.accentColor : ThemeConstants.primaryColor)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _showChatView
                        ? Colors.white
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          ),

          // Create Event button
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showChatView = false;
                });
                _showCreateEventDialog();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !_showChatView
                      ? (isDark ? ThemeConstants.accentColor : ThemeConstants.primaryColor)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Create Event',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: !_showChatView
                        ? Colors.white
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show create event dialog
  void _showCreateEventDialog() {
    if (_selectedCommunityId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => CreateEventDialog(
        communityId: _selectedCommunityId.toString(), // Convert to string since dialog expects string
        onSubmit: (title, description, location, dateTime, maxParticipants) {
          // Handle event creation
          // Here we'd typically call an API to create the event
          // For now, just show a success message and return to chat
          Navigator.of(context).pop(); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully')),
          );
          setState(() {
            _showChatView = true; // Switch back to chat view
          });
        },
      ),
    );
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
    title: GestureDetector(
      onTap: () {
        if (_selectedCommunityId != null && _selectedEventId == null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityMembersPage(communityId: _selectedCommunityId!),
            ),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getAppBarTitle(),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_selectedCommunityId != null && _selectedEventId == null)
            const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    ),
    leading: IconButton(
      icon: const Icon(Icons.menu),
      tooltip: "Select Community",
      onPressed: _toggleDrawer,
    ),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: "More options",
        onSelected: (value) {
          switch (value) {
            case 'members':
              if (_selectedCommunityId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityMembersPage(communityId: _selectedCommunityId!),
                  ),
                );
              }
              break;
            case 'info':
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Community Info not implemented yet')),
              );
              break;
            case 'media':
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Media Gallery not implemented yet')),
              );
              break;
            case 'clear':
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clear Chat not implemented yet')),
              );
              break;
            case 'leave':
              _showLeaveConfirmationDialog();
              break;
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'members',
            child: ListTile(
              leading: Icon(Icons.people),
              title: Text('Community Members'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'info',
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Community Info'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'media',
            child: ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Media, Links & Docs'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'clear',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Clear Chat'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'leave',
            child: ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text('Leave Community', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
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

                 // Toggle buttons for Chat / Create Event
                 _buildToggleButtons(isDark),

                 // Display Event Context Card if chatting in an event room
                 if (_selectedEventId != null)
                    _buildSelectedEventCardContainer(isDark, authProvider.userId),

                 // Message List Area
                 if (_showChatView)
                   Expanded(
                     child: _buildMessagesListContainer(isDark, authProvider.userId ?? ''),
                   ),

                 // Message Input Area
                 if (_showChatView)
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
      // This already returns, which is good.
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.red.shade100)
        ),
        child: const Text("Could not load event details.", style: TextStyle(color: Colors.redAccent)),
      );
    }

    // Event found, display the card
    final event = _selectedEventDetails!; // Use ! because we checked for null
    final bool isJoined = currentUserId != null && event.participants.contains(currentUserId);

    // --- This is the main return path when event is found ---
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      // decoration: BoxDecoration( ... ), // Optional styling
      child: ChatEventCard(
        event: event,
        isJoined: isJoined,
        isSelected: true, // You fixed this - make sure ChatEventCard accepts it
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped event card: ${event.title}')));
        },
        onJoin: () { /* If needed */ },
        showJoinButton: false,
        trailingWidget: TextButton(
          onPressed: selectCommunityChat,
          child: const Text('Back to Community Chat'), // Improved text
        ),
      ),
    );

    // --- ADD THIS FINAL FALLBACK RETURN (even though it might seem redundant) ---
    // return const SizedBox.shrink();
    // Alternatively, return an error widget if logic somehow fails above
    // return const Center(child: Text("Error displaying event card"));
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

                      // Get user's profile image URL from AuthProvider for current user
                      String? profileImageUrl;
                      if (isCurrentUserMessage) {
                        // Get current user's profile image from AuthProvider
                        profileImageUrl = Provider.of<AuthProvider>(context, listen: false).userImageUrl;
                      } else {
                        // For other users, check if their profile image is included in message data
                        profileImageUrl = messageData.profile_image_url;
                      }

                      // Adapt ChatMessageData to MessageModel, now including profile image
                      final displayMessage = MessageModel(
                        id: messageData.message_id.toString(),
                        senderId: messageData.user_id.toString(),
                        senderName: messageData.username,
                        content: messageData.content,
                        timestamp: messageData.timestamp,
                        profileImageUrl: profileImageUrl, // Pass profile image URL
                      );

                      return ChatMessageBubble(
                        message: displayMessage,
                        isMe: isCurrentUserMessage,
                      );
                    },
                  ),
      ),
    ],
  );
}

  // For attachment menu animations and state
  //bool _showAttachments = false;
  //final _attachmentAnimationDuration = const Duration(milliseconds: 300);

  // Build Message Input Row
  Widget _buildMessageInput(bool isDark) {
    // Use StreamBuilder to listen to connection state changes
    return StreamBuilder<String>(
      // Get the stream from the WebSocketService provider
      stream: Provider.of<WebSocketService>(context, listen: false).connectionState,
      initialData: 'disconnected', // Assume disconnected initially
     builder: (context, snapshot) {
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    final connectionState = snapshot.data;
    final bool isWsConnected = connectionState == 'connected';

    // --- CORRECTED KEY CALCULATION AND COMPARISON ---
    // Calculate the target room key in 'type_id' format based on UI state
    final String? targetRoomKey = getRoomKey(
        _selectedEventId != null ? 'event' : 'community',
        _selectedEventId ?? _selectedCommunityId
    );

    // Get the currently connected room key from the service (also in 'type_id' format)
    final String? connectedRoomKey = wsService.currentRoomKey; // Assuming service stores 'type_id'

    // Check if connected AND the connected room matches the target room
    final bool isConnectedToCurrentRoom = isWsConnected && (connectedRoomKey == targetRoomKey) && targetRoomKey != null;
    // --- END CORRECTION ---

    final bool canSend = isConnectedToCurrentRoom && !_isSendingMessage;

        return Column(
          children: [
            // Attachment Options Panel - Animated
            AnimatedContainer(
              duration: _attachmentAnimationDuration,
              curve: Curves.easeInOut,
              height: _showAttachments ? 120 : 0, // Height when expanded/collapsed
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _showAttachments ? 16 : 0
              ),
              decoration: BoxDecoration(
                color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: _showAttachments ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, -2)
                  )
                ] : null,
              ),
              child: _showAttachments ? _buildAttachmentOptions(isDark) : null,
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                  color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]
              ),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attachment Button
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      child: IconButton(
                        icon: AnimatedRotation(
                          turns: _showAttachments ? 0.125 : 0, // 45 degrees rotation when open
                          duration: _attachmentAnimationDuration,
                          child: Icon(
                            _showAttachments ? Icons.close : Icons.add,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            size: 22,
                          ),
                        ),
                        tooltip: _showAttachments ? "Close" : "Attachments",
                        onPressed: () {
                          setState(() {
                            _showAttachments = !_showAttachments;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Message Text Field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          // Update hint text based on actual connection state to selected room
                          hintText: canSend ? 'Type a message...' : 'Connect to this room to chat...',
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
                        // Use canSend to determine if onSubmitted works
                        onSubmitted: canSend ? (_) => _sendMessage() : null,
                        // Use canSend for enabled state
                        enabled: canSend,
                        onTap: () {
                          // Close attachment menu when typing
                          if (_showAttachments) {
                            setState(() => _showAttachments = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send Button
                    CircleAvatar(
                      radius: 22,
                      // Dim button if cannot send
                      backgroundColor: canSend ? ThemeConstants.accentColor : Colors.grey,
                      child: _isSendingMessage
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.white,
                        tooltip: "Send Message",
                        // Use canSend for onPressed
                        onPressed: canSend ? _sendMessage : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Build attachment options grid
  Widget _buildAttachmentOptions(bool isDark) {
    final attachmentOptions = [
      {'icon': Icons.photo, 'label': 'Gallery', 'color': Colors.purple},
      {'icon': Icons.camera_alt, 'label': 'Camera', 'color': Colors.pink},
      {'icon': Icons.insert_drive_file, 'label': 'Document', 'color': Colors.blue},
      {'icon': Icons.location_on, 'label': 'Location', 'color': Colors.green},
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: attachmentOptions.length,
      itemBuilder: (context, index) {
        final option = attachmentOptions[index];
        return _buildAttachmentOption(
          icon: option['icon'] as IconData,
          label: option['label'] as String,
          color: option['color'] as Color,
          isDark: isDark,
          onTap: () {
            // Handle attachment option tap
            setState(() => _showAttachments = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${option['label']} attachment selected')),
            );
          },
        );
      },
    );
  }

  // Single attachment option item
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Build Not Logged In View
  // Place this method inside the State class (e.g., _ChatScreenState)
  Widget _buildNotLoggedInView(bool isDark) {
    final theme = Theme.of(context); // Get theme inside build method or context
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline, // Or another appropriate icon
              size: 80,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'Login Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in to access this feature.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Go to Login'),
              // Use Navigator to go back to the root (where login screen is shown)
              // pushNamedAndRemoveUntil is safer than pushReplacementNamed('/')
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', // Assuming '/login' route exists or handle differently
                      (route) => false // Remove all routes below login
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.accentColor,
                foregroundColor: Colors.white, // Use onPrimary color from theme if defined
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Helper to generate room key string
  String? getRoomKey(String? type, int? id) { // Make params nullable
    if (type == null || id == null || id <= 0) return null;
    return "${type}_${id}";
  }

} // End of _ChatScreenState
