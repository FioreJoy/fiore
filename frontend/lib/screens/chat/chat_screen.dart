// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

// --- Service Imports ---
import '../../services/websocket_service.dart';
import '../../services/auth_provider.dart';
import '../../services/api/user_service.dart';
import '../../services/api/chat_service.dart';
import '../../services/api/event_service.dart';

// --- Model Imports ---
import '../../models/chat_message_data.dart';
import '../../models/event_model.dart';

// --- NEW Widget Imports ---
import '_chat_drawer.dart'; // Import the new drawer widget
import '_chat_messages_view.dart'; // Import the new message list widget
import '_chat_input.dart'; // Import the new input widget
import '../../widgets/chat_event_card.dart'; // Keep for event context card

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // --- State Variables ---
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Context State
  int? _selectedCommunityId;
  int? _selectedEventId;

  // Data & Loading States
  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = [];
  EventModel? _selectedEventDetails;
  String? _errorLoadingCommunities;
  String? _errorLoadingMessages;
  String? _errorLoadingEventDetails;

  bool _isLoadingMessages = false;
  bool _isLoadingCommunities = true;
  bool _isLoadingEventDetails = false;
  bool _isSendingMessage = false;
  bool _canLoadMoreMessages = true;

  // WS State & Listeners
  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;
  StreamSubscription? _onlineCountSubscription;
  Map<String, int> _roomOnlineCounts = {}; // Store online counts per roomKey
  String _currentWsConnectionState = 'disconnected'; // Local copy for UI


  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    print("ChatScreen initState");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeChat();
        _setupWebSocketListener();
      }
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    print("ChatScreen disposing...");
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    _onlineCountSubscription?.cancel();
    super.dispose();
  }

  // --- Initialization & Data Loading ---
  Future<void> _initializeChat() async {
    await _loadUserCommunities();
    if (_selectedCommunityId != null && mounted) {
      _updateChatRoomLabel();
      await _loadChatHistory(isInitialLoad: true);
      _connectWebSocket();
    } else {
      if(mounted) setState(() => _isLoadingMessages = false);
    }
  }

  void _setupWebSocketListener() {
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _wsMessagesSubscription?.cancel(); _wsConnectionStateSubscription?.cancel(); _onlineCountSubscription?.cancel();
    print("ChatScreen: Setting up WebSocket listeners...");

    // Listen to Raw Messages
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) {
      if (!mounted) return;
      final currentViewedRoomKey = _getCurrentRoomKey();
      final messageRoomKey = getRoomKey(messageMap['event_id'] != null ? 'event' : 'community', messageMap['event_id'] ?? messageMap['community_id']);

      if (messageMap.containsKey('message_id') && messageRoomKey == currentViewedRoomKey && currentViewedRoomKey != null) {
        try { final chatMessage = ChatMessageData.fromJson(messageMap); if (!_messages.any((m) => m.message_id == chatMessage.message_id)) {
            setState(() { _messages.add(chatMessage); _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
               final currentUserId = int.tryParse(authProvider.userId ?? ''); bool isOwnMessage = currentUserId != null && chatMessage.user_id == currentUserId;
               WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jumpIfAtBottom: true, jumpIfOwn: isOwnMessage));}); } else { print("ChatScreen: Ignoring duplicate message ID ${chatMessage.message_id}"); }
        } catch (e, s) { print("ChatScreen: Error parsing ChatMessageData: $e\n$s"); } }
    }, onError: (error) { if (mounted) print("ChatScreen: Error on WS raw messages stream: $error"); });

    // Listen to Connection State
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) {
      if (!mounted) return; print("ChatScreen: WS Connection State changed: $state");
      setState(() { _currentWsConnectionState = state; });
    });

    // Listen to Online Counts
     _onlineCountSubscription = wsService.onlineCounts.listen((countMap) {
       if (!mounted) return; print("ChatScreen: Received online counts update: $countMap");
       setState(() { _roomOnlineCounts = countMap; });
     });
  }

  Future<void> _loadUserCommunities() async {
     if (!mounted) return; setState(() { _isLoadingCommunities = true; _errorLoadingCommunities = null; });
     final userService = Provider.of<UserService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
     if (!authProvider.isAuthenticated || authProvider.token == null) { setState(() { _isLoadingCommunities = false; _userCommunities = []; _selectedCommunityId = null; _selectedEventId = null; }); return; }
     try { final communitiesData = await userService.getMyJoinedCommunities(authProvider.token!); if (!mounted) return;
       _userCommunities = List<Map<String, dynamic>>.from(communitiesData); int? initialCommunityId = _selectedCommunityId;
       if (_userCommunities.isNotEmpty && (initialCommunityId == null || !_userCommunities.any((c) => c['id'] == initialCommunityId))) { initialCommunityId = _userCommunities.first['id'] as int?; } else if (_userCommunities.isEmpty) { initialCommunityId = null; }
       setState(() { _selectedCommunityId = initialCommunityId; _isLoadingCommunities = false; _selectedEventId = null; });
     } catch (e) { if (mounted) setState(() { _isLoadingCommunities = false; _errorLoadingCommunities = e.toString(); }); }
  }

  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async {
     final String? roomType = _selectedEventId != null ? 'event' : (_selectedCommunityId != null ? 'community' : null); final int? roomId = _selectedEventId ?? _selectedCommunityId;
     if (!mounted || roomType == null || roomId == null) { if (mounted) setState(() { _messages = []; _isLoadingMessages = false; _canLoadMoreMessages = true; _errorLoadingMessages = "No room selected"; }); return; }
     if (!isInitialLoad && (_isLoadingMessages || !_canLoadMoreMessages)) { print("ChatScreen: Skipping load more."); return; }
     setState(() { _isLoadingMessages = true; if (isInitialLoad) _messages = []; _errorLoadingMessages = null; });
     final chatService = Provider.of<ChatService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
     if (!authProvider.isAuthenticated || authProvider.token == null) { if (mounted) setState(() { _isLoadingMessages = false; _messages = []; _errorLoadingMessages = "Not logged in"; }); return; }
     try { final List<dynamic> messagesData = await chatService.getChatMessages( token: authProvider.token!, communityId: roomType == 'community' ? roomId : null, eventId: roomType == 'event' ? roomId : null, limit: 50, beforeId: beforeMessageId,); if (!mounted) return;
       final newMessages = messagesData.map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>)).toList(); newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
       setState(() { if (isInitialLoad) _messages = newMessages; else _messages.insertAll(0, newMessages); _isLoadingMessages = false; _canLoadMoreMessages = newMessages.length >= 50; });
       if (isInitialLoad) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true)); else print("ChatScreen: Older messages loaded (${newMessages.length}).");
     } catch (e) { if (mounted) setState(() { _isLoadingMessages = false; _errorLoadingMessages = e.toString(); }); }
   }

  Future<void> _loadSelectedEventDetails() async {
      if (!mounted || _selectedEventId == null) return; setState(() { _isLoadingEventDetails = true; _errorLoadingEventDetails = null; });
      final eventService = Provider.of<EventService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
       if (!authProvider.isAuthenticated || authProvider.token == null) { setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; _errorLoadingEventDetails = "Not logged in"; }); return; }
      try { final eventData = await eventService.getEventDetails(_selectedEventId!, token: authProvider.token!); if (mounted) setState(() { _selectedEventDetails = EventModel.fromJson(eventData); _isLoadingEventDetails = false; });
      } catch (e) { if (mounted) setState(() { _isLoadingEventDetails = false; _errorLoadingEventDetails = e.toString(); _selectedEventDetails = null; }); }
   }

  // --- Scroll Listener ---
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

  // --- WebSocket Control ---
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
   void _disconnectWebSocket() { Provider.of<WebSocketService>(context, listen: false).disconnect(); }

  // --- UI Actions ---

  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // Close drawer
    } else {
      _scaffoldKey.currentState?.openDrawer(); // Open drawer
    }
    setState(() => _isDrawerOpen = !_isDrawerOpen); // Toggle state if needed elsewhere
  }
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

  void _updateChatRoomLabel() { setState(() {}); } // Triggers AppBar rebuild

  Future<void> _sendMessage(String messageText) async { // Takes text from ChatInput callback
    if (messageText.isEmpty || !mounted || _isSendingMessage) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    final currentKey = _getCurrentRoomKey();
    if (currentKey == null || wsService.currentRoomKey != currentKey || !wsService.isConnected) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not connected to ${currentKey ?? 'chat'}. Cannot send.'), backgroundColor: Colors.orange)); return; }
    setState(() => _isSendingMessage = true);
    try {
      final messagePayload = {'content': messageText}; wsService.sendMessage(messagePayload);
      // Do NOT clear controller here, ChatInput owns it
    } catch (e) { print("ChatScreen: Error sending message: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSendingMessage = false); }
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

  String? _getCurrentRoomKey() { /* Keep implementation from previous version */
       return getRoomKey( _selectedEventId != null ? 'event' : (_selectedCommunityId != null ? 'community' : null), _selectedEventId ?? _selectedCommunityId);
   }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context); final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    // Determine connection status for the *currently selected* room
    final wsService = Provider.of<WebSocketService>(context); // Listen for rebuilds
    final currentKey = _getCurrentRoomKey();
    final bool isConnectedToCurrentRoom = wsService.isConnected && wsService.currentRoomKey == currentKey;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(_getAppBarTitle(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            _buildOnlineCountIndicator(), // Use helper
          ],),
        leading: IconButton( icon: const Icon(Icons.menu), tooltip: "Select Community", onPressed: _toggleDrawer),
      ),
      // Use the NEW ChatDrawer widget
      drawer: ChatDrawer(
          isLoading: _isLoadingCommunities,
          communities: _userCommunities,
          selectedCommunityId: _selectedCommunityId,
          selectedEventId: _selectedEventId,
          onCommunitySelected: _selectCommunity,
          error: _errorLoadingCommunities,
      ),
      body: !authProvider.isAuthenticated
          ? _buildNotLoggedInView(isDark)
          : Column( children: [
                 // Show community loading indicator only when userCommunities is empty initially
                 if (_isLoadingCommunities && _userCommunities.isEmpty)
                    const LinearProgressIndicator(minHeight: 2),
                 // Show error loading communities if relevant
                 if (_errorLoadingCommunities != null && _userCommunities.isEmpty)
                    Padding(padding: const EdgeInsets.all(16), child: Text("Error loading communities: $_errorLoadingCommunities", style: const TextStyle(color: Colors.red))),

                 // Event Context Card
                 if (_selectedEventId != null)
                    _buildSelectedEventCardContainer(isDark, authProvider.userId),

                 // Message List Area - uses the new dedicated widget
                 Expanded(
                   child: ChatMessagesView(
                      messages: _messages,
                      scrollController: _scrollController,
                      isLoading: _isLoadingMessages, // Pass loading state for messages
                      error: _errorLoadingMessages, // Pass error state for messages
                      currentUserId: authProvider.userId ?? '', // Pass current user ID
                      canLoadMore: _canLoadMoreMessages,
                    ),
                 ),

                 // Input Area - uses the new dedicated widget
                 ChatInput(
                     messageController: _messageController,
                     onSendMessage: _sendMessage, // Pass callback
                     isSending: _isSendingMessage, // Pass sending state
                     isConnected: isConnectedToCurrentRoom, // Pass calculated connection state
                 ),
              ],),
    );
  }

  // --- Helper Build Methods ---
  Widget _buildOnlineCountIndicator() { /* Keep implementation from previous version */
      final currentKey = _getCurrentRoomKey(); final count = _roomOnlineCounts[currentKey] ?? 0; final wsService = Provider.of<WebSocketService>(context, listen: false); final isConnected = wsService.isConnected && wsService.currentRoomKey == currentKey; if (!isConnected || currentKey == null) return const SizedBox.shrink();
      return Padding( padding: const EdgeInsets.only(right: 16.0), child: Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.circle, size: 10, color: count > 0 ? Colors.green.shade400 : Colors.grey.shade400), const SizedBox(width: 4), Text( count > 0 ? "$count Online" : (count == 0 ? "0 Online" : ""), style: Theme.of(context).textTheme.bodySmall?.copyWith( color: count > 0 ? Colors.green.shade600 : Colors.grey.shade500),)],),);
   }
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

  // Build Not Logged In View (Keep implementation)
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
  // Helper to generate room key string (Keep implementation)
  String? getRoomKey(String? type, int? id) { if (type == null || id == null || id <= 0) return null; return "${type}_${id}"; }

} // End of _ChatScreenState
