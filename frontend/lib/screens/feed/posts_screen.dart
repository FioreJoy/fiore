// frontend/lib/screens/feed/posts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

// --- Service Imports ---
import '../../services/api/post_service.dart';
import '../../services/api/vote_service.dart'; // Import VoteService
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/post_card.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

// --- Screen Imports ---
import '../create/create_post_screen.dart';
import '../replies_screen.dart';

class PostsScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;

  const PostsScreen({
    Key? key,
    this.communityId,
    this.communityName
  }) : super(key: key);

  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Use String keys for consistency if IDs are strings in PostCard/VoteService
  final Map<String, Map<String, dynamic>> _postVoteData = {};

  String _selectedFilter = 'all';
  Future<List<dynamic>>? _loadPostsFuture;

  final List<Map<String, dynamic>> _filterTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.public},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.new_releases},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerPostLoad();
      }
    });
  }

  void _triggerPostLoad() {
    if (!mounted) return;
    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // No need to check apiClient here, assume AuthProvider manages it
    if (!authProvider.isAuthenticated) {
      print("PostsScreen: Not authenticated. Cannot load posts.");
      setState(() { _loadPostsFuture = Future.value([]); }); // Return empty list
      return;
    }

    setState(() {
      // TODO: Verify PostService method names and parameters for filters
      if (_selectedFilter == 'trending') {
        print("Loading trending posts...");
        // Assuming getTrendingPosts exists, otherwise use getPosts
        _loadPostsFuture = postService.getTrendingPosts(communityId: widget.communityId);
      } else if (_selectedFilter == 'latest') {
        print("Loading latest posts (using getPosts)...");
        _loadPostsFuture = postService.getPosts(communityId: widget.communityId /*, sortBy: 'latest' */);
      } else { // Default to 'all'
        print("Loading all posts...");
        _loadPostsFuture = postService.getPosts(communityId: widget.communityId);
      }
    });
  }

  // --- Actions ---
  // <<< FIX: Use int postId and VoteService >>>
  Future<void> _voteOnPost(int postId, bool voteType) async {
    if (!mounted) return;
    // <<< FIX: Get VoteService >>>
    final voteService = Provider.of<VoteService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote.')));
      return;
    }

    final postIdStr = postId.toString(); // Use String for map key
    final currentVoteData = _postVoteData[postIdStr] ?? {'vote_type': null, 'upvotes': 0, 'downvotes': 0};
    final previousVoteType = currentVoteData['vote_type'] as bool?;
    final currentUpvotes = currentVoteData['upvotes'] as int? ?? 0;
    final currentDownvotes = currentVoteData['downvotes'] as int? ?? 0;

    // Optimistic UI update
    setState(() {
      final newData = Map<String, dynamic>.from(currentVoteData);
      int newUpvotes = currentUpvotes; int newDownvotes = currentDownvotes;
      if (previousVoteType == voteType) { newData['vote_type'] = null; if (voteType == true) newUpvotes--; else newDownvotes--; }
      else { newData['vote_type'] = voteType; if (voteType == true) { newUpvotes++; if (previousVoteType == false) newDownvotes--; } else { newDownvotes++; if (previousVoteType == true) newUpvotes--; } }
      newData['upvotes'] = newUpvotes < 0 ? 0 : newUpvotes; newData['downvotes'] = newDownvotes < 0 ? 0 : newDownvotes;
      _postVoteData[postIdStr] = newData; // Use string key
    });

    try {
      // <<< FIX: Call VoteService.castVote with named parameters >>>
      await voteService.castVote(
        postId: postId, // Pass int postId
        replyId: null, // Explicitly null for post vote
        voteType: voteType,
      );
      // Consider refreshing just the counts instead of all posts
      // For now, simple refresh:
      // _triggerPostLoad(); // Can cause flicker, maybe update counts from response
    } catch (e) {
      if (!mounted) return;
      // Revert UI on error
      setState(() {
        _postVoteData[postIdStr] = currentVoteData; // Restore original data using string key
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: ${e.toString()}'), backgroundColor: ThemeConstants.errorColor));
    }
  }

  // <<< FIX: Changed postId parameter to int >>>
  void _navigateToReplies(int postId, String? postTitle) {
    Navigator.push(
      context,
      // <<< FIX: Pass int postId to RepliesScreen >>>
      MaterialPageRoute(builder: (context) => RepliesScreen(postId: postId, postTitle: postTitle)),
    );
  }

  void _navigateToCreatePost() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) { /* Show login message */ return; }

    // Navigate and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreatePostScreen(communityId: widget.communityId, communityName: widget.communityName)),
    );
    // Refresh if the create screen indicated success (e.g., returned true)
    if (result == true && mounted) {
      _triggerPostLoad();
    }
  }

  // <<< FIX: Changed postId parameter to int >>>
  Future<void> _deletePost(int postId) async {
    if (!mounted) return;
    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) return; // Silently return if not logged in

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to delete this post? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton( onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor)), ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // <<< FIX: Pass int postId using named parameter >>>
        await postService.deletePost(postId: postId); // Assuming deletePost expects named param
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted'), duration: Duration(seconds: 1)));
        _triggerPostLoad(); // Refresh list
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: ${e.toString()}'), backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  // Format DateTime string (Keep as before)
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
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) { return ''; }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final authProvider = Provider.of<AuthProvider>(context); // Listen for auth state changes if needed
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    // <<< FIX: Get current user ID as int? >>>
    final int? currentUserId = authProvider.userId;

    return Scaffold(
      appBar: widget.communityId != null ? AppBar(title: Text(widget.communityName ?? 'Community Posts')) : null,
      body: Column(
        children: [
          // Filter tabs (only show if not inside a specific community)
          if (widget.communityId == null)
            Container(
              height: 50,
              color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filterTabs.length,
                padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8),
                itemBuilder: (context, index) {
                  final filter = _filterTabs[index];
                  final isSelected = _selectedFilter == filter['id'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(filter['label'] as String),
                      avatar: Icon(filter['icon'] as IconData?, size: 16, color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black54)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && _selectedFilter != filter['id']) {
                          setState(() { _selectedFilter = filter['id'] as String; });
                          _triggerPostLoad(); // Reload posts when filter changes
                        }
                      },
                      selectedColor: ThemeConstants.accentColor.withOpacity(0.3),
                      backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: StadiumBorder(side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      showCheckmark: false, // Hide default checkmark
                    ),
                  );
                },
              ),
            ),

          // Posts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _triggerPostLoad(),
              child: FutureBuilder<List<dynamic>>(
                future: _loadPostsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && (_loadPostsFuture == null || snapshot.data == null) ) {
                    return _buildLoadingShimmer(); // Show shimmer on initial load
                  }
                  if (snapshot.hasError) {
                    return _buildErrorUI(snapshot.error, isDark);
                  }
                  // Check specifically for null data even if connection is done
                  if (!snapshot.hasData && snapshot.connectionState == ConnectionState.done) {
                    // Could be an error state not caught, or empty list returned legitimately
                    print("FutureBuilder: snapshot has no data but connection is done.");
                    return _buildEmptyUI(isDark, filter: _selectedFilter, communityName: widget.communityName);
                  }
                  if (snapshot.data == null || snapshot.data!.isEmpty) {
                    return _buildEmptyUI(isDark, filter: _selectedFilter, communityName: widget.communityName);
                  }

                  final posts = snapshot.data!;

                  // Update vote data map after posts are fetched
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    bool needsUiUpdate = false;
                    for (var postDyn in posts) {
                      // Ensure post is a map and has an ID
                      if (postDyn is! Map<String, dynamic> || postDyn['id'] == null) continue;
                      final post = postDyn; // Now we know it's a map
                      final postIdStr = post['id'].toString(); // Use String key
                      final fetchedUpvotes = post['upvotes'] as int? ?? 0;
                      final fetchedDownvotes = post['downvotes'] as int? ?? 0;
                      final fetchedVoteType = post['user_vote'] as bool?; // Assuming backend sends this

                      if (!_postVoteData.containsKey(postIdStr)) {
                        _postVoteData[postIdStr] = { 'vote_type': fetchedVoteType, 'upvotes': fetchedUpvotes, 'downvotes': fetchedDownvotes };
                        needsUiUpdate = true;
                      } else {
                        final localVoteData = _postVoteData[postIdStr]!;
                        // Update only if counts differ, keep local vote state unless server provides it
                        if (localVoteData['upvotes'] != fetchedUpvotes || localVoteData['downvotes'] != fetchedDownvotes ) {
                          _postVoteData[postIdStr]!['upvotes'] = fetchedUpvotes;
                          _postVoteData[postIdStr]!['downvotes'] = fetchedDownvotes;
                          // Optionally update vote_type if provided by backend, otherwise keep optimistic state
                          if (localVoteData['vote_type'] != fetchedVoteType && fetchedVoteType != null) {
                            _postVoteData[postIdStr]!['vote_type'] = fetchedVoteType;
                          }
                          needsUiUpdate = true;
                        }
                      }
                    }
                    if (needsUiUpdate && mounted) { setState(() {}); }
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final postDyn = posts[index];
                      // Add check for valid post data
                      if (postDyn is! Map<String, dynamic> || postDyn['id'] == null) {
                        return const SizedBox.shrink(); // Skip invalid items
                      }
                      final post = postDyn;
                      // <<< FIX: Use int ID internally, convert to String for map key >>>
                      final int postIdInt = post['id'] as int? ?? 0;
                      final String postIdStr = postIdInt.toString();


                      final voteData = _postVoteData[postIdStr] ?? {'vote_type': null, 'upvotes': post['upvotes'] ?? 0, 'downvotes': post['downvotes'] ?? 0};
                      final bool hasUpvoted = voteData['vote_type'] == true;
                      final bool hasDownvoted = voteData['vote_type'] == false;
                      final int displayUpvotes = voteData['upvotes'] ?? 0;
                      final int displayDownvotes = voteData['downvotes'] ?? 0;

                      final communityName = post['community_name'] as String?;
                      final Color? communityColor = communityName != null && post['community_id'] != null
                          ? communityColors[post['community_id'].hashCode % communityColors.length]
                          : null;

                      // <<< FIX: Compare int? with post['user_id'] (which should also be int) >>>
                      final bool isPostOwner = authProvider.isAuthenticated &&
                          currentUserId != null &&
                          post['user_id'] == currentUserId; // Direct int comparison


                      // Assume PostCard accepts a Map<String, dynamic> or a PostModel
                      // If PostCard expects PostModel, map 'post' map to PostModel here
                      // PostModel postModel = PostModel.fromJson(post); // Example

                      return Padding(
                        padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                        child: PostCard(
                          // Option 1: Pass individual fields
                          // postId: postIdStr, // Pass String ID if PostCard expects it
                          title: post['title'] ?? 'No Title',
                          content: post['content'] ?? '',
                          authorName: post['author_name'] ?? 'Anonymous',
                          authorAvatar: post['author_avatar_url'], // Use pre-generated URL if available
                          timeAgo: _formatTimeAgo(post['created_at']),
                          upvotes: displayUpvotes,
                          downvotes: displayDownvotes,
                          replyCount: post['reply_count'] ?? 0,
                          hasUpvoted: hasUpvoted,
                          hasDownvoted: hasDownvoted,
                          isOwner: isPostOwner,
                          communityName: communityName,
                          communityColor: communityColor,
                          imageUrl: post['image_url'], // Use pre-generated URL if available

                          // Option 2: Pass PostModel (if PostCard expects it)
                          // post: postModel,

                          // <<< FIX: Pass int ID to callbacks >>>
                          onUpvote: () => _voteOnPost(postIdInt, true),
                          onDownvote: () => _voteOnPost(postIdInt, false),
                          onReply: () => _navigateToReplies(postIdInt, post['title']),
                          onDelete: isPostOwner ? () => _deletePost(postIdInt) : null,
                          onTap: () => _navigateToReplies(postIdInt, post['title']),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        child: const Icon(Icons.add),
        tooltip: "Create Post",
        backgroundColor: ThemeConstants.accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- Helper Build Methods ---
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        itemCount: 5, // Number of shimmer items
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
          child: Container(
            height: 180, // Adjust height to match PostCard estimate
            decoration: BoxDecoration(
              color: Colors.white, // Base color for shimmer container
              borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUI(bool isDark, {String? filter, String? communityName}) {
    String message = communityName != null
        ? 'No posts found in "$communityName".'
        : 'No posts found for "$filter".';
    String suggestion = communityName != null
        ? 'Be the first to post here!'
        : 'Try changing the filter or create a new post!';
    return Center(
      child: SingleChildScrollView( // Allow scrolling if content overflows
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text( suggestion, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700), textAlign: TextAlign.center, ),
            const SizedBox(height: 24),
            CustomButton(text: 'Create Post', icon: Icons.add, onPressed: _navigateToCreatePost, type: ButtonType.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.largePadding),
          child: CustomCard( // Use CustomCard for consistent styling
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Fit content
                children: [
                  const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48),
                  const SizedBox(height: ThemeConstants.smallPadding),
                  Text('Failed to load posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: ThemeConstants.smallPadding),
                  Text(error?.toString() ?? 'An unknown error occurred.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                  const SizedBox(height: ThemeConstants.mediumPadding),
                  CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _triggerPostLoad, type: ButtonType.primary),
                ],
              ),
            ),
          ),
        )
    );
  }
} // End of _PostsScreenState