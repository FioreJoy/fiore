// frontend/lib/screens/replies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// --- Service Imports ---
import '../services/auth_provider.dart';
import '../services/api/reply_service.dart';
import '../services/api/vote_service.dart';

// --- Widget and Screen Imports ---
import '../widgets/reply_card.dart';
import 'create/create_reply_screen.dart'; // Adjusted path
import '../theme/theme_constants.dart';

// Helper data structure
class ReplyNode {
  final Map<String, dynamic> data;
  final List<ReplyNode> children;
  bool isExpanded;

  // <<< FIX: Use named parameters >>>
  ReplyNode({
    required this.data,
    this.children = const [],
    this.isExpanded = true
  });
}

class RepliesScreen extends StatefulWidget {
  final int postId; // Assuming int ID
  final String? postTitle;

  const RepliesScreen({
    required this.postId,
    this.postTitle,
    super.key
  });

  @override
  _RepliesScreenState createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> {

  Future<List<ReplyNode>>? _loadRepliesFuture;
  final Map<String, Map<String, dynamic>> _replyVoteData = {}; // Key is String ID

  @override
  void initState() {
    super.initState();
    _triggerLoadReplies();
  }

  void _triggerLoadReplies() {
    if (!mounted) return;
    final replyService = Provider.of<ReplyService>(context, listen: false);
    setState(() {
      _loadRepliesFuture = _fetchAndStructureReplies(replyService);
    });
  }

  Future<List<ReplyNode>> _fetchAndStructureReplies(ReplyService replyService) async {
    // <<< FIX: Use correct method name if different, e.g., getRepliesForPost >>>
    // Assuming the method is fetchReplies for now
    final List<dynamic> flatRepliesDyn = await replyService.getRepliesForPost(widget.postId);
    // Ensure data is List<Map<String, dynamic>>
    final List<Map<String, dynamic>> flatReplies = List<Map<String, dynamic>>.from(flatRepliesDyn);


    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bool needsUiUpdate = false;
        for (var reply in flatReplies) {
          final replyIdStr = reply['id']?.toString() ?? '0'; // Safe access and convert to string
          final currentUpvotes = reply['upvotes'] as int? ?? 0;
          final currentDownvotes = reply['downvotes'] as int? ?? 0;

          if (!_replyVoteData.containsKey(replyIdStr)) {
            _replyVoteData[replyIdStr] = { 'vote_type': null, 'upvotes': currentUpvotes, 'downvotes': currentDownvotes, };
            needsUiUpdate = true;
          } else {
            if (_replyVoteData[replyIdStr]!['upvotes'] != currentUpvotes || _replyVoteData[replyIdStr]!['downvotes'] != currentDownvotes) {
              _replyVoteData[replyIdStr]!['upvotes'] = currentUpvotes;
              _replyVoteData[replyIdStr]!['downvotes'] = currentDownvotes;
              needsUiUpdate = true;
            }
          }
        }
        if (needsUiUpdate && mounted) { setState(() {}); }
      });
    }

    final Map<int?, List<Map<String, dynamic>>> repliesByParentId = {};
    for (var reply in flatReplies) {
      final parentId = reply['parent_reply_id'] as int?;
      repliesByParentId.putIfAbsent(parentId, () => []).add(reply);
    }

    List<ReplyNode> buildTree(int? parentId) {
      if (!repliesByParentId.containsKey(parentId)) return [];
      // Sort replies by date
      repliesByParentId[parentId]!.sort((a, b) {
        DateTime timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        DateTime timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return timeA.compareTo(timeB); // Ascending
      });
      return repliesByParentId[parentId]!.map((replyData) {
        final children = buildTree(replyData['id'] as int?);
        // <<< FIX: Use named constructor >>>
        return ReplyNode(data: replyData, children: children);
      }).toList();
    }

    return buildTree(null); // Start from top-level replies (parentId is null)
  }


  void _navigateToAddReply(BuildContext context, {int? parentReplyId, String? parentContent}) {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) { /* show message */ return; }

    Navigator.push( context,
      MaterialPageRoute(
        // <<< FIX: Ensure class name matches >>>
          builder: (context) => CreateReplyScreen(
            postId: widget.postId,
            parentReplyId: parentReplyId,
            parentReplyContent: parentContent,
          )),
    ).then((_) => _triggerLoadReplies());
  }

  Future<void> _deleteReply(int replyId) async {
    if (!mounted) return;
    final replyService = Provider.of<ReplyService>(context, listen: false);

    // <<< FIX: Pass context and builder to showDialog >>>
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Reply?'),
          content: const Text('Are you sure you want to delete this reply?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor))),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // <<< FIX: Call deleteReply with NAMED parameter >>>
        // Assuming definition is deleteReply({required int replyId})
        await replyService.deleteReply(replyId: replyId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply deleted'), duration: Duration(seconds: 1)));
        _triggerLoadReplies();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting reply: ${e.toString()}'), backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  Future<void> _voteOnReply(int replyId, bool voteType) async {
    if (!mounted) return;
    final voteService = Provider.of<VoteService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) { /* show message */ return; }

    final replyIdStr = replyId.toString();
    final currentVoteData = _replyVoteData[replyIdStr] ?? {'vote_type': null, 'upvotes': 0, 'downvotes': 0};
    final previousVoteType = currentVoteData['vote_type'] as bool?;
    final currentUpvotes = currentVoteData['upvotes'] as int? ?? 0;
    final currentDownvotes = currentVoteData['downvotes'] as int? ?? 0;

    // Optimistic UI Update
    setState(() { /* ... optimistic update using replyIdStr key ... */ });

    try {
      // <<< FIX: Use named parameters for castVote >>>
      await voteService.castVote(
        replyId: replyId, // Pass int replyId
        voteType: voteType,
        // postId is null here
      );
    } catch (e) {
      if (!mounted) return;
      // Revert UI
      setState(() { _replyVoteData[replyIdStr] = currentVoteData; }); // Use string key
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: ${e.toString()}'), backgroundColor: ThemeConstants.errorColor));
    }
  }

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d').format(dateTime); // Just the date for older ones
    } catch (e) {
      return ''; // Return empty string on parse error
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final int? currentUserId = authProvider.userId; // Get int?

    return Scaffold(
      appBar: AppBar(title: Text(widget.postTitle ?? "Replies")),
      body: RefreshIndicator(
        onRefresh: () async => _triggerLoadReplies(),
        child: FutureBuilder<List<ReplyNode>>(
          future: _loadRepliesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading replies: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.comment_outlined, size: 50, color: Colors.grey), const SizedBox(height: 16), const Text('No replies yet.'), const SizedBox(height: 8), TextButton( onPressed: () => _navigateToAddReply(context), child: const Text('Be the first to reply!'), ), ], ) );
            }

            final structuredReplies = snapshot.data!;

            // Function to recursively build the list view items
            List<Widget> buildReplyWidgets(List<ReplyNode> nodes, int level) {
              List<Widget> widgets = [];
              for (var node in nodes) {
                // <<< FIX: Access node.data >>>
                final reply = node.data;
                final int replyId = reply['id'] as int? ?? 0;
                final String replyIdStr = replyId.toString();
                final int? replyUserId = reply['user_id'] as int?;
                final isOwner = authProvider.isAuthenticated && currentUserId != null && replyUserId == currentUserId;

                final voteData = _replyVoteData[replyIdStr] ?? {'vote_type': null, 'upvotes': reply['upvotes'] ?? 0, 'downvotes': reply['downvotes'] ?? 0};
                final bool hasUpvoted = voteData['vote_type'] == true;
                final bool hasDownvoted = voteData['vote_type'] == false;
                final int displayUpvotes = voteData['upvotes'] ?? 0;
                final int displayDownvotes = voteData['downvotes'] ?? 0;

                widgets.add(
                  Padding(
                    padding: EdgeInsets.only(left: level * 0.0, bottom: level > 0 ? 2 : 8.0, top: level > 0 ? 2 : 0), // Indentation removed for simplicity, add back if needed: left: level * 16.0
                    child: ReplyCard(
                      // Pass data from the 'reply' map
                      content: reply['content'] ?? '...',
                      authorName: reply['author_name'] ?? 'Anonymous',
                      authorAvatar: reply['author_avatar'], // Pass avatar URL/path if available
                      timeAgo: _formatTimeAgo(reply['created_at']),
                      upvotes: displayUpvotes,
                      downvotes: displayDownvotes,
                      isOwner: isOwner,
                      hasUpvoted: hasUpvoted,
                      hasDownvoted: hasDownvoted,
                      indentLevel: level,
                      onReply: () => _navigateToAddReply( context, parentReplyId: replyId, parentContent: reply['content'], ), // Pass int ID
                      onDelete: isOwner ? () => _deleteReply(replyId) : null, // Pass int ID
                      onUpvote: () => _voteOnReply(replyId, true), // Pass int ID
                      onDownvote: () => _voteOnReply(replyId, false), // Pass int ID
                    ),
                  ),
                );
                // <<< FIX: Access node.children >>>
                widgets.addAll(buildReplyWidgets(node.children, level + 1));
              }
              return widgets;
            }

            return ListView(
              padding: const EdgeInsets.all(8),
              children: buildReplyWidgets(structuredReplies, 0),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddReply(context),
        tooltip: "Add Reply",
        backgroundColor: ThemeConstants.accentColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}