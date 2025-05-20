import 'package:flutter/material.dart';
// Provider is not directly used for API calls in this mock version,
// but might be used if chat list becomes dynamic
// import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// --- Screen Import ---
import 'chat_screen.dart'; // Sibling screen

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';
// AppConstants is not directly used in this file now.
// import '../../../../core/constants/app_constants.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _chatRooms = [];

  // Mock data will be replaced by API calls fetching actual user's chat rooms
  final List<Map<String, dynamic>> _mockChatRooms = [
    {
      'id': 'community_1',
      'actual_id': 1,
      'type': 'community',
      'name': 'Flutter Developers Hub',
      'avatar_url':
          'https://yt3.googleusercontent.com/ytc/AIdro_k1G2XMuQ1IcqL4B2qA9g60So8Jg0VIB91c03t21P4=s900-c-k-c0x00ffffff-no-rj',
      'last_message_content': 'Hey, check out the new Dart 3 features!',
      'last_message_sender': 'Alice',
      'last_message_timestamp':
          DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      'unread_count': 3,
    },
    {
      'id': 'event_101',
      'actual_id': 101,
      'type': 'event',
      'name': 'Tech Meetup Q&A Session',
      'avatar_url': null,
      'last_message_content': 'Thanks for joining everyone!',
      'last_message_sender': 'You',
      'last_message_timestamp':
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'unread_count': 0,
    },
    {
      'id': 'community_3',
      'actual_id': 3,
      'type': 'community',
      'name': 'Weekend Gamers',
      'avatar_url':
          'https://cdn.iconscout.com/icon/free/png-256/free-discord-3628366-3030003.png',
      'last_message_content': 'Anyone up for a match tonight?',
      'last_message_sender': 'Bob',
      'last_message_timestamp':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'unread_count': 1,
    },
    {
      'id': 'community_4',
      'actual_id': 4,
      'type': 'community',
      'name': 'Local Book Club',
      'avatar_url': null,
      'last_message_content': 'Next meeting is on Thursday.',
      'last_message_sender': 'Admin',
      'last_message_timestamp': DateTime.now()
          .subtract(const Duration(minutes: 30))
          .toIso8601String(),
      'unread_count': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // TODO: Replace with actual API call to fetch list of chat rooms
    // (e.g., joined communities with recent messages, ongoing event chats)
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        _chatRooms = List.from(_mockChatRooms);
        _chatRooms.sort((a, b) {
          DateTime timeA =
              DateTime.tryParse(a['last_message_timestamp'] ?? '') ??
                  DateTime(0);
          DateTime timeB =
              DateTime.tryParse(b['last_message_timestamp'] ?? '') ??
                  DateTime(0);
          return timeB.compareTo(timeA); // Sort newest first
        });
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String? isoString) {
    // ... (formatting logic unchanged) ...
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (messageDate == today)
        return DateFormat.jm().format(dateTime);
      else if (today.difference(messageDate).inDays == 1)
        return 'Yesterday';
      else if (now.difference(messageDate).inDays < 7)
        return DateFormat.E().format(dateTime);
      else
        return DateFormat.MMMd().format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? _buildLoadingShimmer(isDark)
          : _error != null
              ? _buildErrorView(isDark)
              : _chatRooms.isEmpty
                  ? _buildEmptyView(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadChatRooms,
                      child: ListView.separated(
                        itemCount: _chatRooms.length,
                        itemBuilder: (context, index) {
                          final room = _chatRooms[index];
                          final roomType = room['type'] as String? ?? 'unknown';
                          final actualId = room['actual_id'] as int? ?? 0;
                          final roomName =
                              room['name'] as String? ?? 'Chat Room';
                          final avatarUrl = room['avatar_url'] as String?;
                          final unreadCount = room['unread_count'] as int? ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Icon(
                                      roomType == 'community'
                                          ? Icons.group_work_outlined
                                          : Icons.event_note_outlined,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    )
                                  : null,
                            ),
                            title: Text(roomName,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                "${room['last_message_sender']}: ${room['last_message_content']}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    _formatTimestamp(
                                        room['last_message_timestamp']
                                            as String?),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade700,
                                    )),
                                if (unreadCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    communityId: roomType == 'community'
                                        ? actualId
                                        : null,
                                    eventId:
                                        roomType == 'event' ? actualId : null,
                                    communityName: roomType == 'community'
                                        ? roomName
                                        : null,
                                    eventName:
                                        roomType == 'event' ? roomName : null,
                                  ),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: ThemeConstants.mediumPadding,
                                vertical: 8),
                          );
                        },
                        separatorBuilder: (context, index) => Divider(
                          height: 0.5,
                          indent: 80,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
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

  Widget _buildErrorView(bool isDark) {
    /* ... unchanged, no specific imports needed to fix ... */
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
            Text(_error ?? "An unknown error occurred.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: ThemeConstants.largePadding),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadChatRooms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    /* ... unchanged ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Messages Yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              'Join communities or events to start chatting with others.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
