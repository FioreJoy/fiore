// frontend/lib/screens/feed/home_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // For loading shimmer

// --- Service Imports ---
import '../../services/auth_provider.dart';
import '../../services/api/event_service.dart';
import '../../services/api/community_service.dart';
import '../../services/api/post_service.dart'; // For "Following" feed posts

// --- Model Imports ---
import '../../models/event_model.dart';
// import '../../models/community_model.dart'; // If you have one
// import '../../models/post_model.dart'; // If you have one

// --- Widget Imports ---
import '../../widgets/event_card.dart';
import '../../widgets/post_card.dart'; // Assuming PostCard can be used for community updates
import '../../widgets/community_card.dart'; // For suggested communities
import '../../theme/theme_constants.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  bool _isLoading = true;
  String? _error;

  List<EventModel> _upcomingEvents = [];
  List<dynamic> _communityUpdates = []; // Can be posts or events from joined communities
  List<dynamic> _followingPosts = [];   // Posts from followed users
  List<dynamic> _suggestedCommunities = [];

  // Selected feed filter
  String _selectedFeedFilter = 'discover'; // 'discover', 'following'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAllFeedData();
      }
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
    // final communityService = Provider.of<CommunityService>(context, listen: false);

    try {
      // --- Fetch Data (Parallelize if possible) ---
      // For now, sequential fetching
      List<dynamic> fetchedEventsRaw = [];
      // Example: Fetch a few nearby events if location is available, or just upcoming from joined communities
      // This is a simplified placeholder, real logic would be more complex.
      // For "Home", we might show events the user has joined or that are upcoming in their communities.
      // Using a generic endpoint for now if it exists, or a specific "my upcoming events" if available.
      // As a placeholder, let's assume getCommunityEvents for a default community or a "my events" endpoint
      if (authProvider.isAuthenticated && authProvider.token != null) {
        // This is a placeholder. Ideally, you'd have an endpoint for "my relevant events"
        // For now, let's try to fetch from a known community or a general "all" list.
        // Replace '1' with a dynamic community ID or use a different endpoint.
        try {
          fetchedEventsRaw = await eventService.getCommunityEvents(1, token: authProvider.token, limit: 5);
        } catch (e) {
          print("HomeFeed: Error fetching initial events: $e");
          // Fallback or ignore
        }
      } else {
         // For unauthenticated users, maybe show popular/general events.
         // Using placeholder getCommunityEvents for now.
        try {
            fetchedEventsRaw = await eventService.getCommunityEvents(1, limit: 5);
        } catch (e) {
            print("HomeFeed: Error fetching public events: $e");
        }
      }
      _upcomingEvents = fetchedEventsRaw.map((data) => EventModel.fromJson(data as Map<String, dynamic>)).toList();


      // Placeholder for Community Updates & Following Posts (depends on feed filter)
      if (authProvider.isAuthenticated && authProvider.token != null) {
          if (_selectedFeedFilter == 'following') {
            _followingPosts = await postService.getFollowingFeed(token: authProvider.token!, limit: 10);
            _communityUpdates = []; // Clear other if showing specific feed
          } else { // 'discover' or other general feed
            // Placeholder: Fetch recent posts from a general endpoint or joined communities
            _communityUpdates = await postService.getPosts(token: authProvider.token, limit: 10); // General discover for now
            _followingPosts = [];
          }
      } else {
        // Unauthenticated: Show general discover posts
         _communityUpdates = await postService.getPosts(limit: 10);
         _followingPosts = [];
      }


      // Placeholder for Suggested Communities
      // _suggestedCommunities = await communityService.getTrendingCommunities(token: authProvider.token, limit: 3);

      if (!mounted) return;
      setState(() => _isLoading = false);

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load feed: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onViewAll}) {
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
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('View All')),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    if (_isLoading && _upcomingEvents.isEmpty) {
      return _buildShimmerSection(itemHeight: 220, itemCount: 2, isHorizontal: true);
    }
    if (_upcomingEvents.isEmpty) {
      return const SizedBox.shrink(); // Or a "No upcoming events" message
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Upcoming Events', onViewAll: () {
          // TODO: Navigate to full events list screen
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to All Events (TODO)')));
        }),
        SizedBox(
          height: 260, // Adjust height for EventCard
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return SizedBox(
                width: 300, // Width for EventCard
                child: Padding(
                  padding: const EdgeInsets.only(right: ThemeConstants.mediumPadding),
                  child: EventCard(
                    event: event,
                    onTap: () {
                      // TODO: Navigate to event detail
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tap event: ${event.title}')));
                    },
                    // onJoinLeave: () => _handleJoinLeaveEvent(event), // Implement join/leave
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
    final postsToShow = _selectedFeedFilter == 'following' ? _followingPosts : _communityUpdates;

    if (_isLoading && postsToShow.isEmpty) {
      return _buildShimmerSection(itemHeight: 250, itemCount: 3, isHorizontal: false);
    }
    if (postsToShow.isEmpty && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16),
        child: Center(
          child: Text(
            _selectedFeedFilter == 'following'
                ? 'Follow some users or communities to see their posts here.'
                : 'No posts to show in this feed yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(), // Handled by outer SingleChildScrollView
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 8),
      itemCount: postsToShow.length,
      itemBuilder: (context, index) {
        final post = postsToShow[index] as Map<String, dynamic>;
        final postId = post['id']?.toString() ?? 'unknown_post_${post.hashCode}';
        // Simplified PostCard usage, assuming it handles nulls gracefully
        return PostCard(
          postId: postId,
          title: post['title'] ?? 'No Title',
          content: post['content'] ?? '...',
          authorName: post['author_name'],
          authorAvatarUrl: post['author_avatar_url'],
          timeAgo: "some time ago", // TODO: Format time properly for posts
          initialUpvotes: post['upvotes'] ?? 0,
          initialDownvotes: post['downvotes'] ?? 0,
          initialReplyCount: post['reply_count'] ?? 0,
          initialFavoriteCount: post['favorite_count'] ?? 0,
          initialHasUpvoted: post['viewer_vote_type'] == 'UP',
          initialHasDownvoted: post['viewer_vote_type'] == 'DOWN',
          initialIsFavorited: post['viewer_has_favorited'] ?? false,
          isOwner: Provider.of<AuthProvider>(context, listen: false).userId == post['user_id']?.toString(),
          communityName: post['community_name'],
          media: post['media'],
          onReply: () { /* TODO: Navigate to replies */ },
          onTap: () { /* TODO: Navigate to post detail or replies */ },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // AppBar is handled by MainNavigationScreen for this tab
      body: RefreshIndicator(
        onRefresh: _loadAllFeedData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feed Filter (Discover / Following)
              if (Provider.of<AuthProvider>(context).isAuthenticated) // Show only if logged in
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: ThemeConstants.mediumPadding),
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'discover', label: Text('Discover'), icon: Icon(Icons.public_outlined, size: 18)),
                      ButtonSegment<String>(value: 'following', label: Text('Following'), icon: Icon(Icons.rss_feed_outlined, size: 18)),
                    ],
                    selected: {_selectedFeedFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      if (mounted && newSelection.first != _selectedFeedFilter) {
                        setState(() {
                          _selectedFeedFilter = newSelection.first;
                          _loadAllFeedData(); // Reload data based on new filter
                        });
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: ThemeConstants.accentColor.withOpacity(0.2),
                      selectedForegroundColor: ThemeConstants.accentColor,
                      side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                  ),
                ),

              _buildEventsSection(), // Events first

              // Community Updates or Following Feed Section Header
              _buildSectionHeader(context, _selectedFeedFilter == 'following' ? 'From Your Network' : 'Recent Activity'),
              _buildFeedPostsSection(), // Display posts based on filter

              // TODO: Suggested Communities Section (if needed)
              // _buildSectionHeader(context, 'Discover Communities'),
              // ... CommunityCard list ...

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerSection({required double itemHeight, required int itemCount, bool isHorizontal = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: isHorizontal
          ? SizedBox(
              height: itemHeight + ThemeConstants.mediumPadding, // Account for padding
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: ThemeConstants.mediumPadding / 2),
                itemCount: itemCount,
                itemBuilder: (context, index) => Container(
                  width: itemHeight * 1.3, // Aspect ratio for horizontal cards
                  margin: const EdgeInsets.only(right: ThemeConstants.mediumPadding),
                  decoration: BoxDecoration(
                    color: Colors.white, // Base for shimmer
                    borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 8),
              itemCount: itemCount,
              itemBuilder: (context, index) => Container(
                height: itemHeight,
                margin: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                decoration: BoxDecoration(
                  color: Colors.white, // Base for shimmer
                  borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                ),
              ),
            ),
    );
  }
}
