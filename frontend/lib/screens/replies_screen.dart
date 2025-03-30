// screens/replies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/reply_card.dart'; // Use the ReplyCard widget
import 'create_reply_screen.dart';
import '../theme/theme_constants.dart'; // For styling

// Helper data structure for replies
class ReplyNode {
  final Map<String, dynamic> data;
  final List<ReplyNode> children;
  ReplyNode(this.data, {this.children = const []});
}

class RepliesScreen extends StatefulWidget {
  final String postId;
  final String? postTitle; // Optional: Pass post title for context

  const RepliesScreen({
    required this.postId,
    this.postTitle,
    Key? key
  }) : super(key: key);

  @override
  _RepliesScreenState createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> {

  Future<List<ReplyNode>>? _loadRepliesFuture;

  @override
  void initState() {
    super.initState();
    _triggerLoadReplies();
  }

  void _triggerLoadReplies() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
        _loadRepliesFuture = _fetchAndStructureReplies(apiService, authProvider.token);
    });
  }

  // Function to fetch replies and structure them hierarchically
  Future<List<ReplyNode>> _fetchAndStructureReplies(ApiService apiService, String? token) async {
    final flatReplies = await apiService.fetchReplies(widget.postId, token);
    // Build a map for easy lookup
    final Map<int?, List<Map<String, dynamic>>> repliesByParentId = {};
    for (var reply in flatReplies) {
      final parentId = reply['parent_reply_id'] as int?; // Can be null
      repliesByParentId.putIfAbsent(parentId, () => []).add(reply);
    }

    // Recursive function to build the node tree
    List<ReplyNode> buildTree(int? parentId) {
      if (!repliesByParentId.containsKey(parentId)) {
        return [];
      }
      return repliesByParentId[parentId]!.map((replyData) {
        final children = buildTree(replyData['id'] as int?);
        return ReplyNode(replyData, children: children);
      }).toList();
    }

    // Start building from top-level replies (parentId = null)
    return buildTree(null);
  }


  void _navigateToAddReply(BuildContext context, {String? parentReplyId, String? parentContent}) {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) { /* ... */ return; }

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CreateReplyScreen(
                postId: widget.postId,
                parentReplyId: parentReplyId, // Pass parent ID
                parentReplyContent: parentContent, // Pass parent content
              )),
    ).then((_) => _triggerLoadReplies()); // Refresh replies after returning
  }

  Future<void> _deleteReply(String replyId, ApiService apiService, AuthProvider authProvider) async {
     if (!authProvider.isAuthenticated) { /* ... */ return; }
     final confirmed = await showDialog<bool>( /* ... */ );
     if (confirmed == true) {
        try {
           await apiService.deleteReply(replyId, authProvider.token!);
           ScaffoldMessenger.of(context).showSnackBar( /* ... Success ... */);
           _triggerLoadReplies(); // Refresh replies
        } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar( /* ... Error ... */);
        }
     }
  }

   Future<void> _voteOnReply(ApiService apiService, AuthProvider authProvider, String replyId, bool voteType) async {
      // Similar logic to _voteOnPost, but targets replyId
       if (!authProvider.isAuthenticated) { /* ... */ return; }
       // TODO: Implement optimistic UI update for reply votes if needed
        try {
           await apiService.vote(replyId: int.parse(replyId), voteType: voteType, token: authProvider.token!);
           // Refreshing the whole list might be too much, consider updating just the vote count locally
           _triggerLoadReplies(); // Simple refresh for now
        } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar( /* ... Error ... */ );
        }
   }


  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
               return Center(child: Text('No replies yet. Be the first!'));
            }

            final structuredReplies = snapshot.data!;

            // Function to recursively build the list view items
            List<Widget> buildReplyWidgets(List<ReplyNode> nodes, int level) {
              List<Widget> widgets = [];
              for (var node in nodes) {
                final reply = node.data;
                 final replyId = reply['id'].toString();
                 final isOwner = authProvider.isAuthenticated && authProvider.userId == reply['user_id'].toString();
                 // TODO: Get actual vote status for replies
                 final bool hasUpvoted = false; // Replace with actual state
                 final bool hasDownvoted = false; // Replace with actual state

                widgets.add(
                  Padding(
                    padding: EdgeInsets.only(bottom: level > 0 ? 0 : 8.0), // Less padding for nested
                    child: ReplyCard(
                      content: reply['content'] ?? 'No Content',
                      authorName: reply['author_name'] ?? 'Anonymous',
                      authorAvatar: reply['author_avatar'],
                      timeAgo: "Some time ago", // Format reply['created_at']
                      upvotes: reply['upvotes'] ?? 0,
                      downvotes: reply['downvotes'] ?? 0,
                      isOwner: isOwner,
                      hasUpvoted: hasUpvoted,
                      hasDownvoted: hasDownvoted,
                      indentLevel: level, // Pass indent level
                      onReply: () => _navigateToAddReply(
                        context,
                        parentReplyId: replyId,
                        parentContent: reply['content'],
                      ),
                      onDelete: isOwner
                          ? () => _deleteReply(replyId, apiService, authProvider)
                          : null,
                       onUpvote: () => _voteOnReply(apiService, authProvider, replyId, true),
                       onDownvote: () => _voteOnReply(apiService, authProvider, replyId, false),
                      // childReplies: [], // ReplyCard doesn't need this directly anymore
                    ),
                  ),
                );
                // Recursively add children
                widgets.addAll(buildReplyWidgets(node.children, level + 1));
              }
              return widgets;
            }

            return ListView(
               padding: const EdgeInsets.all(8),
               children: buildReplyWidgets(structuredReplies, 0), // Start with level 0
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddReply(context), // Add top-level reply
        child: const Icon(Icons.add_comment),
        tooltip: "Add Reply",
      ),
    );
  }
}