// frontend/lib/screens/feed/posts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // Keep shimmer

// --- Service Imports ---
import '../../services/api/post_service.dart'; // Correct service
import '../../services/api/vote_service.dart'; // Needed for actions within the screen? No, handled by Card.
import '../../services/api/favorite_service.dart'; // Needed for actions within the screen? No, handled by Card.
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/post_card.dart'; // Updated PostCard
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart'; // For potential default images or base URL

// --- Navigation Imports ---
import '../create/create_post_screen.dart'; // Correct path
import '../replies_screen.dart'; // Correct path

// --- Formatting ---
import 'package:intl/intl.dart'; // For date formatting

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
  bool get wantKeepAlive => true; // Keep state

  String _selectedFilter = 'all'; // Default filter
  Future<List<dynamic>>? _loadPostsFuture;
  String? _error; // Store potential loading errors

  // Filter Tabs Data (Keep as is)
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
        _refreshPosts();      }
    });
  }

  // Renamed from _triggerPostLoad to avoid confusion with actual API call method
  void _refreshPosts() {
    if (!mounted) return;
    // Simply trigger a state change to make the FutureBuilder refetch
    setState(() {
      _error = null; // Clear previous error on refresh
      _loadPostsFuture = _fetchPostsData(); // Re-assign the future
    });
  }

  // Extracted the actual data fetching logic
  Future<List<dynamic>> _fetchPostsData() async {
    if (!mounted) return []; // Return empty if not mounted
    final apiService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (_selectedFilter == 'trending') {
        // Pass token if needed by backend for trending
        return await apiService.getTrendingPosts(token: authProvider.token);
      } else {
        // Pass token for main feed to get viewer-specific data
        return await apiService.getPosts(
          token: authProvider.token,
          communityId: widget.communityId,
          // Add limit/offset if implementing pagination later
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load posts: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
      // Re-throw so FutureBuilder can catch it
      throw e;
    }
  }

  // --- Actions (Navigate) ---
  void _navigateToReplies(String postId, String? postTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepliesScreen(postId: postId, postTitle: postTitle)),
    );
  }

  void _navigateToCreatePost() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create posts.')),
      );
      return;
    }
    // Navigate and wait for a potential result indicating success
    final result = await Navigator.push<bool>( // Expect a boolean result
      context,
      MaterialPageRoute(builder: (context) => CreatePostScreen(communityId: widget.communityId, communityName: widget.communityName)),
    );
    // Refresh list if result is true (indicating a post was created)
    if (result == true && mounted) {
      _refreshPosts();
    }
  }

  Future<void> _deletePost(String postId) async {
    if (!mounted) return;
    final apiService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.')));
      return;
    }

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Call service to delete post
        await apiService.deletePost(token: authProvider.token!, postId: int.parse(postId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post deleted'), duration: Duration(seconds: 1)));
          _refreshPosts(); // Refresh list after deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting post: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor));
        }
      }
    }
  }

  // --- Format Time (Keep helper) ---
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
      return DateFormat('MMM d, yyyy').format(dateTime); // Use intl package
    } catch (e) {
      print("Error formatting time ago: $e");
      return ''; // Return empty string on parsing error
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final authProvider = Provider.of<AuthProvider>(context); // Listen for auth changes if needed
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors; // Use theme constants

    // Re-fetch data when the widget first builds or is refreshed
    _loadPostsFuture ??= _fetchPostsData(); // Assign future only if null

    return Scaffold(
      // Only show AppBar if displaying posts for a specific community
      appBar: widget.communityId != null
          ? AppBar(title: Text(widget.communityName ?? 'Community Posts'))
          : null,
      body: Column(
        children: [
          // Filter tabs (Only show if not inside a specific community)
          if (widget.communityId == null)
            Container( /* ... keep filter tabs UI as before ... */
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
                      label: Text(filter['label']),
                      avatar: Icon(filter['icon'], size: 16, color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black54)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && _selectedFilter != filter['id']) {
                          setState(() { _selectedFilter = filter['id'] as String; });
                          _refreshPosts(); // Trigger refresh with new filter
                        }
                      },
                      selectedColor: ThemeConstants.accentColor,
                      backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  );
                },
              ),
            ),

          // Posts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshPosts(), // Use simple refresh trigger
              child: FutureBuilder<List<dynamic>>(
                future: _loadPostsFuture, // Use the state variable Future
                builder: (context, snapshot) {
                  // Handle loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingShimmer(); // Show shimmer
                  }
                  // Handle error state (check local _error first, then snapshot error)
                  if (_error != null || snapshot.hasError) {
                    return _buildErrorUI(_error ?? snapshot.error, isDark);
                  }
                  // Handle empty or no data state
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyUI(isDark, filter: _selectedFilter, communityName: widget.communityName);
                  }

                  // Display data
                  final posts = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index] as Map<String, dynamic>; // Cast data
                      final postId = post['id']?.toString() ?? ''; // Safe access to ID

                      // Determine community color (if applicable)
                      final int? postCommunityId = post['community_id'] as int?;
                      final Color? communityColor = postCommunityId != null
                          ? communityColors[postCommunityId.hashCode % communityColors.length]
                          : null;

                      // Determine if the current user owns this post
                      final bool isPostOwner = authProvider.isAuthenticated &&
                          authProvider.userId != null &&
                          post['user_id']?.toString() == authProvider.userId;

                      // Pass initial vote/favorite state to PostCard
                      // Safely access potentially null boolean values from backend data
                      bool initialUpvoted = post['viewer_vote_type'] == 'UP';
                      bool initialDownvoted = post['viewer_vote_type'] == 'DOWN';
                      bool initialFavorited = post['viewer_has_favorited'] == true;

                      return PostCard(
                        key: ValueKey(postId), // Use unique key for state preservation
                        postId: postId,
                        title: post['title'] ?? 'No Title',
                        content: post['content'] ?? 'No Content',
                        authorName: post['author_name'] ?? 'Anonymous',
                        authorAvatarUrl: post['author_avatar_url'], // Use URL directly
                        timeAgo: _formatTimeAgo(post['created_at']),
                        // Pass initial counts and states safely
                        initialUpvotes: post['upvotes'] ?? 0,
                        initialDownvotes: post['downvotes'] ?? 0,
                        initialReplyCount: post['reply_count'] ?? 0,
                        initialFavoriteCount: post['favorite_count'] ?? 0,
                        initialHasUpvoted: initialUpvoted,
                        initialHasDownvoted: initialDownvoted,
                        initialIsFavorited: initialFavorited,
                        isOwner: isPostOwner,
                        communityName: post['community_name'] as String?,
                        communityColor: communityColor,
                        // Pass callbacks
                        onReply: () => _navigateToReplies(postId, post['title']),
                        onDelete: isPostOwner ? () => _deletePost(postId) : null,
                        onTap: () => _navigateToReplies(postId, post['title']),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // Only show FAB if not inside a specific community screen
      floatingActionButton: widget.communityId == null
          ? FloatingActionButton(
        onPressed: _navigateToCreatePost,
        tooltip: "Create Post",
        child: const Icon(Icons.add),
      )
          : null, // Hide FAB if showing posts for a specific community
    );
  }

  // --- Helper Build Methods (Keep existing shimmer, empty, error UIs) ---
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
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
        : 'No posts found for "$filter".'; // Use filter name
    String suggestion = communityName != null
        ? 'Be the first to post here!'
        : 'Try changing the filter or create a new post!';
    return Center(
      child: SingleChildScrollView( // Allows scrolling if content overflows vertically
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text( suggestion, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700), textAlign: TextAlign.center,),
            const SizedBox(height: 24),
            // Only show create button if not inside a specific community context
            if (widget.communityId == null)
              CustomButton(text: 'Create Post', icon: Icons.add, onPressed: _navigateToCreatePost, type: ButtonType.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center( child: Padding( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: ThemeConstants.mediumPadding),
      Text('Failed to load posts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: ThemeConstants.smallPadding),
      Text( error.toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: ThemeConstants.largePadding),
      CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _refreshPosts, type: ButtonType.secondary), // Use _refreshPosts
    ],),),);
  }
}