import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/theme_constants.dart';
import '../models/message_model.dart'; // For ChatMessageBubble widget adaptation
import '../models/event_model.dart';
import '../models/chat_message_data.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_event_card.dart';
import '../widgets/create_event_dialog.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

class ChatroomScreen extends StatefulWidget {
  const ChatroomScreen({Key? key}) : super(key: key);

  @override
  _ChatroomScreenState createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // --- State Variables ---
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDrawerOpen = false;
  late AnimationController _fabAnimationController;

  int? _currentCommunityId; // Start with null, set after fetching
  int? _selectedEventId;

  List<ChatMessageData> _messages = [];
  List<EventModel> _events = [];
  List<Map<String, dynamic>> _userCommunities = []; // Replaces _userCommunities

  bool _isLoadingMessages = true;
  bool _isLoadingEvents = true;
  bool _isLoadingCommunities = true; // Added loading state for communities

  StreamSubscription? _messageSubscription;

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: ThemeConstants.shortAnimation,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData(); // This will now also load communities
        // WebSocket setup will happen after initial community ID is set in _loadInitialData
      }
    });

    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _messageController.dispose();
    _fabAnimationController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    try {
      if (mounted) {
         Provider.of<ApiService>(context, listen: false).disconnectWebSocket();
      }
    } catch (e) {
      print("Error disconnecting WebSocket during dispose: $e");
    }
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
      _setupWebSocket(); // Re-evaluate WebSocket connection
    }
  }


  // --- Data Loading & WebSocket ---
  Future<void> _loadInitialData() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (mounted) setState(() { _isLoadingMessages = false; _isLoadingEvents = false; _isLoadingCommunities = false; _messages = []; _events = []; _userCommunities = []; _currentCommunityId = null; });
      return;
    }

    if (mounted) setState(() { _isLoadingMessages = true; _isLoadingEvents = true; _isLoadingCommunities = true; });
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      // Fetch communities first to determine the default community
      final communitiesData = await apiService.fetchCommunities(authProvider.token);

      if (!mounted) return; // Check again after first await

      final fetchedCommunities = (communitiesData as List).map((c) => Map<String, dynamic>.from(c)).toList();
      int? initialCommunityId = _currentCommunityId; // Keep track if it needs setting

      // Set the current community ID to the first one if not already set or if current doesn't exist anymore
      if (fetchedCommunities.isNotEmpty && (initialCommunityId == null || !fetchedCommunities.any((c) => c['id'] == initialCommunityId))) {
          initialCommunityId = fetchedCommunities.first['id'] as int?;
      } else if (fetchedCommunities.isEmpty) {
          initialCommunityId = null; // No communities, no selection
      }

      setState(() {
          _userCommunities = fetchedCommunities;
          _currentCommunityId = initialCommunityId; // Update the current community ID
          _isLoadingCommunities = false;
      });

      // Now load messages and events for the potentially updated _currentCommunityId
      if (_currentCommunityId != null) {
         // Fetch initial chat messages
         final messagesData = await apiService.fetchChatMessages(
           communityId: _selectedEventId == null ? _currentCommunityId : null,
           eventId: _selectedEventId,
           token: authProvider.token!,
           limit: 50,
         );

         // Fetch events (Replace mock)
         final eventsData = await apiService.fetchCommunityEvents(_currentCommunityId!, authProvider.token!); // Use actual API call

         if (!mounted) return;

         setState(() {
           _messages = (messagesData as List)
               .map((m) => ChatMessageData.fromJson(m))
               .toList()
               .reversed.toList();
           _events = eventsData; // Assuming fetchCommunityEvents returns List<EventModel>
           _isLoadingMessages = false;
           _isLoadingEvents = false;
         });

         WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true));
         _setupWebSocket(); // Setup WebSocket now that we have a community ID

       } else {
          // No communities, so no messages/events to load
           if (mounted) {
              setState(() {
                 _messages = [];
                 _events = [];
                 _isLoadingMessages = false;
                 _isLoadingEvents = false;
              });
           }
           apiService.disconnectWebSocket(); // Ensure WS is disconnected
       }

    } catch (e) {
      if (!mounted) return;
      print('Error loading initial data: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      setState(() { _isLoadingMessages = false; _isLoadingEvents = false; _isLoadingCommunities = false; });
    }
  }

  void _setupWebSocket() {
    if (!mounted) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _messageSubscription?.cancel();
    apiService.disconnectWebSocket();

    if (!authProvider.isAuthenticated || _currentCommunityId == null) {
      print("WebSocket setup skipped: Not authenticated or no community selected.");
      return;
    }

    String roomType;
    int roomId;

    if (_selectedEventId != null) {
      roomType = "event";
      roomId = _selectedEventId!;
    } else if (_tabController.index == 0) {
      roomType = "community";
      roomId = _currentCommunityId!;
    } else {
      print("WebSocket setup skipped: On Events tab without a selected event.");
      return;
    }

    print("Setting up WebSocket for $roomType $roomId");
    apiService.connectWebSocket(roomType, roomId, authProvider.token);

    _messageSubscription = apiService.messages.listen(
      (chatMessage) {
        if (!mounted) return;
        setState(() {
          int optimisticIndex = _messages.indexWhere((m) => m.message_id < 0);
          bool replacedOptimistic = false;
          if (optimisticIndex != -1) {
            if (_messages[optimisticIndex].content == chatMessage.content && _messages[optimisticIndex].user_id == chatMessage.user_id) {
              _messages[optimisticIndex] = chatMessage;
              replacedOptimistic = true;
            }
          }
          if (!replacedOptimistic && !_messages.any((m) => m.message_id == chatMessage.message_id && chatMessage.message_id > 0)) {
            _messages.add(chatMessage);
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        print("Error on message stream: $error");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat connection error: $error'), backgroundColor: Colors.red));
      }
    );
  }

  // --- UI Actions ---

  void _toggleDrawer() {
    if (mounted) setState(() { _isDrawerOpen = !_isDrawerOpen; });
  }

  void _switchCommunity(int id) {
    if (_currentCommunityId == id && mounted) {
      setState(() => _isDrawerOpen = false);
      return;
    }
    if (mounted) {
      setState(() {
        _currentCommunityId = id;
        _selectedEventId = null;
        _isDrawerOpen = false;
        _messages = [];
        _events = [];
        _isLoadingMessages = true;
        _isLoadingEvents = true; // Also reset event loading state
      });
      _loadInitialData(); // Reload everything for the new community
      // _setupWebSocket() will be called by _loadInitialData if successful
    }
  }

  void _switchEvent(int? eventId) {
    if (_selectedEventId == eventId || !mounted) return;
    setState(() {
      _selectedEventId = eventId;
      _messages = [];
      _isLoadingMessages = true;
    });
    _loadInitialData(); // Reload messages for the event/community
    _setupWebSocket(); // Connect to the specific event/community room
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to send messages')));
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final tempId = -(DateTime.now().millisecondsSinceEpoch);

    final optimisticMessage = ChatMessageData(
      message_id: tempId,
      community_id: _selectedEventId == null ? _currentCommunityId : null,
      event_id: _selectedEventId,
      user_id: int.parse(authProvider.userId!),
      username: "Me",
      content: messageText,
      timestamp: DateTime.now().toUtc(),
    );

     if (mounted) {
       setState(() {
         _messages.add(optimisticMessage);
         _messageController.clear();
       });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
     }

    // Send via WebSocket
    final messagePayload = jsonEncode({"content": messageText});
    apiService.sendWebSocketMessage(messagePayload);
    print("Optimistic message added (ID: $tempId), sent via WebSocket.");
  }

  void _showFabMenu() {
     if (!mounted) return;
    if (_fabAnimationController.status == AnimationStatus.completed) {
      _fabAnimationController.reverse();
    } else {
      _fabAnimationController.forward();
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
        communityId: _currentCommunityId!.toString(),
        onSubmit: _createEvent,
      ),
    );
    _fabAnimationController.reverse();
  }

  Future<void> _createEvent(String title, String description, String location, DateTime dateTime, int maxParticipants) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
     if (_currentCommunityId == null || !mounted) return;

    setState(() => _isLoadingEvents = true); // Indicate loading for event creation

    try {
      // Replace with actual API call
      final newEvent = await apiService.createEvent(
        _currentCommunityId!, title, description, location, dateTime, maxParticipants, authProvider.token!,
      );

      if (!mounted) return;

      setState(() {
        _events.add(newEvent);
        _isLoadingEvents = false;
        _tabController.animateTo(1); // Switch to Events tab
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event "${newEvent.title}" created successfully')));

    } catch (e) {
      if (!mounted) return;
      print('Error creating event: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create event. Please try again.')));
       setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _joinEvent(EventModel event) async {
     final authProvider = Provider.of<AuthProvider>(context, listen: false);
     if (!authProvider.isAuthenticated || authProvider.userId == null || !mounted) return;
     final apiService = Provider.of<ApiService>(context, listen: false);

     final initialParticipants = List<String>.from(event.participants);
     final isJoining = !initialParticipants.contains(authProvider.userId!);

     // Optimistic UI update
     if (mounted) {
         setState(() {
           final index = _events.indexWhere((e) => e.id == event.id);
           if (index != -1) {
              final updatedParticipants = isJoining
                  ? [...initialParticipants, authProvider.userId!]
                  : initialParticipants.where((id) => id != authProvider.userId!).toList();
              _events[index] = EventModel(
                 id: event.id, title: event.title, description: event.description, location: event.location,
                 dateTime: event.dateTime, maxParticipants: event.maxParticipants, creatorId: event.creatorId,
                 communityId: event.communityId, imageUrl: event.imageUrl,
                 participants: updatedParticipants,
              );
           }
         });
     }

     try {
       // Replace with actual API call
       await apiService.joinEvent(event.id, authProvider.token!);
       // await apiService.joinOrLeaveEvent(event.id, isJoining, authProvider.token!); // Use if single endpoint exists

       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have ${isJoining ? 'joined' : 'left'} "${event.title}"')));
     } catch (e) {
       if (!mounted) return;
       print('Error joining/leaving event: $e');
       // Revert optimistic update
       setState(() {
          final index = _events.indexWhere((e) => e.id == event.id);
          if (index != -1) {
             _events[index] = EventModel(
                  id: event.id, title: event.title, description: event.description, location: event.location,
                  dateTime: event.dateTime, maxParticipants: event.maxParticipants, creatorId: event.creatorId,
                  communityId: event.communityId, imageUrl: event.imageUrl,
                 participants: initialParticipants,
             );
          }
       });
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to ${isJoining ? 'join' : 'leave'} event. Please try again.')));
     }
  }

   String _getCurrentCommunityName() {
     // Find name from the fetched list
     if (_currentCommunityId == null) return "Chat";
     final community = _userCommunities.firstWhere(
       (c) => c['id'] == _currentCommunityId,
       orElse: () => {'name': 'Chat'}, // Default name
     );
     return community['name'] as String? ?? 'Chat';
   }

  String? _getCurrentEventTitle() {
    if (_selectedEventId == null) return null;
    try {
      final event = _events.firstWhere((e) => int.tryParse(e.id) == _selectedEventId);
      return event.title;
    } catch (e) {
      return "Event";
    }
  }

  void _scrollToBottom([bool jump = false]) {
     if (!_scrollController.hasClients) return;
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.position.pixels;
            if (jump || maxScroll - currentScroll < 150) { // Increased threshold
                if (jump) {
                   _scrollController.jumpTo(maxScroll);
                } else {
                   _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
            }
        }
     });
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    final String currentTitle = _selectedEventId != null
        ? (_getCurrentEventTitle() ?? "Event")
        : _getCurrentCommunityName();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_selectedEventId != null)
              Text('Event Chat', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.white70)),
          ],
        ),
        leading: IconButton(icon: Icon(_isDrawerOpen ? Icons.close : Icons.menu), onPressed: _toggleDrawer),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chat'), Tab(text: 'Events')],
          indicatorColor: ThemeConstants.highlightColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) => _handleTabChange(),
        ),
        actions: [
          if (_selectedEventId != null) IconButton(icon: const Icon(Icons.event_note), onPressed: () {}),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: !authProvider.isAuthenticated
          ? _buildNotLoggedInView(isDark)
          : Stack(
              children: [
                Column(
                  children: [
                    // Event Chips
                    if (_tabController.index == 1 && _events.isNotEmpty)
                      _buildEventChips(isDark),

                    // Selected Event Card
                    if (_selectedEventId != null && _tabController.index == 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildSelectedEventCard(isDark),
                      ),

                    // Main List Area
                    Expanded(
                      child: (_tabController.index == 0 || _selectedEventId != null)
                          ? _buildMessagesList(isDark, authProvider.userId ?? '')
                          : _buildEventsList(isDark),
                    ),

                    // Message Input Area
                    if (_tabController.index == 0 || _selectedEventId != null)
                      _buildMessageInput(isDark),
                  ],
                ),
                // Drawer
                _buildDrawer(isDark, size),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? _buildFloatingActionButton()
          : null,
    );
  }


  // --- Helper Build Methods ---

  Widget _buildEventChips(bool isDark) {
    if (_isLoadingEvents) {
      return Container(height: 60, alignment: Alignment.center, child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
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
               label: Text(event.title),
               selected: isSelected,
               onSelected: (selected) => _switchEvent(selected ? eventIdInt : null),
               backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
               selectedColor: ThemeConstants.accentColor,
               labelStyle: TextStyle(
                 color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87),
                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
               ),
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             ),
           );
         },
       ),
     );
   }

  Widget _buildDrawer(bool isDark, Size size) {
     return Stack( // Use Stack to position overlay and drawer
         children: [
            if (_isDrawerOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleDrawer,
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
            AnimatedPositioned(
               duration: ThemeConstants.mediumAnimation,
               curve: Curves.easeInOut,
               left: _isDrawerOpen ? 0 : -size.width * 0.75, // Adjust width if needed
               top: 0, bottom: 0, width: size.width * 0.75,
               child: Material( // Use Material for elevation/shadow
                  elevation: 16.0,
                  child: Container(
                    color: isDark ? ThemeConstants.backgroundDark : Colors.white,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                            child: Row(
                              children: [
                                Text('My Communities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                                const Spacer(),
                                IconButton(icon: const Icon(Icons.add_circle_outline), color: ThemeConstants.accentColor, onPressed: () {}),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _userCommunities.length,
                              itemBuilder: (context, index) {
                                final community = _userCommunities[index];
                                final communityIdInt = community['id'] as int;
                                final isSelected = _currentCommunityId == communityIdInt;
                                return ListTile(
                                   leading: CircleAvatar(
                                      backgroundColor: isSelected ? ThemeConstants.accentColor : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                                      child: Text((community['name'] as String)[0], style: TextStyle(color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold)),
                                   ),
                                   title: Text(community['name'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black87)),
                                   trailing: (community['unread'] as int? ?? 0) > 0
                                       ? Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(color: ThemeConstants.errorColor, shape: BoxShape.circle),
                                            child: Text((community['unread'] as int).toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                         )
                                       : null,
                                   selected: isSelected,
                                   selectedTileColor: isDark ? ThemeConstants.backgroundDarker.withOpacity(0.5) : Colors.grey.shade100,
                                   onTap: () => _switchCommunity(communityIdInt),
                                );
                              },
                            ),
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

  Widget _buildFloatingActionButton() {
     return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         ScaleTransition(
           scale: CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
           child: Padding(
             padding: const EdgeInsets.only(bottom: 8.0),
             child: FloatingActionButton.small(
               heroTag: 'event_fab',
               onPressed: _showCreateEventDialog,
               backgroundColor: ThemeConstants.accentColor,
               child: const Icon(Icons.event, color: ThemeConstants.primaryColor),
               tooltip: 'Create Event',
             ),
           ),
         ),
         FloatingActionButton(
           heroTag: 'main_fab',
           onPressed: _showFabMenu,
           backgroundColor: ThemeConstants.accentColor,
           child: AnimatedRotation(
             turns: _fabAnimationController.value * 0.125, // Rotate 45 degrees
             duration: ThemeConstants.shortAnimation,
             child: const Icon(Icons.add, color: ThemeConstants.primaryColor),
           ),
           tooltip: 'More Actions',
         ),
       ],
     );
   }

   Widget _buildMessageInput(bool isDark) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
       decoration: BoxDecoration(
         color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]
       ),
       child: SafeArea( // Ensure input is above system intrusions (like home bar)
         child: Row(
           children: [
             IconButton(icon: const Icon(Icons.add_photo_alternate), color: ThemeConstants.accentColor, onPressed: () {}),
             IconButton(icon: const Icon(Icons.emoji_emotions_outlined), color: ThemeConstants.accentColor, onPressed: () {}),
             Expanded(
               child: TextField(
                 controller: _messageController,
                 decoration: InputDecoration(
                   hintText: 'Type a message...',
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                   filled: true,
                   fillColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Adjust padding
                 ),
                 minLines: 1,
                 maxLines: 5, // Allow multi-line input
                 textCapitalization: TextCapitalization.sentences,
                 onSubmitted: (_) => _sendMessage(),
               ),
             ),
             const SizedBox(width: 8),
             CircleAvatar(
               radius: 22, // Slightly larger tap target
               backgroundColor: ThemeConstants.accentColor,
               child: IconButton(
                 icon: const Icon(Icons.send),
                 color: ThemeConstants.primaryColor,
                 onPressed: _sendMessage,
               ),
             ),
           ],
         ),
       ),
     );
   }

  Widget _buildNotLoggedInView(bool isDark) {
    // Copied from original, ensure it returns a Widget
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
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: ThemeConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark, String currentUserId) {
    if (_isLoadingMessages && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isLoadingMessages && _messages.isEmpty) {
      return Center(child: Text('No messages yet. Start the conversation!', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final messageData = _messages[index];
        final isCurrentUser = messageData.user_id.toString() == currentUserId;
        final displayMessage = MessageModel(
          id: messageData.message_id.toString(),
          userId: messageData.user_id.toString(),
          username: isCurrentUser ? "Me" : messageData.username,
          content: messageData.content,
          timestamp: messageData.timestamp,
          isCurrentUser: isCurrentUser,
        );
        return ChatMessageBubble(message: displayMessage);
      },
    );
  }

  Widget _buildEventsList(bool isDark) {
    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return Center(child: Text('No events found for this community.', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isJoined = event.participants.contains(authProvider.userId);
        return ChatEventCard(
          event: event,
          isJoined: isJoined,
          onTap: () => _switchEvent(int.tryParse(event.id)),
          onJoin: () => _joinEvent(event),
          showJoinButton: true,
        );
      },
    );
  }

  Widget _buildSelectedEventCard(bool isDark) {
    if (_selectedEventId == null) return const SizedBox.shrink();
    final event = _events.firstWhere(
      (e) => int.tryParse(e.id) == _selectedEventId,
      orElse: () => EventModelMock.mockEventPlaceholder(),
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isJoined = event.participants.contains(authProvider.userId);

    return ChatEventCard(
      event: event,
      isJoined: isJoined,
      onTap: () { /* Show details maybe */ },
      onJoin: () => _joinEvent(event),
      showJoinButton: true, // Keep join button visible here too
    );
  }
}

// Defined extension outside the State class
extension EventModelMock on EventModel {
  static EventModel mockEventPlaceholder() => EventModel(
    id: '0', title: 'Event not found', description: '', location: '',
    dateTime: DateTime.now(), maxParticipants: 0, participants: [],
    creatorId: '', communityId: '',
  );
}