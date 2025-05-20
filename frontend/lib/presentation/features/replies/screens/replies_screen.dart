import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/reply_api.dart'; // For ReplyApiService

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/reply_card.dart';     // Path to global widget
import '../../../global_widgets/custom_button.dart';    // Path to global widget
import '../../create/screens/create_reply_screen.dart'; // Path to create feature screen

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';
// import '../../../../core/constants/app_constants.dart'; // Not directly used in this screen

// Assuming a typedef for ReplyService if its class name wasn't changed during file rename.
// If ReplyService class in reply_api.dart is now ReplyApi, use that directly.
typedef ReplyApiService = ReplyService;

// ReplyNode helper class (no path changes needed, it's local)
class ReplyNode {
  final Map<String, dynamic> data;
  final List<ReplyNode> children;
  bool isExpanded;
  ReplyNode(this.data, {this.children = const [], this.isExpanded = true});
}

class RepliesScreen extends StatefulWidget {
  final String postId;
  final String? postTitle;

  const RepliesScreen({ required this.postId, this.postTitle, Key? key }) : super(key: key);

  @override
  _RepliesScreenState createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> {
  Future<List<ReplyNode>>? _loadRepliesFuture;
  String? _error;

  @override
  void initState() { super.initState(); _loadRepliesFuture = _fetchAndStructureReplies(); }

  Future<void> _refreshReplies() async { if (!mounted) return; setState(() { _error = null; _loadRepliesFuture = _fetchAndStructureReplies(); }); }

  Future<List<ReplyNode>> _fetchAndStructureReplies() async {
    if (!mounted) return [];
    final replyService = Provider.of<ReplyApiService>(context, listen: false); // Use typedef
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final flatReplies = await replyService.getRepliesForPost( int.parse(widget.postId), token: authProvider.token,);
      if (!mounted) return [];
      final Map<int?, List<Map<String, dynamic>>> repliesByParentId = {};
      for (var reply in flatReplies) { if (reply is Map<String, dynamic>) { final parentId = reply['parent_reply_id'] as int?; repliesByParentId.putIfAbsent(parentId, () => []).add(reply); } else { /* print("Warning: Non-map item in replies: $reply"); */ }}
      List<ReplyNode> buildTree(int? parentId) { if (!repliesByParentId.containsKey(parentId)) return []; repliesByParentId[parentId]!.sort((a, b) { DateTime timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0); DateTime timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0); return timeA.compareTo(timeB); }); return repliesByParentId[parentId]!.map((replyData) { final children = buildTree(replyData['id'] as int?); return ReplyNode(replyData, children: children);}).toList(); }
      return buildTree(null);
    } catch (e) { /* print("Error fetching/structuring replies: $e"); */ if (mounted) setState(() => _error = "Failed to load: ${e.toString().replaceFirst("Exception: ", "")}"); throw e; }
  }

  void _navigateToAddReply(BuildContext context, {String? parentReplyId, String? parentContent}) { /* ... Correct CreateReplyScreen path implicitly fixed by its own move ... */
    final authProvider = context.read<AuthProvider>(); if (!authProvider.isAuthenticated) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log in to reply.'))); return; }
    Navigator.push<bool>( context, MaterialPageRoute( builder: (context) => CreateReplyScreen( postId: int.parse(widget.postId), parentReplyId: parentReplyId != null ? int.parse(parentReplyId) : null, parentReplyContent: parentContent,)),).then((didCreate) { if (didCreate == true && mounted) _refreshReplies(); });
  }
  Future<void> _deleteReply(String replyId) async { /* ... Correct ReplyApiService path, ThemeConstants ... */
    if (!mounted) return; final replyService = Provider.of<ReplyApiService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false); if (!authProvider.isAuthenticated || authProvider.token == null) return;
    final confirmed = await showDialog<bool>( context: context, builder: (context) => AlertDialog( title: const Text('Delete Reply?'), content: const Text('Sure?'), actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor)))],),);
    if (confirmed == true) { try { await replyService.deleteReply(token: authProvider.token!, replyId: int.parse(replyId)); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Reply deleted'), duration: Duration(seconds: 1))); _refreshReplies();}}
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Error deleting: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor));}}
  }
  String _formatTimeAgo(String? dateTimeString) { /* ... Unchanged ... */ if (dateTimeString == null) return ''; try { final dt = DateTime.parse(dateTimeString).toLocal(); final now = DateTime.now(); final diff = now.difference(dt); if (diff.inSeconds < 60) return '${diff.inSeconds}s'; if (diff.inMinutes < 60) return '${diff.inMinutes}m'; if (diff.inHours < 24) return '${diff.inHours}h'; if (diff.inDays < 7) return '${diff.inDays}d'; return DateFormat('MMM d').format(dt); } catch(e) {return '';}}

  @override
  Widget build(BuildContext context) { /* ... UI unchanged, paths fixed via imports ... */
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold( appBar: AppBar(title: Text(widget.postTitle ?? "Replies")),
      body: RefreshIndicator( onRefresh: _refreshReplies, child: FutureBuilder<List<ReplyNode>>( future: _loadRepliesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingShimmer();
          if (_error != null) return _buildErrorUI(_error!, Theme.of(context).brightness == Brightness.dark);
          if (snapshot.hasError) return _buildErrorUI(snapshot.error, Theme.of(context).brightness == Brightness.dark);
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyUI(Theme.of(context).brightness == Brightness.dark);
          final structuredReplies = snapshot.data!;
          List<Widget> buildReplyWidgets(List<ReplyNode> nodes, int level) { List<Widget> widgets = []; for (var node in nodes) { final reply = node.data; final replyId = reply['id']?.toString() ?? ''; if (replyId.isEmpty) continue; final bool isOwner = authProvider.isAuthenticated && authProvider.userId != null && reply['user_id']?.toString() == authProvider.userId; bool initialUpvoted = reply['viewer_vote_type'] == 'UP'; bool initialDownvoted = reply['viewer_vote_type'] == 'DOWN'; bool initialFavorited = reply['viewer_has_favorited'] == true;
          widgets.add( ReplyCard( key: ValueKey(replyId), replyId: replyId, content: reply['content'] ?? '...', authorName: reply['author_name'] ?? 'Anonymous', authorAvatarUrl: reply['author_avatar_url'], timeAgo: _formatTimeAgo(reply['created_at']), initialUpvotes: reply['upvotes'] ?? 0, initialDownvotes: reply['downvotes'] ?? 0, initialFavoriteCount: reply['favorite_count'] ?? 0, initialHasUpvoted: initialUpvoted, initialHasDownvoted: initialDownvoted, initialIsFavorited: initialFavorited, isOwner: isOwner, indentLevel: level, onReply: () => _navigateToAddReply(context, parentReplyId: replyId, parentContent: reply['content'],), onDelete: isOwner ? () => _deleteReply(replyId) : null, media: reply['media'] as List<dynamic>?)); widgets.addAll(buildReplyWidgets(node.children, level + 1));} return widgets;}
          return ListView( padding: const EdgeInsets.all(ThemeConstants.smallPadding), children: buildReplyWidgets(structuredReplies, 0),);},),),
      floatingActionButton: FloatingActionButton( onPressed: () => _navigateToAddReply(context), tooltip: "Add Reply", child: const Icon(Icons.add_comment),),);
  }
  Widget _buildLoadingShimmer() { /* ... Unchanged ... */ final isDark = Theme.of(context).brightness == Brightness.dark; final baseC = isDark ? Colors.grey.shade800 : Colors.grey.shade300; final highC = isDark ? Colors.grey.shade700 : Colors.grey.shade100; return Shimmer.fromColors( baseColor: baseC, highlightColor: highC, child: ListView.builder( padding: const EdgeInsets.all(ThemeConstants.smallPadding), itemCount: 8, itemBuilder: (_, __) => Padding( padding: const EdgeInsets.symmetric(vertical: 6.0), child: Container( height: 80, decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),),),),),); }
  Widget _buildEmptyUI(bool isDark) { /* ... Unchanged ... */ return Center( child: SingleChildScrollView( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.comment_outlined, size: 60, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400), const SizedBox(height: 16), Text('No replies yet.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)), const SizedBox(height: 8), TextButton( onPressed: () => _navigateToAddReply(context), child: const Text('Be the first to reply!'),),],),),); }
  Widget _buildErrorUI(Object? error, bool isDark) { /* ... Unchanged ... */ return Center( child: SingleChildScrollView( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: ThemeConstants.mediumPadding), Text('Failed to load replies', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: ThemeConstants.smallPadding), Text( error.toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: ThemeConstants.largePadding), CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _refreshReplies, type: ButtonType.secondary), ],),),); }
}