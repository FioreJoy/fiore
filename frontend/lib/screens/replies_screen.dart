// frontend/lib/screens/replies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // For loading state

// --- Service Imports ---
import '../../services/api/reply_service.dart'; // Correct service
import '../../services/auth_provider.dart';
// VoteService and FavoriteService are used within ReplyCard now

// --- Widget Imports ---
import '../../widgets/reply_card.dart'; // Updated ReplyCard
import '../../widgets/custom_button.dart'; // For error/empty states

// --- Navigation Imports ---
import 'create/create_reply_screen.dart'; // Correct path

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';

// --- Formatting ---
import 'package:intl/intl.dart';

// Helper data structure for replies hierarchy (Keep as is)
class ReplyNode {
  final Map<String, dynamic> data;
  final List<ReplyNode> children;
  bool isExpanded;

  ReplyNode(this.data, {this.children = const [], this.isExpanded = true});
}

class RepliesScreen extends StatefulWidget {
  final String postId; // Keep as String if consistently used, else int
  final String? postTitle;

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
  String? _error;

  // No longer need local vote map, ReplyCard handles its state
  // final Map<String, Map<String, dynamic>> _replyVoteData = {};

  @override
  void initState() {
    super.initState();
    // Initial load triggered by FutureBuilder
    _loadRepliesFuture = _fetchAndStructureReplies();
  }

  // Renamed from _triggerLoadReplies
  Future<void> _refreshReplies() async {
    if (!mounted) return;
    setState(() {
      _error = null; // Clear previous error
      _loadRepliesFuture = _fetchAndStructureReplies(); // Re-assign Future
    });
  }

  // Fetch and structure replies
  Future<List<ReplyNode>> _fetchAndStructureReplies() async {
    if (!mounted) return [];
    final replyService = Provider.of<ReplyService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Fetch replies - backend now includes counts and viewer status if authenticated
      final flatReplies = await replyService.getRepliesForPost(
        int.parse(widget.postId), // Convert postId to int for service
        token: authProvider.token, // Pass token to get viewer status
      );

      if (!mounted) return []; // Check again after await

      // --- Build Tree Structure (Keep existing logic) ---
      final Map<int?, List<Map<String, dynamic>>> repliesByParentId = {};
      for (var reply in flatReplies) {
        // Ensure reply is a Map
        if (reply is Map<String, dynamic>) {
          final parentId = reply['parent_reply_id'] as int?;
          repliesByParentId.putIfAbsent(parentId, () => []).add(reply);
        } else {
          print("Warning: Received non-map item in replies list: $reply");
        }
      }

      List<ReplyNode> buildTree(int? parentId) {
        if (!repliesByParentId.containsKey(parentId)) { return []; }
        repliesByParentId[parentId]!.sort((a, b) {
          DateTime timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
          DateTime timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
          return timeA.compareTo(timeB);
        });
        return repliesByParentId[parentId]!.map((replyData) {
          final children = buildTree(replyData['id'] as int?);
          return ReplyNode(replyData, children: children);
        }).toList();
      }
      // --- End Build Tree ---

      return buildTree(null); // Build tree from top-level replies

    } catch (e) {
      print("Error fetching/structuring replies: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to load replies: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
      // Re-throw error for FutureBuilder
      throw e;
    }
  }


  // --- Actions ---
  void _navigateToAddReply(BuildContext context, {String? parentReplyId, String? parentContent}) {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to reply.')));
      return;
    }

    Navigator.push<bool>( // Expect boolean result
      context,
      MaterialPageRoute(
          builder: (context) => CreateReplyScreen(
            postId: int.parse(widget.postId), // Pass int ID
            parentReplyId: parentReplyId != null ? int.parse(parentReplyId) : null, // Pass int ID
            parentReplyContent: parentContent,
          )),
    ).then((didCreate) { // Refresh replies if one was created
      if (didCreate == true && mounted) {
        _refreshReplies();
      }
    });
  }

  Future<void> _deleteReply(String replyId) async {
    if (!mounted) return;
    final replyService = Provider.of<ReplyService>(context, listen: false); // Use ReplyService
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) return;

    // Confirmation Dialog (Keep as is)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog( /* ... dialog content ... */
        title: const Text('Delete Reply?'),
        content: const Text('Are you sure you want to delete this reply?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Call delete service method
        await replyService.deleteReply(token: authProvider.token!, replyId: int.parse(replyId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reply deleted'), duration: Duration(seconds: 1)));
          _refreshReplies(); // Refresh replies list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error deleting reply: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: ThemeConstants.errorColor));
        }
      }
    }
  }

  // Note: _voteOnReply is REMOVED, as this logic now resides within ReplyCard

  // --- Format Time (Keep helper) ---
  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return '${difference.inSeconds}s';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      return DateFormat('MMM d').format(dateTime);
    } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    //super.build(context); // Keep state
    final authProvider = Provider.of<AuthProvider>(context); // Listen for auth changes if needed

    return Scaffold(
      appBar: AppBar(title: Text(widget.postTitle ?? "Replies")),
      body: RefreshIndicator(
        onRefresh: _refreshReplies, // Use simple refresh trigger
        child: FutureBuilder<List<ReplyNode>>(
          future: _loadRepliesFuture, // Use state Future
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingShimmer(); // Use shimmer
            }
            // Check local error state first
            if (_error != null) {
              return _buildErrorUI(_error!, Theme.of(context).brightness == Brightness.dark);
            }
            if (snapshot.hasError) {
              return _buildErrorUI(snapshot.error, Theme.of(context).brightness == Brightness.dark);
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyUI(Theme.of(context).brightness == Brightness.dark); // Use empty state UI
            }

            final structuredReplies = snapshot.data!;

            // Function to recursively build the list view items
            List<Widget> buildReplyWidgets(List<ReplyNode> nodes, int level) {
              List<Widget> widgets = [];
              for (var node in nodes) {
                final reply = node.data; // This is the Map<String, dynamic> for the reply
                final replyId = reply['id']?.toString() ?? ''; // Safe access
                if (replyId.isEmpty) continue; // Skip if ID is invalid

                final bool isOwner = authProvider.isAuthenticated &&
                    authProvider.userId != null &&
                    reply['user_id']?.toString() == authProvider.userId;

                // Extract initial state for ReplyCard from the fetched data
                bool initialUpvoted = reply['viewer_vote_type'] == 'UP';
                bool initialDownvoted = reply['viewer_vote_type'] == 'DOWN';
                bool initialFavorited = reply['viewer_has_favorited'] == true;

                widgets.add(
                  // Removed extra Padding, ReplyCard handles its margin/padding
                  ReplyCard(
                    key: ValueKey(replyId), // Use unique key
                    replyId: replyId,
                    content: reply['content'] ?? '...',
                    authorName: reply['author_name'] ?? 'Anonymous',
                    authorAvatarUrl: reply['author_avatar_url'], // Pass URL directly
                    timeAgo: _formatTimeAgo(reply['created_at']),
                    // Pass initial counts and states
                    initialUpvotes: reply['upvotes'] ?? 0,
                    initialDownvotes: reply['downvotes'] ?? 0,
                    initialFavoriteCount: reply['favorite_count'] ?? 0,
                    initialHasUpvoted: initialUpvoted,
                    initialHasDownvoted: initialDownvoted,
                    initialIsFavorited: initialFavorited,
                    isOwner: isOwner,
                    indentLevel: level,
                    // Pass callbacks (vote/favorite handled internally by ReplyCard)
                    onReply: () => _navigateToAddReply(
                      context,
                      parentReplyId: replyId,
                      parentContent: reply['content'],
                    ),
                    onDelete: isOwner ? () => _deleteReply(replyId) : null,
                  ),
                );
                // Recursively add children
                widgets.addAll(buildReplyWidgets(node.children, level + 1));
              }
              return widgets;
            }

            return ListView(
              padding: const EdgeInsets.all(ThemeConstants.smallPadding), // Add some padding around the list
              children: buildReplyWidgets(structuredReplies, 0),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddReply(context), // Add top-level reply
        tooltip: "Add Reply",
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  // --- Helper Build Methods ---
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor, highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(ThemeConstants.smallPadding),
        itemCount: 8, // Placeholder count
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Container(
            height: 80, // Approximate height of a reply card
            decoration: BoxDecoration(
              color: Colors.white, // Base for shimmer
              borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUI(bool isDark) {
    return Center( child: SingleChildScrollView( // Allow scrolling on small screens
      padding: const EdgeInsets.all(ThemeConstants.largePadding),
      child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.comment_outlined, size: 60, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('No replies yet.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextButton( onPressed: () => _navigateToAddReply(context), child: const Text('Be the first to reply!'),),
      ],),
    ),);
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center( child: SingleChildScrollView( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: ThemeConstants.mediumPadding),
      Text('Failed to load replies', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: ThemeConstants.smallPadding),
      Text( error.toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: ThemeConstants.largePadding),
      CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _refreshReplies, type: ButtonType.secondary),
    ],),),);
  }
}