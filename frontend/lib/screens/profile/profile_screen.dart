// frontend/lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../../services/api/user_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_card.dart';
import '../../widgets/event_card.dart';
import '../../models/event_model.dart';
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';
import '../settings/settings_home_screen.dart';
import '../settings/settings_feature/account/edit_profile.dart';
import '../replies_screen.dart';
// Import detail screens for navigation from tabs
import '../communities/community_detail_screen.dart';
// import '../events/event_detail_screen.dart'; // Assuming you will create this

class ProfileScreen extends StatefulWidget {
  final String? userIdToView;
  const ProfileScreen({ Key? key, this.userIdToView }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  bool _isLoadingProfile = true;
  Map<String, dynamic>? _userData;
  String? _errorProfile;

  bool _isLoadingContent = true;
  String? _errorContent;
  List<dynamic> _userPosts = [];
  List<dynamic> _userCommunities = [];
  List<dynamic> _userEvents = [];

  bool _isFollowing = false;
  bool _isFollowActionLoading = false;

  String get _profileUserId => widget.userIdToView ?? Provider.of<AuthProvider>(context, listen: false).userId ?? '';
  bool get _isMyProfile => widget.userIdToView == null || widget.userIdToView == Provider.of<AuthProvider>(context, listen: false).userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) _loadProfileData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(String? dateTimeString) { if (dateTimeString == null) return 'some time ago'; try { final dateTime = DateTime.parse(dateTimeString).toLocal(); final now = DateTime.now(); final difference = now.difference(dateTime); if (difference.inSeconds < 60) return '${difference.inSeconds}s ago'; if (difference.inMinutes < 60) return '${difference.inMinutes}m ago'; if (difference.inHours < 24) return '${difference.inHours}h ago'; if (difference.inDays < 7) return '${difference.inDays}d ago'; return DateFormat('MMM d, yyyy').format(dateTime); } catch (e) { return 'a while ago'; } }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final targetUserIdStr = _profileUserId;
    if (targetUserIdStr.isEmpty && _isMyProfile) { setState(() { _isLoadingProfile = false; _errorProfile = "Not authenticated."; }); return; }
    else if (targetUserIdStr.isEmpty && !_isMyProfile) { setState(() { _isLoadingProfile = false; _errorProfile = "User ID not provided."; }); return; }
    final targetUserId = int.tryParse(targetUserIdStr);
    if (targetUserId == null) { setState(() { _isLoadingProfile = false; _errorProfile = "Invalid User ID format."; }); return; }
    setState(() { _isLoadingProfile = true; _errorProfile = null; });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      final data = await userService.getUserProfile(targetUserId, token: authProvider.token);
      if (!mounted) return;
      setState(() { _userData = data; _isLoadingProfile = false; _isFollowing = data['is_following'] ?? false; });
      _loadTabContent(targetUserId, authProvider.token);
    } catch (e) { if (mounted) setState(() { _errorProfile = "Failed to load profile: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoadingProfile = false; }); }
  }

  Future<void> _loadTabContent(int targetUserId, String? token) async {
    if (!mounted) return;
    setState(() => _isLoadingContent = true);
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      final results = await Future.wait([
        userService.getUserPosts(targetUserId, token: token, limit: 20), // Backend: /users/{id}/posts
        // For communities and events for *other* users, we need specific backend endpoints
        // GET /users/{id}/communities and GET /users/{id}/events
        // If it's "my profile", use the "me" endpoints.
        _isMyProfile && token != null ? userService.getMyJoinedCommunities(token, limit: 20) : Future.value([]), // Placeholder if viewing others
        _isMyProfile && token != null ? userService.getMyJoinedEvents(token, limit: 20) : Future.value([]), // Placeholder if viewing others
      ]);
      if (!mounted) return;
      setState(() {
        _userPosts = results[0];
        _userCommunities = results[1];
        _userEvents = results[2];
        _isLoadingContent = false; _errorContent = null;
      });
    } catch (e) {
      if (mounted) setState(() { _errorContent = "Failed to load content: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoadingContent = false;});
    }
  }

  Future<void> _toggleFollow() async { /* ... unchanged ... */ if (_isFollowActionLoading || !mounted || _isMyProfile) return; final userService = Provider.of<UserService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false); final targetUserIdStr = _profileUserId; final targetUserId = int.tryParse(targetUserIdStr); if (!authProvider.isAuthenticated || authProvider.token == null || targetUserId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.'))); return; } setState(() => _isFollowActionLoading = true); final previousIsFollowing = _isFollowing; setState(() => _isFollowing = !_isFollowing); try { Map<String, dynamic> response; if (_isFollowing) response = await userService.followUser(authProvider.token!, targetUserId); else response = await userService.unfollowUser(authProvider.token!, targetUserId); if (mounted && _userData != null && response['new_follower_count'] != null) { setState(() => _userData!['followers_count'] = response['new_follower_count']); } } catch (e) { if (mounted) { setState(() => _isFollowing = previousIsFollowing); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor)); } } finally { if (mounted) setState(() => _isFollowActionLoading = false); } }
  void _navigateToSettings() { /* ... unchanged ... */ Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsHomeScreen())).then((_) => _loadProfileData()); }
  void _navigateToEditProfile() async { /* ... unchanged ... */ final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())); if (result == true && mounted) _loadProfileData(); }
  String _formatDateTime(String? dateTimeString) { /* ... unchanged ... */ if (dateTimeString == null) return 'N/A'; try { return DateFormat('MMM d, yyyy').format(DateTime.parse(dateTimeString).toLocal()); } catch (e) { return 'Invalid Date'; } }
  String _formatLocation(dynamic locationData, String? address) { /* ... unchanged ... */ if (address != null && address.isNotEmpty) return address; if (locationData is Map) { final lon = locationData['longitude']; final lat = locationData['latitude']; if (lon is num && lat is num && (lon != 0 || lat != 0)) return '(${lon.toStringAsFixed(2)}, ${lat.toStringAsFixed(2)})'; } else if (locationData is String && locationData.isNotEmpty && locationData != '(0,0)' && locationData != '(0.0,0.0)') return locationData; return 'Location not set'; }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingProfile || _tabController == null) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: _buildLoadingShimmer(isDark));
    if (_errorProfile != null) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: _buildErrorView(_errorProfile!, isDark));
    if (_userData == null) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: _buildErrorView("Profile data not available.", isDark));

    final String name = _userData!['name'] ?? 'User';
    final String username = _userData!['username'] ?? 'username';
    final String? imageUrl = _isMyProfile ? context.watch<AuthProvider>().userImageUrl : _userData!['image_url'];
    final int followersCount = _userData!['followers_count'] ?? 0;
    final int followingCount = _userData!['following_count'] ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  title: Text(innerBoxIsScrolled ? name : '', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  expandedHeight: 290.0, // Adjusted slightly
                  floating: false, pinned: true, stretch: true,
                  backgroundColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  elevation: innerBoxIsScrolled ? 2.0 : 0.0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _buildProfileHeader(name, username, imageUrl, followersCount, followingCount, isDark, theme),
                  ),
                  actions: [ /* ... actions unchanged ... */ if (_isMyProfile) IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: _navigateToSettings) else PopupMenuButton<String>( icon: const Icon(Icons.more_vert_outlined), onSelected: (value) { if (value == 'block') { print("Block user action");} else if (value == 'report') {print("Report user action"); } }, itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[ const PopupMenuItem<String>(value: 'block', child: Text('Block User')), const PopupMenuItem<String>(value: 'report', child: Text('Report User', style: TextStyle(color: ThemeConstants.errorColor))), ], ), ],
                  bottom: TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary, unselectedLabelColor: Colors.grey.shade500,
                    indicatorColor: theme.colorScheme.primary, indicatorWeight: 2.5,
                    tabs: const [ Tab(text: 'Posts'), Tab(text: 'Communities'), Tab(text: 'Activity') ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildContentTab(_userPosts, 'No posts to show.', 'Posts', theme, isDark, (item) => _buildPostItem(item, theme, isDark)),
              _buildContentTab(_userCommunities, _isMyProfile ? 'You haven\'t joined any communities yet.' : '$name is not part of any communities yet.', 'Communities', theme, isDark, (item) => _buildCommunityItem(item, theme, isDark)),
              _buildContentTab(_userEvents, _isMyProfile ? 'No upcoming events or activity.' : '$name has no upcoming events or activity.', 'Activity', theme, isDark, (item) => _buildEventItem(item, theme, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, String username, String? imageUrl, int followers, int following, bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight * 0.1, // Adjusted for status bar & some appbar
        left: 20, right: 20,
        bottom: kTextTabBarHeight + 20, // Enough space for TabBar below
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [ThemeConstants.backgroundDark.withOpacity(0.6), ThemeConstants.backgroundDarker.withOpacity(0.4)] : [Colors.blueGrey.shade50.withOpacity(0.7), Colors.grey.shade50.withOpacity(0.1)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        // Removed MainAxisSize.min to allow Column to fill available vertical space from FlexibleSpaceBar
        children: [
          Hero(
            tag: 'profile_avatar_$_profileUserId',
            child: CircleAvatar(radius: 45, backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200, backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider),
          ),
          const SizedBox(height: 10),
          Text(name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,),
          Text("@$username", style: theme.textTheme.titleSmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildHeaderStat(followers.toString(), "Followers", isDark, theme),
            Container(height: 20, width: 1, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _buildHeaderStat(following.toString(), "Following", isDark, theme),
          ]),
          const SizedBox(height: 12),
          if (_isMyProfile) SizedBox(width: 170, child: CustomButton(text: 'Edit Profile', onPressed: _navigateToEditProfile, type: ButtonType.outline, padding: const EdgeInsets.symmetric(vertical: 8), icon: Icons.edit_outlined, fontSize: 13))
          else if (Provider.of<AuthProvider>(context, listen: false).isAuthenticated)
            SizedBox(width: 170, child: CustomButton(text: _isFollowing ? 'Unfollow' : 'Follow', onPressed: _toggleFollow, isLoading: _isFollowActionLoading, type: _isFollowing ? ButtonType.outline : ButtonType.primary, padding: const EdgeInsets.symmetric(vertical: 8), icon: _isFollowing ? Icons.person_remove_outlined : Icons.person_add_alt_1, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, bool isDark, ThemeData theme) { /* ... unchanged ... */ return Column(mainAxisSize: MainAxisSize.min, children: [ Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)), ]); }

  Widget _buildContentTab(List<dynamic> items, String emptyMessage, String itemTypeForError, ThemeData theme, bool isDark, Widget Function(Map<String, dynamic>) itemBuilder) {
    return SafeArea(top: false, bottom: false,
      child: Builder(
        builder: (BuildContext context) {
          return CustomScrollView(
            key: PageStorageKey<String>(itemTypeForError),
            slivers: <Widget>[
              SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
              if (_isLoadingContent)
                const SliverFillRemaining(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())))
              else if (_errorContent != null)
                SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error loading $itemTypeForError: $_errorContent", style: TextStyle(color: Colors.redAccent), textAlign: TextAlign.center,))))
              else if (items.isEmpty)
                  SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text(emptyMessage, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center,))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(8.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) => itemBuilder(items[index] as Map<String, dynamic>),
                        childCount: items.length,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, ThemeData theme, bool isDark) {
    final postId = post['id']?.toString() ?? 'unknown_post_${post.hashCode}';
    final String postAuthorId = post['user_id']?.toString() ?? '';
    // For posts listed on a user's profile, the author of the post is the profile user.
    // If posts data includes its own distinct author_name and author_avatar_url, use those.
    // Otherwise, fall back to the profile user's data.
    final String authorName = post['author_name'] ?? _userData?['username'] ?? 'Anonymous';
    final String? authorAvatarUrl = post['author_avatar_url'] ?? (_isMyProfile ? context.read<AuthProvider>().userImageUrl : _userData?['image_url']);

    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding / 2),
      child: PostCard(
        key: ValueKey('profile_post_$postId'), // Unique key
        postId: postId,
        title: post['title'] ?? 'No Title',
        content: post['content'] ?? '...',
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        timeAgo: _formatTimeAgo(post['created_at'] as String?),
        initialUpvotes: post['upvotes'] ?? 0,
        initialDownvotes: post['downvotes'] ?? 0,
        initialReplyCount: post['reply_count'] ?? 0,
        initialFavoriteCount: post['favorite_count'] ?? 0,
        initialHasUpvoted: post['viewer_vote_type'] == 'UP',
        initialHasDownvoted: post['viewer_vote_type'] == 'DOWN',
        initialIsFavorited: post['viewer_has_favorited'] ?? false,
        isOwner: _isMyProfile && postAuthorId == _profileUserId, // A post is owned if profile is mine AND post author is me
        communityName: post['community_name'] as String?,
        media: post['media'] as List<dynamic>?,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepliesScreen(postId: postId, postTitle: post['title']))),
        onReply: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepliesScreen(postId: postId, postTitle: post['title']))),
        onDelete: (_isMyProfile && postAuthorId == _profileUserId) ? () { /* TODO: Call delete post service */ print("Delete post $postId");} : null,
      ),
    );
  }

  Widget _buildCommunityItem(Map<String, dynamic> community, ThemeData theme, bool isDark) {
    final communityId = community['id']?.toString() ?? 'unknown_comm_${community.hashCode}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: CommunityCard(
        key: ValueKey('profile_comm_$communityId'), // Unique key
        name: community['name'] ?? 'Unnamed Community',
        memberCount: community['member_count'] ?? 0,
        onlineCount: community['online_count'] ?? 0,
        logoUrl: community['logo_url'] as String?,
        description: community['description'] as String?,
        backgroundColor: ThemeConstants.communityColors[community['id'].hashCode % ThemeConstants.communityColors.length],
        // is_member_by_viewer might not be present if fetching general user's communities.
        // Assume true if it's my profile's joined communities.
        isJoined: community['is_member_by_viewer'] ?? _isMyProfile,
        onJoin: () {
          // This would require a more complex state update or passing a callback from a parent list.
          print("Join/Leave community ${community['name']} from profile (not fully implemented here)");
        },
        onTap: () {
          // Navigate to CommunityDetailScreen
          Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDetailScreen(
              communityData: community,
              initialIsJoined: community['is_member_by_viewer'] ?? _isMyProfile,
              onToggleJoin: (id, currentStatus) async {
                // This is a simplified version. Ideally, the ProfileScreen would manage this state update.
                print("Toggle join for $id from profile's community card");
                // You'd call a service here and then potentially refresh _userCommunities
                return {'statusChanged': false, 'isJoined': currentStatus}; // Placeholder
              }
          )));
        },
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> eventData, ThemeData theme, bool isDark) {
    try {
      final event = EventModel.fromJson(eventData);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: EventCard(
          key: ValueKey('profile_event_${event.id}'), // Unique key
          event: event,
          onTap: () {
            // TODO: Navigate to EventDetailScreen(event: event)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tapped event: ${event.title}")));
          },
          // onJoinLeave: () { /* Handle join/leave for event from profile */ }
        ),
      );
    } catch (e) { return ListTile(title: Text("Error displaying event: $e", style: TextStyle(color: Colors.redAccent))); }
  }

  Widget _buildLoadingShimmer(bool isDark) { /* ... unchanged ... */ final base = isDark?Colors.grey[800]!:Colors.grey[300]!; final high = isDark?Colors.grey[700]!:Colors.grey[100]!; return Shimmer.fromColors(baseColor: base, highlightColor: high, child: Column(children: [ Container(height: 290, color: Colors.white), Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [ Row(children: List.generate(3, (_) => Expanded(child: Container(height: 70, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))))), const SizedBox(height: 24), Container(height: 20, width: 100, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), Container(height: 16, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), ]))]));}
  Widget _buildErrorView(String message, bool isDark) { /* ... unchanged ... */ return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.error_outline_rounded, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)), const SizedBox(height: 24), CustomButton( text: 'Retry', icon: Icons.refresh_rounded, onPressed: _loadProfileData, type: ButtonType.secondary,), ],),),); }
  Widget _buildNotLoggedInView(bool isDark) { /* ... unchanged ... */ return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.person_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400), const SizedBox(height: 20), Text('Please log in to view your profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)), const SizedBox(height: 24), ElevatedButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Log In')) ]))); }

}