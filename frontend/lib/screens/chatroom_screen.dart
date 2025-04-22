// frontend/lib/screens/chatroom_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // <--- ADDED Import for File (needed if event creation includes image)
import 'dart:async'; // For StreamSubscription, Timer
import 'dart:convert'; // For jsonEncode

import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/theme_constants.dart';
import '../models/event_model.dart';
import '../models/chat_message_data.dart';
import '../models/message_model.dart'; // Used for ChatMessageBubble
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_event_card.dart';
import '../widgets/create_event_dialog.dart';
// import 'dart:math' as math; // Was unused, removed


// Define placeholder outside the State class
class _EventModelPlaceholder extends EventModel {
  _EventModelPlaceholder() : super(
      id: '0', title: 'Event not found', description: '', location: '',
      dateTime: DateTime.now(), maxParticipants: 0, participants: [],
      creatorId: '', communityId: '', imageUrl: null
  );
}


class ChatroomScreen extends StatefulWidget {
  const ChatroomScreen({Key? key}) : super(key: key);

  @override
  _ChatroomScreenState createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  // --- State Variables ---
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDrawerOpen = false;
  late AnimationController _fabAnimationController;

  int? _currentCommunityId; // ID of the community whose chat/events are being viewed
  int? _selectedEventId; // ID of the specific event chat being viewed (null for community chat)

  List<ChatMessageData> _messages = [];
  List<EventModel> _events = [];
  List<Map<String, dynamic>> _userCommunities = []; // Stores user's joined communities {id, name, logo_url?, ...}

  bool _isLoadingMessages = false;
  bool _isLoadingEvents = false;
  bool _isLoadingCommunities = true; // Start loading communities initially
  bool _isSendingMessage = false;

  StreamSubscription? _messageSubscription; // Subscription to ApiService message stream
  Timer? _reconnectTimer; // Timer for WebSocket reconnection attempts
  File? _pickedEventImage; // Variable to hold image picked for event creation


  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: ThemeConstants.shortAnimation,
    );

    // Load user's communities first when the screen initializes
    // Use addPostFrameCallback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserCommunities();
      }
    });

    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _messageController.dispose();
    _fabAnimationController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _reconnectTimer?.cancel();
    // Safely dispose WebSocket resources
    try {
      // Use the disposeWebSocket method in ApiService
      Provider.of<ApiService>(context, listen: false).disposeWebSocket();
    } catch (e) {
      print("Error disposing WebSocket via ApiService: $e");
    }
    super.dispose();
  }

  // --- Scroll Listener ---
  void _scrollListener() {
    // Example: Load older messages when reaching the top
    if (_scrollController.position.atEdge && _scrollController.position.pixels == 0 && !_isLoadingMessages) {
      // Check if there are older messages to load based on the oldest message ID currently displayed
      final oldestMessageId = _messages.isNotEmpty ? _messages.first.message_id : null;
      if (oldestMessageId != null) {
        print("Reached top, loading older messages before ID: $oldestMessageId");
        _loadOlderMessages(oldestMessageId);
      }
    }
  }

  // --- Tab Change Listener ---
  void _handleTabChange() {
    if (!mounted) return;
    // If switching away from the Chat tab AND an event is selected, keep the event context
    // If switching back TO Chat tab from Events tab, reset event selection ONLY IF no event is selected
    if (_tabController.index == 0 && _selectedEventId != null) {
      // Still viewing event chat, no change needed immediately, WS should stay connected
    } else if (_tabController.index == 1) {
      // Switched to Events tab, disconnect WS ONLY IF viewing community chat
      if (_selectedEventId == null) {
        print("Switched to Events tab (no event selected), disconnecting WebSocket.");
        Provider.of<ApiService>(context, listen: false).disconnectWebSocket();
      }
    } else if (_tabController.index == 0 && _selectedEventId == null) {
      // Switched back to community chat view on Chat tab
      print("Switched back to community chat view, setting up WebSocket.");
      _setupWebSocket(); // Ensure WS is connected for the community
    }
    // Force rebuild to update UI based on tab (e.g., show/hide FAB)
    setState(() {});
  }

  // --- Data Loading ---
  Future<void> _loadUserCommunities() async {
    if (!mounted) return;
    setState(() => _isLoadingCommunities = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      setState(() { _isLoadingCommunities = false; _userCommunities = []; _currentCommunityId = null; });
      return;
    }

    try {
      // Assuming fetchCommunities returns List<Map<String, dynamic>>
      final communitiesData = await apiService.fetchCommunities(authProvider.token);
      if (!mounted) return;

      _userCommunities = List<Map<String, dynamic>>.from(communitiesData);

      // Determine initial community to display
      int? initialCommunityId = _currentCommunityId;
      if (_userCommunities.isNotEmpty && (initialCommunityId == null || !_userCommunities.any((c) => c['id'] == initialCommunityId))) {
        // Default to the first community if none is selected or the selected one is gone
        initialCommunityId = _userCommunities.first['id'] as int?;
      } else if (_userCommunities.isEmpty) {
        initialCommunityId = null; // No communities
      }

      // Use setState only once at the end if possible
      setState(() {
        _currentCommunityId = initialCommunityId;
        _isLoadingCommunities = false;
        // Reset messages/events/event selection when communities reload
        _messages = [];
        _events = [];
        _selectedEventId = null;
      });

      // Load messages/events for the determined community (if any)
      if (_currentCommunityId != null) {
        _loadMessagesAndEvents(); // This will also setup WebSocket
      } else {
        // Ensure WS is disconnected if there are no communities
        Provider.of<ApiService>(context, listen: false).disconnectWebSocket();
        setState(() { _isLoadingMessages = false; _isLoadingEvents = false; }); // Reset loading states
      }

    } catch (e) {
      if (!mounted) return;
      print('Error loading communities: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading communities: $e')));
      setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _loadMessagesAndEvents({bool loadOlder = false, int? beforeId}) async {
    if (!mounted || (_currentCommunityId == null && _selectedEventId == null)) {
      print("Skipping load: No community or event selected.");
      return; // Need at least one context
    }

    // Don't show full loading indicator when fetching older messages
    if (!loadOlder) {
      setState(() { _isLoadingMessages = true; _isLoadingEvents = true; });
    } else {
      // Optionally show a small indicator at the top while loading older
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      setState(() { _isLoadingMessages = false; _isLoadingEvents = false; _messages = []; _events = []; });
      return;
    }

    try {
      // Determine context for fetching messages
      int? fetchCommunityId = _selectedEventId == null ? _currentCommunityId : null;
      int? fetchEventId = _selectedEventId;

      // Fetch messages
      final messagesData = await apiService.fetchChatMessages(
        communityId: fetchCommunityId,
        eventId: fetchEventId,
        token: authProvider.token!,
        limit: 30, // Fetch a reasonable number of messages
        beforeId: beforeId, // Pass cursor for pagination
      );

      // Fetch events only if loading initial data for a community view
      List<EventModel> fetchedEvents = _events; // Keep existing events if loading older messages or event chat
      if (!loadOlder && _selectedEventId == null && _currentCommunityId != null) {
        fetchedEvents = await apiService.fetchCommunityEvents(_currentCommunityId!, authProvider.token!);
      }

      if (!mounted) return;

      // Process fetched messages
      final newMessages = messagesData
          .map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>))
          .toList();

      // Sort new messages (API might already return sorted, but ensure consistency)
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first

      setState(() {
        if (loadOlder) {
          // Prepend older messages to the existing list
          _messages.insertAll(0, newMessages);
        } else {
          // Replace existing messages with the newly fetched initial set
          _messages = newMessages;
        }

        _events = fetchedEvents; // Update events list if fetched
        _isLoadingMessages = false; // Loading complete
        _isLoadingEvents = false; // Loading complete
      });

      // Scroll control
      if (!loadOlder) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true)); // Jump to bottom on initial load
      } else if (newMessages.isNotEmpty) {
        // Keep scroll position relative to the older messages loaded (more complex, needs specific implementation)
        print("Older messages loaded, scroll position maintained (approx).");
      }

      // Setup WebSocket only on initial load, not when fetching older messages
      if (!loadOlder) {
        _setupWebSocket();
      }

    } catch (e) {
      if (!mounted) return;
      print('Error loading messages/events: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      setState(() { _isLoadingMessages = false; _isLoadingEvents = false; });
    }
  }

  // Function to trigger loading older messages
  Future<void> _loadOlderMessages(int beforeMessageId) async {
    await _loadMessagesAndEvents(loadOlder: true, beforeId: beforeMessageId);
  }


  // --- WebSocket Management ---
  void _setupWebSocket() {
    if (!mounted) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Determine the correct room to connect to
    String? roomType;
    int? roomId;

    if (_selectedEventId != null) {
      roomType = "event";
      roomId = _selectedEventId;
    } else if (_currentCommunityId != null) {
      // Connect to community room regardless of tab,
      // disconnect happens explicitly in tab handler if needed
      roomType = "community";
      roomId = _currentCommunityId;
    }

    // Proceed only if authenticated and a valid room is determined
    if (authProvider.isAuthenticated && roomType != null && roomId != null) {
      // Call connectWebSocket from ApiService
      apiService.connectWebSocket(roomType, roomId, authProvider.token);

      // Cancel previous subscription if exists
      _messageSubscription?.cancel();

      // Subscribe to the message stream from ApiService
      _messageSubscription = apiService.messages.listen(
              (chatMessage) {
            if (!mounted) return;
            setState(() {
              // Avoid duplicates if message is received via WS after optimistic UI or HTTP fallback
              final index = _messages.indexWhere((m) => m.message_id == chatMessage.message_id);
              if (index == -1) {
                _messages.add(chatMessage); // Add new message
                // Sort just in case messages arrive slightly out of order via WS
                _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              } else {
                // Optional: Update existing message if needed (e.g., replace temp ID)
                // _messages[index] = chatMessage;
                print("Duplicate message ignored/updated: ${chatMessage.message_id}");
              }
            });
          },
          onError: (error) {
            if (!mounted) return;
            print("Error on WebSocket message stream: $error");
            // Don't schedule reconnection here, ApiService might handle it or provide status
            // You could show a visual indicator of connection status based on ApiService state
            // _scheduleReconnection(); // Remove direct scheduling here
          },
          onDone: () {
            if (!mounted) return;
            print("WebSocket stream closed by ApiService/Server.");
            // Don't schedule reconnection here, ApiService might handle it
            // _scheduleReconnection(); // Remove direct scheduling here
          }
      );
    } else {
      print("WebSocket setup skipped: Conditions not met (Auth: ${authProvider.isAuthenticated}, Room: $roomType/$roomId)");
      apiService.disconnectWebSocket(); // Ensure WS is disconnected if conditions aren't met
    }
  }

  // Keep this function if you want manual reconnection logic triggered by UI,
  // but rely on ApiService internal reconnection first if it has it.
  // void _scheduleReconnection() { ... }

  // --- UI Actions ---
  void _toggleDrawer() {
    if (mounted) setState(() => _isDrawerOpen = !_isDrawerOpen);
  }

  void _switchCommunity(int id) {
    if (_currentCommunityId == id) {
      if (mounted) setState(() => _isDrawerOpen = false); // Close drawer
      return;
    }
    if (!mounted) return;

    setState(() {
      _currentCommunityId = id;
      _selectedEventId = null; // Reset event selection
      _isDrawerOpen = false;
      _messages = []; // Clear immediately for responsiveness
      _events = [];
      _isLoadingMessages = true; // Show loading states
      _isLoadingEvents = true;
      // Ensure Chat tab is selected when switching community
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      } else {
        // If already on chat tab, trigger load immediately
        _loadMessagesAndEvents();
      }
      // Note: _loadMessagesAndEvents will be called by the tab listener if animateTo was used
    });
    // If already on the Chat tab, the listener won't fire, so call explicitly:
    // if (_tabController.index == 0) {
    //    _loadMessagesAndEvents(); // This also calls _setupWebSocket
    // } // -> Redundant now handled in the setState logic above
  }

  // Switch between viewing community chat and a specific event chat
  void _switchEvent(int? eventId) {
    if (_selectedEventId == eventId || !mounted) return; // No change or not mounted
    print("Switching event view to: $eventId");
    setState(() {
      _selectedEventId = eventId;
      _messages = []; // Clear messages for the new context
      _isLoadingMessages = true;
      // If switching TO an event, ensure Chat tab is active
      if (eventId != null && _tabController.index != 0) {
        _tabController.animateTo(0);
      }
    });
    // Reload messages (and potentially events if logic required)
    // _loadMessagesAndEvents will setup the correct WebSocket connection
    _loadMessagesAndEvents();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !mounted || _isSendingMessage) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to send messages')));
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    // final int currentUserId = int.parse(authProvider.userId!); // Assume userId is available and int

    // Clear input and set loading immediately
    if (mounted) {
      setState(() {
        _messageController.clear();
        _isSendingMessage = true;
      });
    }

    // Primary method: Send via WebSocket using ApiService method
    try {
      final messagePayload = jsonEncode({"content": messageText});
      apiService.sendWebSocketMessage(messagePayload); // ApiService handles WS connection check
      print("Message sent via WebSocket channel.");
      // We don't add optimistic message here anymore, rely on WS echo/broadcast
      // If WS fails, ApiService might internally fallback to HTTP POST,
      // or we could explicitly call the HTTP method here on specific errors.

      // Reset sending state after attempting send (WS is async, success isn't guaranteed yet)
      // A slight delay might feel better if WS echo is fast
      // await Future.delayed(Duration(milliseconds: 100));
      if (mounted) setState(() => _isSendingMessage = false);

    } catch (e) {
      // This catch block might be hit if sendWebSocketMessage throws synchronously (e.g., WS not connected)
      if (mounted) {
        print("Error sending message (WebSocket likely disconnected): $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: Connection issue?'), backgroundColor: Colors.orange));
        // Attempt HTTP fallback?
        // await _sendViaHttpFallback(messageText, authProvider.token!); // Example
        setState(() => _isSendingMessage = false); // Reset sending state on error
      }
    }
  }

  // Example HTTP fallback function (call from _sendMessage catch block if needed)
  Future<void> _sendViaHttpFallback(String messageText, String token) async {
    print("Attempting HTTP fallback for message...");
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.sendChatMessageHttp(
        content: messageText,
        communityId: _selectedEventId == null ? _currentCommunityId : null,
        eventId: _selectedEventId,
        token: token,
      );
      print("Message sent via HTTP fallback.");
      // Note: Message will appear twice if WS echo eventually arrives.
      // Need careful duplicate handling based on message_id in _setupWebSocket listener.
    } catch (httpError) {
      print("HTTP fallback also failed: $httpError");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: ${httpError.toString()}'), backgroundColor: Colors.red));
        // Optionally restore text to input field: _messageController.text = messageText;
      }
    }
  }


  void _showFabMenu() {
    if (!mounted) return;
    if (_fabAnimationController.status == AnimationStatus.completed) {
      _fabAnimationController.reverse();
    } else {
      _fabAnimationController.forward();
    }
  }

  // Add image picking logic for event creation dialog
  Future<void> _pickEventImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedEventImage = File(pickedFile.path);
      });
      // Re-show dialog or update existing one if possible? Complex.
      // Better to pick image *within* the dialog itself.
      // This state variable might be better managed within the CreateEventDialog state.
      print("Event image picked, path: ${pickedFile.path}");
    }
  }

  void _showCreateEventDialog() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to create events')));
      return;
    }
    if (_currentCommunityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a community first')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateEventDialog(
        // Pass community ID
        communityId: _currentCommunityId!, // Use ! because we checked for null
        onSubmit: _createEvent, // Pass the callback function
      ),
    ).then((_) {
      // Reset picked image after dialog closes, regardless of submission
      setState(() {
        _pickedEventImage = null;
      });
    });
    _fabAnimationController.reverse(); // Close FAB menu
  }

  // Updated _createEvent to accept the image file from the dialog
  Future<void> _createEvent(
      String title, String description, String location,
      DateTime dateTime, int maxParticipants, File? imageFile // Accept File?
      ) async {
    if (!mounted || _currentCommunityId == null) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    setState(() => _isLoadingEvents = true); // Indicate loading

    try {
      // --- FIX IS HERE: Use named parameters AND pass imageFile ---
      final newEvent = await apiService.createEvent(
        communityId: _currentCommunityId!,
        title: title,
        description: description.isNotEmpty ? description : null,
        location: location,
        eventTimestamp: dateTime,
        maxParticipants: maxParticipants,
        image: imageFile, // Pass the image File object from dialog
        token: authProvider.token!,
      );
      // --- END FIX ---

      if (!mounted) return;

      setState(() {
        _events.add(newEvent); // Add to local list
        _events.sort((a, b) => a.dateTime.compareTo(b.dateTime)); // Keep sorted
        _isLoadingEvents = false;
        _tabController.animateTo(1); // Switch to Events tab
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event "${newEvent.title}" created successfully')));

    } catch (e) {
      if (!mounted) return;
      print('Error creating event: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create event: ${e.toString()}')));
      setState(() => _isLoadingEvents = false);
    }
  }


  Future<void> _joinOrLeaveEvent(EventModel event) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to join/leave events')));
      return;
    }
    final apiService = Provider.of<ApiService>(context, listen: false);

    final String currentUserId = authProvider.userId!;
    final bool currentlyJoined = event.participants.contains(currentUserId);

    // Prevent action if event is full and user tries to join
    if (!currentlyJoined && event.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot join, event is full.'), backgroundColor: Colors.orange));
      return;
    }


    // Optimistic UI update
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        final updatedParticipants = List<String>.from(event.participants); // Create mutable copy
        if (currentlyJoined) {
          updatedParticipants.remove(currentUserId);
        } else {
          updatedParticipants.add(currentUserId); // Add current user ID
        }
        // Create a new EventModel instance with updated participants
        _events[index] = EventModel(
          id: event.id, title: event.title, description: event.description, location: event.location,
          dateTime: event.dateTime, maxParticipants: event.maxParticipants, creatorId: event.creatorId,
          communityId: event.communityId, imageUrl: event.imageUrl,
          participants: updatedParticipants, // Use the updated list
        );
      }
    });

    try {
      if (currentlyJoined) {
        await apiService.leaveEvent(event.id, authProvider.token!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You left "${event.title}"')));
      } else {
        // API call already includes check for 'full' potentially, but client-side check is good too
        await apiService.joinEvent(event.id, authProvider.token!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You joined "${event.title}"')));
      }
      // Optionally refresh full event list or details after successful action
      // _loadMessagesAndEvents(); // Could reload everything
    } catch (e) {
      if (!mounted) return;
      print('Error joining/leaving event: $e');
      // Revert optimistic update on error
      setState(() {
        final index = _events.indexWhere((ev) => ev.id == event.id); // Find index again
        if (index != -1) {
          _events[index] = event; // Put original event object back
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to ${currentlyJoined ? 'leave' : 'join'} event: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  // --- Helper Getters ---
  String _getCurrentCommunityName() {
    if (_currentCommunityId == null) return "Chat";
    final community = _userCommunities.firstWhere(
          (c) => c['id'] == _currentCommunityId,
      orElse: () => {'name': 'Community'}, // Default if not found
    );
    return community['name'] as String? ?? 'Community';
  }

  String? _getCurrentEventTitle() {
    if (_selectedEventId == null) return null;
    try {
      // Find event by ID (assuming event.id is String, selectedEventId is int)
      final event = _events.firstWhere((e) => int.tryParse(e.id) == _selectedEventId);
      return event.title;
    } catch (e) {
      return "Event"; // Fallback title
    }
  }

  // --- UI Build Methods ---

  void _scrollToBottom([bool jump = false]) {
    if (!_scrollController.hasClients) return;
    // Delay slightly to allow layout to settle after adding messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        // Only auto-scroll if user is already near the bottom or jumping
        if (jump || (maxScroll - currentScroll < 150)) {
          _scrollController.animateTo(
            maxScroll,
            duration: jump ? Duration.zero : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context); // Listen for auth changes for logged-in view

    final String currentTitle = _selectedEventId != null
        ? (_getCurrentEventTitle() ?? "Event Chat") // Use event title if selected
        : _getCurrentCommunityName(); // Otherwise use community name

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: Icon(_isDrawerOpen ? Icons.close : Icons.menu),
            tooltip: _isDrawerOpen ? "Close Communities" : "Open Communities",
            onPressed: _toggleDrawer
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chat'), Tab(text: 'Events')],
          indicatorColor: ThemeConstants.accentColor, // Use accent color for indicator
          labelColor: ThemeConstants.accentColor,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Show event details button only when an event is selected
          if (_selectedEventId != null)
            IconButton(icon: const Icon(Icons.info_outline), tooltip: "Event Details", onPressed: () {
              // TODO: Implement navigation to a dedicated Event Detail Screen or show a modal
              final selectedEvent = _events.firstWhere((e) => int.tryParse(e.id) == _selectedEventId, orElse: () => _EventModelPlaceholder());
              if (selectedEvent.id != '0') { // Check if a valid event was found
                // Show details...
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Show details for: ${selectedEvent.title}')));
              }
            }),
        ],
      ),
      body: !authProvider.isAuthenticated
          ? _buildNotLoggedInView(isDark)
          : Stack(
        children: [
          // Main Content Area
          Column(
            children: [
              // Event Chips Row (Only visible on Events tab AND if events exist and are not loading)
              if (_tabController.index == 1 && _events.isNotEmpty && !_isLoadingEvents)
                _buildEventChips(isDark),

              // Selected Event Card (Visible if an event is selected, regardless of tab)
              if (_selectedEventId != null)
                _buildSelectedEventCardContainer(isDark, authProvider.userId),


              // Chat Messages or Events List
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // Prevent swiping between tabs
                  children: [
                    // Chat Tab View
                    _buildMessagesList(isDark, authProvider.userId ?? ''),
                    // Events Tab View
                    _buildEventsList(isDark, authProvider.userId),
                  ],
                ),
              ),

              // Message Input Area (Show ONLY if on Chat tab OR if an Event chat is selected)
              if (_tabController.index == 0) // Simplified: Show only on Chat tab now
                _buildMessageInput(isDark),
            ],
          ),
          // Drawer for community selection
          _buildDrawer(isDark, size),
        ],
      ),
      // Show FAB only on Events tab
      floatingActionButton: _tabController.index == 1 && _currentCommunityId != null
          ? _buildFloatingActionButton()
          : null,
    );
  }

  // --- Helper Build Methods ---

  // Build Event Chips Row
  Widget _buildEventChips(bool isDark) {
    // Added loading indicator check within the chips row container
    if (_isLoadingEvents) {
      return Container(
          height: 60, // Match height
          alignment: Alignment.center,
          color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
          child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
      );
    }
    // No need for SizedBox if empty, let the parent Column handle layout

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          final eventIdInt = int.tryParse(event.id);
          final isSelected = _selectedEventId == eventIdInt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              avatar: Icon(Icons.event, size: 16, color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black54)),
              selected: isSelected,
              onSelected: (selected) => _switchEvent(selected ? eventIdInt : null), // Pass null to deselect
              backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
              selectedColor: ThemeConstants.accentColor.withOpacity(0.9), // Use accent color
              labelStyle: TextStyle(
                color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              side: isDark ? BorderSide(color: Colors.grey.shade700) : BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded shape
            ),
          );
        },
      ),
    );
  }


  // Build Community Selection Drawer
  Widget _buildDrawer(bool isDark, Size size) {
    // Same implementation as before, ensure it uses _isLoadingCommunities
    return Stack(
        children: [
          if (_isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleDrawer,
                child: Container(color: Colors.black.withOpacity(0.6)), // Darker overlay
              ),
            ),
          AnimatedPositioned(
            duration: ThemeConstants.mediumAnimation,
            curve: Curves.easeInOutCubic,
            left: _isDrawerOpen ? 0 : -size.width * 0.8,
            top: 0, bottom: 0, width: size.width * 0.8,
            child: Material(
              elevation: 16.0,
              child: Container(
                color: isDark ? ThemeConstants.backgroundDark : Colors.white,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        child: Text('My Communities', style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _isLoadingCommunities
                            ? const Center(child: CircularProgressIndicator())
                            : _userCommunities.isEmpty
                            ? Center(child: Text('No communities joined yet.', style: TextStyle(color: Colors.grey.shade500)))
                            : ListView.builder(
                          itemCount: _userCommunities.length,
                          itemBuilder: (context, index) {
                            final community = _userCommunities[index];
                            final communityIdInt = community['id'] as int;
                            final isSelected = _currentCommunityId == communityIdInt;
                            // TODO: Fetch or use logo_url from community data
                            final String? logoUrl = community['logo_url'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? ThemeConstants.accentColor : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                                backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null, // Use logo URL
                                child: logoUrl == null ? Text( // Show initial only if no logo
                                    (community['name'] as String)[0].toUpperCase(),
                                    style: TextStyle(color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(community['name'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedTileColor: ThemeConstants.accentColor.withOpacity(0.1),
                              onTap: () => _switchCommunity(communityIdInt),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: ThemeConstants.accentColor),
                        title: const Text('Create/Find Communities', style: TextStyle(color: ThemeConstants.accentColor)),
                        onTap: () {
                          _toggleDrawer();
                          // TODO: Navigate to Communities Screen or Create Community Screen
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to Communities Screen')));
                          // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => CommunitiesScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]
    );
  }

  // Build Floating Action Button Menu
  Widget _buildFloatingActionButton() {
    // Same implementation as before
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOutBack),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.small(
              heroTag: 'event_fab',
              onPressed: _showCreateEventDialog,
              backgroundColor: ThemeConstants.accentColor,
              tooltip: 'Create Event',
              child: const Icon(Icons.event, color: ThemeConstants.primaryColor),
            ),
          ),
        ),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _showFabMenu,
          backgroundColor: ThemeConstants.highlightColor,
          tooltip: _fabAnimationController.isCompleted ? 'Close Menu' : 'Create Event',
          child: AnimatedRotation(
            turns: _fabAnimationController.value * 0.125,
            duration: ThemeConstants.shortAnimation,
            child: Icon(
                _fabAnimationController.isCompleted ? Icons.close : Icons.add,
                color: ThemeConstants.primaryColor),
          ),
        ),
      ],
    );
  }

  // Build Message Input Row
  Widget _buildMessageInput(bool isDark) {
    // Same implementation as before
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
                  hintText: 'Type a message...',
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
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isSendingMessage,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: ThemeConstants.accentColor,
              child: _isSendingMessage
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeConstants.primaryColor))
                  : IconButton(
                icon: const Icon(Icons.send),
                color: ThemeConstants.primaryColor,
                tooltip: "Send Message",
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Not Logged In View
  Widget _buildNotLoggedInView(bool isDark) {
    // Same implementation as before
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          const SizedBox(height: 20),
          Text('Please log in to access chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Connect with communities and events', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'), // Navigate to root (Login)
            style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: ThemeConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  // Builds the list of messages for the Chat tab
  Widget _buildMessagesList(bool isDark, String currentUserId) {
    if (_isLoadingMessages && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isLoadingMessages && _messages.isEmpty) {
      final contextMessage = _selectedEventId != null
          ? 'No messages in this event yet.'
          : 'No messages in this community yet.\nStart the conversation!';
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(contextMessage, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          )
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: false, // Keep false as we load older messages at the top
      padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8.0),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final messageData = _messages[index];
        // Ensure currentUserId is not empty before comparing
        final bool isCurrentUserMessage = currentUserId.isNotEmpty && (messageData.user_id.toString() == currentUserId);

        // Adapt ChatMessageData to MessageModel for the bubble widget
        final displayMessage = MessageModel(
          id: messageData.message_id.toString(),
          userId: messageData.user_id.toString(),
          username: isCurrentUserMessage ? "Me" : messageData.username,
          content: messageData.content,
          timestamp: messageData.timestamp,
          isCurrentUser: isCurrentUserMessage,
        );
        return ChatMessageBubble(message: displayMessage);
      },
    );
  }

  // Builds the list of events for the Events tab
  Widget _buildEventsList(bool isDark, String? currentUserId) {
    if (_isLoadingEvents && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isLoadingEvents && _events.isEmpty) {
      return Center(child: Text('No events scheduled for this community.', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)));
    }

    // Sort events by date (newest first for example)
    final sortedEvents = List<EventModel>.from(_events)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Newest first


    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80), // Add padding for FAB
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        // Check if the current user has joined this event
        final bool isJoined = currentUserId != null && event.participants.contains(currentUserId);
        final eventIdInt = int.tryParse(event.id); // Parse ID for comparison
        final bool isSelected = _selectedEventId == eventIdInt;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ChatEventCard(
            event: event,
            isJoined: isJoined,
            isSelected: isSelected, // Pass selection state
            onTap: () => _switchEvent(eventIdInt), // Tap to view event chat
            onJoin: () => _joinOrLeaveEvent(event),
            showJoinButton: true,
          ),
        );
      },
    );
  }

  // Container wrapper for the Selected Event Card to handle padding/margin
  Widget _buildSelectedEventCardContainer(bool isDark, String? currentUserId) {
    if (_selectedEventId == null) return const SizedBox.shrink();

    EventModel? event;
    try {
      event = _events.firstWhere((e) => int.tryParse(e.id) == _selectedEventId);
    } catch (e) {
      print("Selected event ID $_selectedEventId not found in local list for card.");
      // Optionally show a loading/error state for the card
      return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
              color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
              borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
              border: Border.all(color: Colors.orange)
          ),
          child: const Text("Event details not available.", style: TextStyle(color: Colors.orange))
      );
    }

    // Event found
    final bool isJoined = currentUserId != null && event.participants.contains(currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: ChatEventCard(
        event: event,
        isJoined: isJoined,
        isSelected: true, // It's the selected one
        onTap: () { /* Maybe show full event details */ },
        onJoin: () => _joinOrLeaveEvent(event),
        showJoinButton: true,
      ),
    );
  }

} // End of _ChatroomScreenState class