// frontend/lib/presentation/features/chat/screens/chat_list_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_screen.dart';
import '../../../../core/theme/theme_constants.dart';
import '../../../../app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/datasources/remote/community_api.dart';
import '../../../../data/datasources/remote/event_api.dart';
import '../../../../data/datasources/remote/user_api.dart'; // For getFollowing
import '../../../../data/models/event_model.dart'; // For EventModel type hint if needed

// Typedefs (ensure these align with your service class names if they changed)
typedef CommunityApiService = CommunityService;
typedef EventApiService = EventService;
typedef UserApiService = UserService;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  bool _isLoadingCommunityChats = true;
  bool _isLoadingEventChats = true;
  bool _isLoadingDirectMessages = true;

  String? _errorCommunityChats;
  String? _errorEventChats;
  String? _errorDirectMessages;

  List<Map<String, dynamic>> _communityChatRooms = [];
  List<EventModel> _eventChatRooms = []; // Store as EventModel for richer data
  List<Map<String, dynamic>> _directMessageContacts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted && _tabController.indexIsChanging) {
        // Potentially trigger load for the newly selected tab if not already loaded
        _loadDataForCurrentTab();
      } else if (mounted && !_tabController.indexIsChanging) {
        // If the tab selection didn't change (e.g. initial build or re-selected current tab)
        // ensure data for current tab is loaded.
        _loadDataForCurrentTab();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  Future<void> _loadInitialData() async {
    // Load data for the initially selected tab (index 0)
    // and potentially pre-load others or load them on demand.
    _loadDataForCurrentTab();
  }

  Future<void> _loadDataForCurrentTab() async {
    switch (_tabController.index) {
      case 0:
        if (_communityChatRooms.isEmpty || _errorCommunityChats != null)
          _loadCommunityChats();
        break;
      case 1:
        if (_eventChatRooms.isEmpty || _errorEventChats != null)
          _loadEventChats();
        break;
      case 2:
        if (_directMessageContacts.isEmpty || _errorDirectMessages != null)
          _loadDirectMessageContacts();
        break;
    }
  }

  Future<void> _refreshCurrentTabData() async {
    switch (_tabController.index) {
      case 0:
        await _loadCommunityChats(forceRefresh: true);
        break;
      case 1:
        await _loadEventChats(forceRefresh: true);
        break;
      case 2:
        await _loadDirectMessageContacts(forceRefresh: true);
        break;
    }
  }

  Future<void> _loadCommunityChats({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh && _communityChatRooms.isNotEmpty && _errorCommunityChats == null) return;

    setState(() {
      _isLoadingCommunityChats = true;
      _errorCommunityChats = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) {
        setState(() {
          _communityChatRooms = [];
          _isLoadingCommunityChats = false;
          _errorCommunityChats = "Log in to view community chats.";
        });
      }
      return;
    }

    final userService = Provider.of<UserApiService>(context, listen: false);
    try {
      // Assuming getMyJoinedCommunities provides sufficient info for a chat list item
      final rawCommunityData =
      await userService.getMyJoinedCommunities(authProvider.token!);
      if (mounted) {
        setState(() {
          _communityChatRooms = List<Map<String, dynamic>>.from(rawCommunityData
              .map((c) => {
            ...c,
            'last_message_content': 'Join the conversation!', // Placeholder
            'last_message_timestamp': DateTime.now()
                .subtract(Duration(hours: Random().nextInt(24)))
                .toIso8601String(), // Placeholder
            'unread_count': Random().nextInt(3), // Placeholder
          }));
          _isLoadingCommunityChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCommunityChats = false;
          _errorCommunityChats = "Failed to load community chats: $e";
        });
      }
    }
  }

  Future<void> _loadEventChats({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh && _eventChatRooms.isNotEmpty && _errorEventChats == null) return;

    setState(() {
      _isLoadingEventChats = true;
      _errorEventChats = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) {
        setState(() {
          _eventChatRooms = [];
          _isLoadingEventChats = false;
          _errorEventChats = "Log in to view event chats.";
        });
      }
      return;
    }

    final userService = Provider.of<UserApiService>(context, listen: false);
    try {
      // Fetches events the user has joined (participated in)
      final rawEventData =
      await userService.getMyJoinedEvents(authProvider.token!);
      if (mounted) {
        setState(() {
          _eventChatRooms = rawEventData
              .map((data) => EventModel.fromJson(data as Map<String, dynamic>))
              .toList();
          // Augment with placeholder chat data if needed
          _isLoadingEventChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEventChats = false;
          _errorEventChats = "Failed to load event chats: $e";
        });
      }
    }
  }

  Future<void> _loadDirectMessageContacts({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh && _directMessageContacts.isNotEmpty && _errorDirectMessages == null) return;

    setState(() {
      _isLoadingDirectMessages = true;
      _errorDirectMessages = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) {
        setState(() {
          _directMessageContacts = [];
          _isLoadingDirectMessages = false;
          _errorDirectMessages = "Log in to view direct messages.";
        });
      }
      return;
    }

    final userService = Provider.of<UserApiService>(context, listen: false);
    try {
      // Fetch users the current user is following
      final followingList =
      await userService.getFollowing(int.parse(authProvider.userId!), token: authProvider.token);
      if (mounted) {
        setState(() {
          _directMessageContacts = List<Map<String, dynamic>>.from(followingList
              .map((user) => {
            'id': user['id'], // User ID of the followed person
            'name': user['name'] ?? user['username'] ?? 'User',
            'avatar_url': user['image_url'],
            'username': user['username'],
            'last_message_content': 'Tap to chat', // Placeholder
            'last_message_timestamp': DateTime.now()
                .subtract(Duration(days: Random().nextInt(7)))
                .toIso8601String(), // Placeholder
            'unread_count': 0, // Placeholder
          }));
          _isLoadingDirectMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDirectMessages = false;
          _errorDirectMessages = "Failed to load contacts: $e";
        });
      }
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      if (messageDate == today) return DateFormat.jm().format(dateTime);
      else if (today.difference(messageDate).inDays == 1) return 'Yesterday';
      else if (now.difference(messageDate).inDays < 7) return DateFormat.E().format(dateTime);
      else return DateFormat.MMMd().format(dateTime);
    } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        automaticallyImplyLeading: false, // Common for root tab screens
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor:
          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(icon: Icon(Icons.group_work_outlined), text: 'Communities'),
            Tab(icon: Icon(Icons.event_note_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.person_outline), text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(_communityChatRooms, 'community', _isLoadingCommunityChats, _errorCommunityChats, isDark),
          _buildEventList(_eventChatRooms, _isLoadingEventChats, _errorEventChats, isDark),
          _buildChatList(_directMessageContacts, 'dm', _isLoadingDirectMessages, _errorDirectMessages, isDark),
        ],
      ),
    );
  }

  Widget _buildChatList(List<dynamic> rooms, String type, bool isLoading, String? error, bool isDark) {
    if (isLoading) return _buildLoadingShimmer(isDark);
    if (error != null) return _buildErrorView(error, isDark, () => _loadDataForCurrentTab());
    if (rooms.isEmpty) return _buildEmptyView(type, isDark);

    return RefreshIndicator(
      onRefresh: _refreshCurrentTabData,
      child: ListView.separated(
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index] as Map<String, dynamic>;
          final roomId = room['id'] as int? ?? 0;
          final roomName = room['name'] as String? ?? 'Chat Room';
          final avatarUrl = room['avatar_url'] as String?;
          final unreadCount = room['unread_count'] as int? ?? 0;

          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Icon(
                type == 'community' ? Icons.group_work_outlined :
                type == 'dm' ? Icons.person_outline : Icons.help_outline, // Default icon if type is unexpected
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              )
                  : null,
            ),
            title: Text(roomName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                type == 'dm'
                    ? "@${room['username'] ?? 'User'}" // For DMs, show username if available
                    : "${room['last_message_sender'] ?? 'System'}: ${room['last_message_content']}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    type == 'dm' ? '' : _formatTimestamp(room['last_message_timestamp'] as String?),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
                    )),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              if (type == 'dm') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                  dmRecipientUserId: roomId,
                  dmRecipientName: roomName,
                  dmRecipientAvatarUrl: avatarUrl,
                )));
              } else if (type == 'community') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                  communityId: roomId,
                  communityName: roomName,
                )));
              }
              // Event chat navigation already handled in _buildEventList
            },
            contentPadding: const EdgeInsets.symmetric(
                horizontal: ThemeConstants.mediumPadding, vertical: 8),
          );
        },
        separatorBuilder: (context, index) => Divider(
          height: 0.5, indent: 80, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildEventList(List<EventModel> events, bool isLoading, String? error, bool isDark) {
    if (isLoading) return _buildLoadingShimmer(isDark);
    if (error != null) return _buildErrorView(error, isDark, () => _loadDataForCurrentTab());
    if (events.isEmpty) return _buildEmptyView('event', isDark);

    return RefreshIndicator(
      onRefresh: _refreshCurrentTabData,
      child: ListView.separated(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          // Generate placeholder chat data for event list items
          final lastMessageContent = "Event chat active. Tap to join.";
          final lastMessageTimestamp = DateTime.now().subtract(Duration(hours: index + 1)).toIso8601String();

          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              backgroundImage: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(event.imageUrl!)
                  : null,
              child: (event.imageUrl == null || event.imageUrl!.isEmpty)
                  ? Icon(
                Icons.event_note_outlined,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              )
                  : null,
            ),
            title: Text(event.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(lastMessageContent,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(_formatTimestamp(lastMessageTimestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                eventId: int.tryParse(event.id), // Assuming event.id is String, needs parsing
                eventName: event.title,
              )));
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 8),
          );
        },
        separatorBuilder: (context, index) => Divider(
          height: 0.5, indent: 80, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
    );
  }


  Widget _buildLoadingShimmer(bool isDark) {
    /* ... unchanged ... */
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(children: [
            const CircleAvatar(radius: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity,
                          height: 14.0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 6)),
                      Container(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 12.0,
                          color: Colors.white),
                    ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildErrorView(String? error, bool isDark, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text('Failed to Load Chats',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(error ?? "An unknown error occurred.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                    isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: ThemeConstants.largePadding),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(String type, bool isDark) {
    String message;
    IconData icon;
    switch(type) {
      case 'community':
        message = 'Join some communities to start chatting!';
        icon = Icons.add_comment_outlined;
        break;
      case 'event':
        message = 'Join some events to see their chats!';
        icon = Icons.event_busy_outlined;
        break;
      case 'dm':
        message = 'Follow some users to start a conversation!';
        icon = Icons.person_add_alt_1_outlined;
        break;
      default:
        message = 'No messages yet.';
        icon = Icons.chat_bubble_outline_rounded;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                  isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}