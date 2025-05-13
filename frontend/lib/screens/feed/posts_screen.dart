// frontend/lib/screens/feed/posts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

// --- Service Imports ---
import '../../services/api/post_service.dart';
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/post_card.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

// --- Navigation Imports ---
import '../create/create_post_screen.dart';
import '../replies_screen.dart';

class PostsScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;

  const PostsScreen({
    Key? key,
    this.communityId,
    this.communityName,
  }) : super(key: key);

  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<List<dynamic>>? _loadPostsFuture;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _canLoadMore = true;
  List<dynamic> _posts = [];
  int _currentPage = 0;
  final int _limit = 15;

  String _selectedFilter = 'all';
  final List<Map<String, dynamic>> _filterTabs = [
    {'id': 'all', 'label': 'Discover', 'icon': Icons.explore_outlined},
    {'id': 'following', 'label': 'Following', 'icon': Icons.people_alt_outlined},
    // {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up}, // Backend for trending needed
  ];


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshPosts(isInitialLoad: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _canLoadMore) {
      _fetchPostsData(isPaginating: true);
    }
  }

  Future<void> _refreshPosts({bool isInitialLoad = false}) async {
    if (!mounted) return;
    _currentPage = 0;
    _posts.clear();
    _canLoadMore = true;
    setState(() {
      _error = null;
      _loadPostsFuture = _fetchPostsData(isInitialLoad: true);
    });
  }

  Future<List<dynamic>> _fetchPostsData({bool isInitialLoad = false, bool isPaginating = false}) async {
    if (!mounted) return [];
    if (isPaginating && _isLoadingMore) return _posts;
    if (!isPaginating && !isInitialLoad && _isLoadingMore) return _posts;

    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (isPaginating) {
      setState(() => _isLoadingMore = true);
    }

    try {
      List<dynamic> fetchedPosts;
      final currentOffset = _currentPage * _limit;

      if (widget.communityId != null) {
        fetchedPosts = await postService.getPosts(
          token: authProvider.token, communityId: widget.communityId,
          limit: _limit, offset: currentOffset,
        );
      } else {
        if (_selectedFilter == 'following') {
          if (!authProvider.isAuthenticated) {
            if (mounted) setState(() { _error = "Please log in to see your feed."; _isLoadingMore = false; _canLoadMore = false; });
            return _posts;
          }
          fetchedPosts = await postService.getFollowingFeed( // Now this method exists
            token: authProvider.token!, limit: _limit, offset: currentOffset,
          );
        } else if (_selectedFilter == 'trending') {
          fetchedPosts = await postService.getTrendingPosts(
            token: authProvider.token, limit: _limit, offset: currentOffset, // Pass params
          );
          if (currentOffset == 0) _posts.clear();
          _canLoadMore = fetchedPosts.length >= _limit;
        }
        else { // 'all' (Discover)
          fetchedPosts = await postService.getPosts(
            token: authProvider.token, limit: _limit, offset: currentOffset,
          );
        }
      }

      if (!mounted) return [];

      if (fetchedPosts.length < _limit) _canLoadMore = false;

      if (isInitialLoad || currentOffset == 0) {
        _posts = List<dynamic>.from(fetchedPosts);
      } else {
        final existingPostIds = _posts.map((p) => p['id']).toSet();
        _posts.addAll(fetchedPosts.where((p) => !existingPostIds.contains(p['id'])));
      }
      _currentPage++;
      _error = null;

    } catch (e) {
      if (mounted) {
        _error = "Failed to load posts: ${e.toString().replaceFirst("Exception: ", "")}";
        _canLoadMore = false;
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
    return _posts;
  }

  void _navigateToCreatePost() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to create posts.')));
      return;
    }
    final result = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (context) => CreatePostScreen(communityId: widget.communityId, communityName: widget.communityName)),
    );
    if (result == true && mounted) _refreshPosts(isInitialLoad: true);
  }

  void _navigateToReplies(String postId, String? postTitle) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RepliesScreen(postId: postId, postTitle: postTitle)),);
  }

  Future<void> _deletePost(String postId) async {
    if (!mounted) return;
    final postService = Provider.of<PostService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) return;

    final confirmed = await showDialog<bool>(
      context: context, builder: (context) => AlertDialog(
      title: const Text('Delete Post?'), content: const Text('Are you sure? This action cannot be undone.'),
      actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: ThemeConstants.errorColor)))],
    ),
    );
    if (confirmed == true) {
      try {
        await postService.deletePost(token: authProvider.token!, postId: int.parse(postId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted'), duration: Duration(seconds: 1)));
          _refreshPosts(isInitialLoad: true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting post: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now(); final difference = now.difference(dateTime);
      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    _loadPostsFuture ??= _fetchPostsData(isInitialLoad: true);

    return Scaffold(
      appBar: widget.communityId != null ? AppBar(title: Text(widget.communityName ?? 'Community Posts')) : null,
      body: Column(
        children: [
          if (widget.communityId == null) _buildFilterTabs(isDark, authProvider.isAuthenticated),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshPosts(isInitialLoad: true),
              child: FutureBuilder<List<dynamic>>(
                future: _loadPostsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _posts.isEmpty) return _buildLoadingShimmer();
                  if (_error != null && _posts.isEmpty) return _buildErrorUI(_error, isDark);
                  if (snapshot.hasError && _posts.isEmpty) return _buildErrorUI(snapshot.error, isDark);
                  if (_posts.isEmpty) return _buildEmptyUI(isDark, filter: _selectedFilter, communityName: widget.communityName);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length && _isLoadingMore) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2.0)));
                      if (index >= _posts.length) return const SizedBox.shrink();
                      final post = _posts[index] as Map<String, dynamic>;
                      final postId = post['id']?.toString() ?? '';
                      final int? postCommunityId = post['community_id'] as int?;
                      final Color? communityColor = postCommunityId != null ? communityColors[postCommunityId.hashCode % communityColors.length] : null;
                      final bool isPostOwner = authProvider.isAuthenticated && authProvider.userId != null && post['user_id']?.toString() == authProvider.userId;
                      bool initialUpvoted = post['viewer_vote_type'] == 'UP';
                      bool initialDownvoted = post['viewer_vote_type'] == 'DOWN';
                      bool initialFavorited = post['viewer_has_favorited'] == true;
                      return PostCard(
                        key: ValueKey("post_$postId"),
                        postId: postId, title: post['title'] ?? 'No Title', content: post['content'] ?? 'No Content',
                        authorName: post['author_name'] ?? 'Anonymous', authorAvatarUrl: post['author_avatar_url'], timeAgo: _formatTimeAgo(post['created_at']),
                        initialUpvotes: post['upvotes'] ?? 0, initialDownvotes: post['downvotes'] ?? 0, initialReplyCount: post['reply_count'] ?? 0, initialFavoriteCount: post['favorite_count'] ?? 0,
                        initialHasUpvoted: initialUpvoted, initialHasDownvoted: initialDownvoted, initialIsFavorited: initialFavorited,
                        isOwner: isPostOwner, communityName: post['community_name'] as String?, communityColor: communityColor, media: post['media'] as List<dynamic>?,
                        onReply: () => _navigateToReplies(postId, post['title']), onDelete: isPostOwner ? () => _deletePost(postId) : null, onTap: () => _navigateToReplies(postId, post['title']),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.communityId == null || authProvider.isAuthenticated)
          ? FloatingActionButton(onPressed: _navigateToCreatePost, tooltip: "Create Post", child: const Icon(Icons.add_rounded))
          : null,
    );
  }

  Widget _buildFilterTabs(bool isDark, bool isAuthenticated) {
    return Container( height: 50, color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
      child: ListView.builder( scrollDirection: Axis.horizontal, itemCount: _filterTabs.length, padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8),
        itemBuilder: (context, index) {
          final filter = _filterTabs[index]; final bool isSelected = _selectedFilter == filter['id']; final bool isEnabled = !(filter['id'] == 'following' && !isAuthenticated);
          return Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(filter['label']), avatar: Icon(filter['icon'], size: 16, color: isEnabled ? (isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black54)) : Colors.grey.shade500),
              selected: isSelected, onSelected: isEnabled ? (selected) { if (selected && _selectedFilter != filter['id']) { setState(() => _selectedFilter = filter['id'] as String); _refreshPosts(isInitialLoad: true); } } : null,
              selectedColor: isEnabled ? ThemeConstants.accentColor : Colors.grey.shade300, backgroundColor: isEnabled ? (isDark ? ThemeConstants.backgroundDark : Colors.white) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              labelStyle: TextStyle(color: isEnabled ? (isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87)) : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              disabledColor: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade300.withOpacity(0.5), padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark; final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300; final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors( baseColor: baseColor, highlightColor: highlightColor,
      child: ListView.builder( padding: const EdgeInsets.all(ThemeConstants.mediumPadding), itemCount: 5,
        itemBuilder: (_, __) => Padding( padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding), child: Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius)))),
      ),
    );
  }

  Widget _buildEmptyUI(bool isDark, {String? filter, String? communityName}) {
    String message = communityName != null ? 'No posts found in "$communityName".' : 'No posts found for "${_filterTabs.firstWhere((f) => f['id'] == filter, orElse: () => {'label': filter})['label']}".';
    String suggestion = communityName != null ? 'Be the first to post here!' : 'Try a different filter or create a new post!';
    if (filter == 'following' && !Provider.of<AuthProvider>(context, listen:false).isAuthenticated) { message = 'Log in to see posts from users you follow.'; suggestion = ''; }
    return Center( child: SingleChildScrollView( padding: const EdgeInsets.all(ThemeConstants.largePadding),
      child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.article_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400), const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        if (suggestion.isNotEmpty) const SizedBox(height: 8),
        if (suggestion.isNotEmpty) Text( suggestion, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700), textAlign: TextAlign.center,), const SizedBox(height: 24),
        if (widget.communityId == null && Provider.of<AuthProvider>(context, listen:false).isAuthenticated) CustomButton(text: 'Create Post', icon: Icons.add, onPressed: _navigateToCreatePost, type: ButtonType.primary),
        if (filter == 'following' && !Provider.of<AuthProvider>(context, listen:false).isAuthenticated) CustomButton(text: 'Log In', icon: Icons.login, onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), type: ButtonType.primary),
      ],),
    ),);
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center( child: Padding( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: ThemeConstants.mediumPadding),
      Text('Failed to load posts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: ThemeConstants.smallPadding),
      Text( error.toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: ThemeConstants.largePadding),
      CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: () => _refreshPosts(isInitialLoad: true), type: ButtonType.secondary),
    ],),),);
  }
}