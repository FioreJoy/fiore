import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/event_api.dart'; // For EventApiService
import '../../../../data/datasources/remote/community_api.dart'; // For CommunityApiService (for suggested)
import '../../../../data/datasources/remote/post_api.dart'; // For PostApiService
import '../../../../data/models/event_model.dart';

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/event_card.dart';
import '../../../global_widgets/post_card.dart';
// import '../../../global_widgets/community_card.dart'; // If suggested communities are added

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String? _error;

  List<EventModel> _upcomingEvents = [];
  List<dynamic> _communityUpdates = [];
  List<dynamic> _followingPosts = [];
  // List<dynamic> _suggestedCommunities = []; // Uncomment if used

  String _selectedFeedFilter = 'discover';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAllFeedData();
    });
  }

  Future<void> _loadAllFeedData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);
    // final communityService = Provider.of<CommunityApiService>(context, listen: false);

    try {
      List<dynamic> fetchedEventsRaw = [];
      if (authProvider.isAuthenticated && authProvider.token != null) {
        try {
          fetchedEventsRaw = await eventService.getCommunityEvents(1,
              token: authProvider.token, limit: 5);
        } catch (e) {
          /* print("HomeFeed: Error fetching initial events: $e"); */
        }
      } else {
        try {
          fetchedEventsRaw = await eventService.getCommunityEvents(1, limit: 5);
        } // Placeholder public events
        catch (e) {/* print("HomeFeed: Error fetching public events: $e"); */}
      }
      _upcomingEvents = fetchedEventsRaw
          .map((data) => EventModel.fromJson(data as Map<String, dynamic>))
          .toList();

      if (authProvider.isAuthenticated && authProvider.token != null) {
        if (_selectedFeedFilter == 'following') {
          _followingPosts = await postService.getFollowingFeed(
              token: authProvider.token!, limit: 10);
          _communityUpdates = [];
        } else {
          _communityUpdates =
              await postService.getPosts(token: authProvider.token, limit: 10);
          _followingPosts = [];
        }
      } else {
        _communityUpdates = await postService.getPosts(limit: 10);
        _followingPosts = [];
      }
      // _suggestedCommunities = await communityService.getTrendingCommunities(token: authProvider.token, limit: 3);

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              "Failed to load feed: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {VoidCallback? onViewAll}) {
    /* ... Unchanged ... */
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
          left: ThemeConstants.mediumPadding,
          right: ThemeConstants.mediumPadding,
          top: ThemeConstants.largePadding,
          bottom: ThemeConstants.smallPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('View All')),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    /* ... Unchanged, imports for EventCard, ThemeConstants are now relative ... */
    if (_isLoading && _upcomingEvents.isEmpty)
      return _buildShimmerSection(
          itemHeight: 220, itemCount: 2, isHorizontal: true);
    if (_upcomingEvents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Upcoming Events', onViewAll: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigate to All Events (TODO)')));
        }),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: ThemeConstants.mediumPadding),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.only(
                      right: ThemeConstants.mediumPadding),
                  child: EventCard(
                    event: event,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tap event: ${event.title}')));
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedPostsSection() {
    /* ... Unchanged, PostCard import updated ... */
    final postsToShow = _selectedFeedFilter == 'following'
        ? _followingPosts
        : _communityUpdates;
    if (_isLoading && postsToShow.isEmpty)
      return _buildShimmerSection(
          itemHeight: 250, itemCount: 3, isHorizontal: false);
    if (postsToShow.isEmpty && !_isLoading)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16),
        child: Center(
          child: Text(
            _selectedFeedFilter == 'following'
                ? 'Follow users or communities to see posts.'
                : 'No posts yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
      );
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.mediumPadding, vertical: 8),
      itemCount: postsToShow.length,
      itemBuilder: (context, index) {
        final post = postsToShow[index] as Map<String, dynamic>;
        final postId =
            post['id']?.toString() ?? 'unknown_post_${post.hashCode}';
        return PostCard(
          postId: postId,
          title: post['title'] ?? 'No Title',
          content: post['content'] ?? '...',
          authorName: post['author_name'],
          authorAvatarUrl: post['author_avatar_url'],
          timeAgo: "some time ago",
          initialUpvotes: post['upvotes'] ?? 0,
          initialDownvotes: post['downvotes'] ?? 0,
          initialReplyCount: post['reply_count'] ?? 0,
          initialFavoriteCount: post['favorite_count'] ?? 0,
          initialHasUpvoted: post['viewer_vote_type'] == 'UP',
          initialHasDownvoted: post['viewer_vote_type'] == 'DOWN',
          initialIsFavorited: post['viewer_has_favorited'] ?? false,
          isOwner: Provider.of<AuthProvider>(context, listen: false).userId ==
              post['user_id']?.toString(),
          communityName: post['community_name'],
          media: post['media'],
          onReply: () {/* Nav */},
          onTap: () {/* Nav */},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAllFeedData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Provider.of<AuthProvider>(context).isAuthenticated)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: ThemeConstants.mediumPadding),
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                          value: 'discover',
                          label: Text('Discover'),
                          icon: Icon(Icons.public_outlined, size: 18)),
                      ButtonSegment<String>(
                          value: 'following',
                          label: Text('Following'),
                          icon: Icon(Icons.rss_feed_outlined, size: 18)),
                    ],
                    selected: {_selectedFeedFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      if (mounted && newSelection.first != _selectedFeedFilter)
                        setState(() {
                          _selectedFeedFilter = newSelection.first;
                          _loadAllFeedData();
                        });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor:
                          ThemeConstants.accentColor.withOpacity(0.2),
                      selectedForegroundColor: ThemeConstants.accentColor,
                      side: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
                    ),
                  ),
                ),
              _buildEventsSection(),
              _buildSectionHeader(
                  context,
                  _selectedFeedFilter == 'following'
                      ? 'From Your Network'
                      : 'Recent Activity'),
              _buildFeedPostsSection(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerSection(
      {required double itemHeight,
      required int itemCount,
      bool isHorizontal = false}) {
    /* ... UI unchanged ... */ final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: isHorizontal
          ? SizedBox(
              height: itemHeight + ThemeConstants.mediumPadding,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: ThemeConstants.mediumPadding,
                    vertical: ThemeConstants.mediumPadding / 2),
                itemCount: itemCount,
                itemBuilder: (context, index) => Container(
                  width: itemHeight * 1.3,
                  margin: const EdgeInsets.only(
                      right: ThemeConstants.mediumPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(ThemeConstants.cardBorderRadius),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                  horizontal: ThemeConstants.mediumPadding, vertical: 8),
              itemCount: itemCount,
              itemBuilder: (context, index) => Container(
                height: itemHeight,
                margin:
                    const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(ThemeConstants.cardBorderRadius),
                ),
              ),
            ),
    );
  }
}
