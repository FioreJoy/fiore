import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../theme/theme_constants.dart';
import 'create_post_screen.dart';
import 'replies_screen.dart';
import 'dart:math' as math;

class PostsScreen extends StatefulWidget {
  const PostsScreen({Key? key}) : super(key: key);

  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Map to track VOTE DATA for each post (stores more than just bool)
  // Key: postId, Value: Map {'vote_type': bool?, 'upvotes': int, 'downvotes': int}
  // vote_type: true=upvoted, false=downvoted, null=not voted
  final Map<String, Map<String, dynamic>> _postVoteData = {};

  // Selected filter
  String _selectedFilter = 'all';

  // Future for loading posts based on filter
  Future<List<dynamic>>? _loadPostsFuture;

  // Filter tabs
  final List<Map<String, dynamic>> _filterTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.public},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    // {'id': 'following', 'label': 'Following', 'icon': Icons.favorite}, // Add backend support first
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.new_releases}, // 'latest' can just be default 'all' ordering
  ];

  @override
  void initState() {
    super.initState();
    // Initial load
    _triggerPostLoad();
  }

  void _triggerPostLoad() {
    // Clear previous vote data when reloading
     // _postVoteData.clear(); // Decide if you want to clear on every refresh/filter change
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      if (_selectedFilter == 'trending') {
        _loadPostsFuture = apiService.fetchTrendingPosts(authProvider.token);
      } else {
        // 'all' and 'latest' use the default fetchPosts endpoint (ordered by latest)
        _loadPostsFuture = apiService.fetchPosts(authProvider.token);
      }
    });
  }


  Future<void> _voteOnPost(ApiService apiService, AuthProvider authProvider, String postId, bool voteType) async {
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar( /* ... */ );
      return;
    }

    final currentVoteData = _postVoteData[postId] ?? {'vote_type': null, 'upvotes': 0, 'downvotes': 0};
    final previousVoteType = currentVoteData['vote_type'];
    final currentUpvotes = currentVoteData['upvotes'];
    final currentDownvotes = currentVoteData['downvotes'];

    // Optimistic UI update
    setState(() {
      final newData = Map<String, dynamic>.from(currentVoteData);
      int newUpvotes = currentUpvotes;
      int newDownvotes = currentDownvotes;

      if (previousVoteType == voteType) { // Undoing vote
        newData['vote_type'] = null;
        if (voteType == true) newUpvotes--; // Decrement upvote
        else newDownvotes--; // Decrement downvote
      } else { // Casting new vote or switching vote
        newData['vote_type'] = voteType;
        if (voteType == true) { // Upvoting
          newUpvotes++;
          if (previousVoteType == false) newDownvotes--; // Switched from downvote
        } else { // Downvoting
          newDownvotes++;
          if (previousVoteType == true) newUpvotes--; // Switched from upvote
        }
      }
       newData['upvotes'] = newUpvotes < 0 ? 0 : newUpvotes; // Ensure non-negative
       newData['downvotes'] = newDownvotes < 0 ? 0 : newDownvotes; // Ensure non-negative
      _postVoteData[postId] = newData;
    });

    try {
      final result = await apiService.vote(postId: int.parse(postId), voteType: voteType, token: authProvider.token!);
      print("Vote API Result: $result");
      // Optional: Update counts from API response if backend sends them back accurately
      // This makes the UI eventually consistent with the backend state.
      // setState(() {
      //    final updatedData = _postVoteData[postId] ?? {};
      //    updatedData['upvotes'] = result['total_upvotes'] ?? updatedData['upvotes']; // Assuming backend returns counts
      //    updatedData['downvotes'] = result['total_downvotes'] ?? updatedData['downvotes'];
      //   _postVoteData[postId] = updatedData;
      // });

    } catch (e) {
      // Revert UI on error
      setState(() {
         final revertedData = Map<String, dynamic>.from(currentVoteData); // Start fresh
         revertedData['vote_type'] = previousVoteType; // Revert vote type
         revertedData['upvotes'] = currentUpvotes; // Revert counts
         revertedData['downvotes'] = currentDownvotes;
         _postVoteData[postId] = revertedData;
      });
      ScaffoldMessenger.of(context).showSnackBar( /* ... Error message ... */ );
    }
  }

  // --- Other methods (_navigateToReplies, _navigateToCreatePost, _deletePost) remain the same ---
  void _navigateToReplies(String postId, String? token) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RepliesScreen(postId: postId)),
    );
  }

  void _navigateToCreatePost(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar( /* ... */ ); return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreatePostScreen()),
    ).then((_) => _triggerPostLoad()); // Refresh on return
  }

   Future<void> _deletePost(String postId, ApiService apiService, AuthProvider authProvider) async {
      if (!authProvider.isAuthenticated) { /* ... */ return; }
       final confirmed = await showDialog<bool>( /* ... */ );
       if (confirmed == true) {
         try {
           await apiService.deletePost(postId, authProvider.token!);
           ScaffoldMessenger.of(context).showSnackBar( /* ... Success ... */);
           _triggerPostLoad(); // Refresh list
         } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar( /* ... Error ... */ );
         }
       }
   }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    final random = math.Random();
    String getRandomTimeAgo() { /* ... */ }

    return Scaffold(
      body: Column(
        children: [
          // Filter tabs
          Container(
             height: 50,
             // ... (Filter Tab UI - Same as before) ...
              child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterTabs.length,
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding),
              itemBuilder: (context, index) {
                final filter = _filterTabs[index];
                final isSelected = _selectedFilter == filter['id'];
                return GestureDetector(
                  onTap: () {
                    if (_selectedFilter != filter['id']) {
                       setState(() { _selectedFilter = filter['id'] as String; });
                       _triggerPostLoad(); // Reload posts when filter changes
                    }
                  },
                  child: Container( /* ... Filter tab styling ... */ ),
                );
              },
            ),
          ),

          // Posts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _triggerPostLoad(),
              child: FutureBuilder<List<dynamic>>(
                future: _loadPostsFuture, // Use the future variable
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingShimmer();
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}')); // Simple error display
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No posts found for "$_selectedFilter".'));
                  }

                  final posts = snapshot.data!;

                   // Initialize vote data for posts if not already present
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                      bool needsSetState = false;
                      for (var post in posts) {
                         final postId = post['id'].toString();
                         if (!_postVoteData.containsKey(postId)) {
                             // TODO: Fetch user's actual vote status for this post from an API endpoint if needed
                             // For now, initialize based on fetched counts (less accurate for UI state)
                            _postVoteData[postId] = {
                               'vote_type': null, // Assume not voted initially, or fetch real status
                               'upvotes': post['upvotes'] ?? 0,
                               'downvotes': post['downvotes'] ?? 0,
                            };
                            needsSetState = true;
                         } else {
                             // Ensure counts are updated from the latest fetch if they changed
                             if (_postVoteData[postId]!['upvotes'] != (post['upvotes'] ?? 0) ||
                                 _postVoteData[postId]!['downvotes'] != (post['downvotes'] ?? 0)) {
                                 _postVoteData[postId]!['upvotes'] = post['upvotes'] ?? 0;
                                 _postVoteData[postId]!['downvotes'] = post['downvotes'] ?? 0;
                                 needsSetState = true;
                             }
                         }
                      }
                      if (needsSetState) {
                          // Avoid calling setState directly in build
                         // Schedule a rebuild if data was initialized/updated
                         // This might cause a flicker, consider a state management solution for votes
                         // setState(() {}); // Be careful with setState in build callbacks
                      }
                   });


                  return ListView.builder(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final postId = post['id'].toString();

                      // Get vote data from the state map
                      final voteData = _postVoteData[postId] ?? {'vote_type': null, 'upvotes': post['upvotes'] ?? 0, 'downvotes': post['downvotes'] ?? 0};
                      final bool hasUpvoted = voteData['vote_type'] == true;
                      final bool hasDownvoted = voteData['vote_type'] == false;
                      final int displayUpvotes = voteData['upvotes'];
                      final int displayDownvotes = voteData['downvotes'];

                      final communityName = post['community_name'] as String?;
                      final communityColor = communityName != null
                          ? communityColors[communityName.hashCode % communityColors.length]
                          : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                        child: PostCard(
                          // ... (other PostCard props) ...
                           title: post['title'] ?? 'No Title',
                           content: post['content'] ?? 'No Content',
                           authorName: post['author_name'] ?? 'Anonymous',
                           authorAvatar: post['author_avatar'], // Backend should provide full URL or path
                           timeAgo: getRandomTimeAgo(), // Replace with actual formatted date
                           upvotes: displayUpvotes,
                           downvotes: displayDownvotes,
                           replyCount: post['reply_count'] ?? 0,
                           hasUpvoted: hasUpvoted,
                           hasDownvoted: hasDownvoted,
                           isOwner: authProvider.isAuthenticated && authProvider.userId == post['user_id'].toString(),
                           communityName: communityName,
                           communityColor: communityColor,

                          onUpvote: () => _voteOnPost(apiService, authProvider, postId, true),
                          onDownvote: () => _voteOnPost(apiService, authProvider, postId, false),
                          onReply: () => _navigateToReplies(postId, authProvider.token),
                          onDelete: () => _deletePost(postId, apiService, authProvider),
                          onTap: () => _navigateToReplies(postId, authProvider.token),
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
        onPressed: () => _navigateToCreatePost(context),
        child: const Icon(Icons.add),
        tooltip: "Create Post",
      ),
    );
  }

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
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
            ),
          ),
        ),
      ),
    );
  }
}
