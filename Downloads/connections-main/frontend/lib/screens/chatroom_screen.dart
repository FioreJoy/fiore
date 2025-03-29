import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/theme_constants.dart';
import '../models/message_model.dart';
import '../models/event_model.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_event_card.dart';
import '../widgets/create_event_dialog.dart';
import 'dart:math' as math;

class ChatroomScreen extends StatefulWidget {
  const ChatroomScreen({Key? key}) : super(key: key);

  @override
  _ChatroomScreenState createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Tab controller for toggling between "All" and "Events"
  late TabController _tabController;

  // Current community ID
  String? _currentCommunityId;

  // Selected event ID (if any)
  String? _selectedEventId;

  // Message input controller
  final TextEditingController _messageController = TextEditingController();

  // Community selection drawer open state
  bool _isDrawerOpen = false;

  // Animation controllers
  late AnimationController _fabAnimationController;

  // Messages and events data
  List<MessageModel> _messages = [];
  List<EventModel> _events = [];
  bool _isLoadingMessages = false;
  bool _isLoadingEvents = false;

  // Mock communities data
  final List<Map<String, dynamic>> _mockCommunities = [
    {'id': '1', 'name': 'Tech Enthusiasts', 'unread': 5},
    {'id': '2', 'name': 'Fitness Freaks', 'unread': 0},
    {'id': '3', 'name': 'Music Lovers', 'unread': 2},
    {'id': '4', 'name': 'Book Club', 'unread': 0},
    {'id': '5', 'name': 'Foodies', 'unread': 1},
    {'id': '6', 'name': 'Travelers', 'unread': 0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: ThemeConstants.shortAnimation,
    );

    // Set default community
    _currentCommunityId = _mockCommunities.first['id'] as String;

    // Load initial data
    _loadData();

    // Listen for tab changes
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_currentCommunityId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;

    setState(() {
      _isLoadingMessages = true;
      _isLoadingEvents = true;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      // Load messages
      final messages = await apiService.fetchMessages(
        _currentCommunityId!,
        _selectedEventId,
        authProvider.token!,
      );

      // Load events if on events tab or if we have a selected event
      final events = await apiService.fetchEvents(
        _currentCommunityId!,
        authProvider.token!,
      );

      setState(() {
        _messages = messages;
        _events = events;
        _isLoadingMessages = false;
        _isLoadingEvents = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoadingMessages = false;
        _isLoadingEvents = false;
      });
    }
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
    });
  }

  void _switchCommunity(String id) {
    setState(() {
      _currentCommunityId = id;
      _selectedEventId = null;
      _isDrawerOpen = false;
    });
    _loadData();
  }

  void _switchEvent(String? eventId) {
    setState(() {
      _selectedEventId = eventId;
    });
    _loadData();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages')),
      );
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    // Optimistically add message to UI
    final newMessage = MessageModel(
      id: (math.Random().nextInt(1000) + 100).toString(),
      userId: authProvider.userId ?? '102',
      username: authProvider.name ?? 'Current User',
      content: _messageController.text,
      timestamp: DateTime.now(),
      isCurrentUser: true,
    );

    setState(() {
      _messages.insert(0, newMessage); // Add to beginning since list is reversed
      _messageController.clear();
    });

    try {
      // Send message to API
      await apiService.sendMessage(
        _currentCommunityId!,
        _selectedEventId,
        newMessage.content,
        authProvider.token!,
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );

      // Remove message from UI if failed
      setState(() {
        _messages.removeWhere((msg) => msg.id == newMessage.id);
      });
    }
  }

  void _showFabMenu() {
    if (_fabAnimationController.status == AnimationStatus.completed) {
      _fabAnimationController.reverse();
    } else {
      _fabAnimationController.forward();
    }
  }

  void _showCreateEventDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create events')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateEventDialog(
        communityId: _currentCommunityId!,
        onSubmit: _createEvent,
      ),
    );

    // Close FAB menu
    _fabAnimationController.reverse();
  }

  Future<void> _createEvent(
    String title,
    String description,
    String location,
    DateTime dateTime,
    int maxParticipants,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final newEvent = await apiService.createEvent(
        _currentCommunityId!,
        title,
        description,
        location,
        dateTime,
        maxParticipants,
        authProvider.token!,
      );

      setState(() {
        _events.add(newEvent);
        _selectedEventId = newEvent.id;
        _tabController.animateTo(1); // Switch to Events tab
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "${newEvent.title}" created successfully')),
      );

      // Reload messages for the new event
      _loadData();
    } catch (e) {
      print('Error creating event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create event. Please try again.')),
      );
    }
  }

  Future<void> _joinEvent(EventModel event) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join events')),
      );
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.joinEvent(event.id, authProvider.token!);

      // Optimistically update UI
      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          final updatedEvent = EventModel(
            id: event.id,
            title: event.title,
            description: event.description,
            location: event.location,
            dateTime: event.dateTime,
            maxParticipants: event.maxParticipants,
            participants: [...event.participants, authProvider.userId!],
            creatorId: event.creatorId,
            communityId: event.communityId,
            imageUrl: event.imageUrl,
          );
          _events[index] = updatedEvent;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have joined "${event.title}"')),
      );
    } catch (e) {
      print('Error joining event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join event. Please try again.')),
      );
    }
  }

  String _getCurrentCommunityName() {
    final community = _mockCommunities.firstWhere(
      (c) => c['id'] == _currentCommunityId,
      orElse: () => {'name': 'Unknown Community'} as Map<String, dynamic>,
    );
    return community['name'] as String;
  }

  String? _getCurrentEventTitle() {
    if (_selectedEventId == null) return null;

    final event = _events.firstWhere(
      (e) => e.id == _selectedEventId,
      orElse: () => EventModel(
        id: '0',
        title: 'Unknown Event',
        description: '',
        location: '',
        dateTime: DateTime.now(),
        maxParticipants: 0,
        participants: [],
        creatorId: '',
        communityId: '',
      ),
    );
    return event.title;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    // Get events for current community
    final communityEvents = _events.where((e) => e.communityId == _currentCommunityId).toList();

    // Current title to display
    final String title = _selectedEventId != null
        ? _getCurrentEventTitle()!
        : _getCurrentCommunityName();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (_selectedEventId != null) ...[
              Text(
                'Event Chat',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.white70,
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: Icon(_isDrawerOpen ? Icons.close : Icons.menu),
          onPressed: _toggleDrawer,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Events'),
          ],
          indicatorColor: ThemeConstants.highlightColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) {
            setState(() {}); // Refresh UI when tab changes
          },
        ),
        actions: [
          if (_selectedEventId != null)
            IconButton(
              icon: const Icon(Icons.event_note),
              onPressed: () {
                // Show event details
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show community or event info
            },
          ),
        ],
      ),
      body: !authProvider.isAuthenticated ? _buildNotLoggedInView(isDark) : Stack(
        children: [
          // Main Chat Content
          Column(
            children: [
              // Event chips (if on Events tab)
              if (_tabController.index == 1 && communityEvents.isNotEmpty)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding),
                    itemCount: communityEvents.length,
                    itemBuilder: (context, index) {
                      final event = communityEvents[index];
                      final isSelected = _selectedEventId == event.id;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(event.title),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedEventId = selected ? event.id : null;
                            });
                            _loadData();
                          },
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
                ),

              // Event details card if selected
              if (_selectedEventId != null && _tabController.index == 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildSelectedEventCard(isDark),
                ),
              ],

              // Messages List or Events List
              Expanded(
                child: _tabController.index == 0
                    ? _buildMessagesList(isDark)
                    : _buildEventsList(isDark, communityEvents),
              ),

              // Message Input (only show in chat tab or if event is selected)
              if (_tabController.index == 0 || _selectedEventId != null)
                Container(
                  padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                  color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_photo_alternate),
                        color: ThemeConstants.accentColor,
                        onPressed: () {
                          // Add photo
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        color: ThemeConstants.accentColor,
                        onPressed: () {
                          // Show emoji picker
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
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
            ],
          ),

          // Community Drawer (Left Side)
          if (_isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleDrawer, // Close when tapping outside
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: ThemeConstants.mediumAnimation,
            left: _isDrawerOpen ? 0 : -size.width * 0.7,
            top: 0,
            bottom: 0,
            width: size.width * 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? ThemeConstants.backgroundDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                      child: Row(
                        children: [
                          Text(
                            'My Communities',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: ThemeConstants.accentColor,
                            onPressed: () {
                              // Join new community
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _mockCommunities.length,
                        itemBuilder: (context, index) {
                          final community = _mockCommunities[index];
                          final isSelected = _currentCommunityId == community['id'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? ThemeConstants.accentColor
                                  : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                              child: Text(
                                (community['name'] as String)[0],
                                style: TextStyle(
                                  color: isSelected
                                      ? ThemeConstants.primaryColor
                                      : (isDark ? Colors.white : Colors.black87),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              community['name'] as String,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: (community['unread'] as int) > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: ThemeConstants.errorColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      (community['unread'] as int).toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                            selected: isSelected,
                            selectedTileColor: isDark
                                ? ThemeConstants.backgroundDarker.withOpacity(0.5)
                                : Colors.grey.shade100,
                            onTap: () => _switchCommunity(community['id'] as String),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1 ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // New Event FAB option (shown when menu is open)
          ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _fabAnimationController,
                curve: Curves.easeOut,
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: 'event_fab',
                onPressed: _showCreateEventDialog,
                backgroundColor: ThemeConstants.accentColor,
                child: const Icon(Icons.event, color: ThemeConstants.primaryColor),
              ),
            ),
          ),

          // Main FAB that toggles the menu
          FloatingActionButton(
            heroTag: 'main_fab',
            onPressed: _showFabMenu,
            backgroundColor: ThemeConstants.accentColor,
            child: AnimatedRotation(
              turns: _fabAnimationController.value * 0.125,
              duration: ThemeConstants.shortAnimation,
              child: const Icon(Icons.add, color: ThemeConstants.primaryColor),
            ),
          ),
        ],
      ) : null,
    );
  }

  Widget _buildNotLoggedInView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'Please log in to access chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with communities and events',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to login
              Navigator.of(context).pushReplacementNamed('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.accentColor,
              foregroundColor: ThemeConstants.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    if (_isLoadingMessages) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      reverse: true, // Display latest messages at the bottom
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return ChatMessageBubble(
          message: message,
          onLongPress: () {
            // Show reaction menu
          },
        );
      },
    );
  }

  Widget _buildEventsList(bool isDark, List<EventModel> events) {
    if (_isLoadingEvents) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an event to get started',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateEventDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConstants.accentColor,
                foregroundColor: ThemeConstants.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedEventId != null) {
      return _buildMessagesList(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final authProvider = Provider.of<AuthProvider>(context);
        final isJoined = event.participants.contains(authProvider.userId);

        return ChatEventCard(
          event: event,
          isJoined: isJoined,
          onTap: () => _switchEvent(event.id),
          onJoin: () => _joinEvent(event),
        );
      },
    );
  }

  Widget _buildSelectedEventCard(bool isDark) {
    if (_selectedEventId == null) return const SizedBox.shrink();

    final event = _events.firstWhere(
      (e) => e.id == _selectedEventId,
      orElse: () => EventModel(
        id: '0',
        title: 'Unknown Event',
        description: '',
        location: '',
        dateTime: DateTime.now(),
        maxParticipants: 0,
        participants: [],
        creatorId: '',
        communityId: '',
      ),
    );

    final authProvider = Provider.of<AuthProvider>(context);
    final isJoined = event.participants.contains(authProvider.userId);

    return ChatEventCard(
      event: event,
      isJoined: isJoined,
      onTap: () {},
      onJoin: () => _joinEvent(event),
      showJoinButton: false,
    );
  }
}
