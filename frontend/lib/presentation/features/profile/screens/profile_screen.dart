import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/user_api.dart'; // For UserApiService
// EventModel is used if we list events directly without a specific event card context
import '../../../../data/models/event_model.dart';

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
// Profile-specific widgets
import '../widgets/profile_header.dart';
import '../widgets/profile_content_tab.dart';
import '../widgets/profile_loading_shimmer.dart';
import '../widgets/profile_error_view.dart';
// Global widgets for list items
import '../../../global_widgets/post_card.dart';
import '../../../global_widgets/community_card.dart';
import '../../../global_widgets/event_card.dart';

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';
// AppConstants for default avatar used in ProfileHeader if imageUrl is null

// --- Screen Imports for Navigation ---
import '../../settings/screens/settings_home_screen.dart';
import '../../settings/screens/account/edit_profile.dart'; // Updated path for EditProfileScreen
import '../../replies/screens/replies_screen.dart'; // Corrected Path
import '../../communities/screens/community_detail_screen.dart';

// Typedef for UserApiService (assuming it's defined elsewhere, like main.dart)
typedef UserApiService = UserService;

class ProfileScreen extends StatefulWidget {
  final String? userIdToView;
  const ProfileScreen({Key? key, this.userIdToView}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
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

  String get _profileUserId =>
      widget.userIdToView ?? Provider.of<AuthProvider>(context, listen: false).userId ?? '';
  bool get _isMyProfile =>
      widget.userIdToView == null ||
          widget.userIdToView == Provider.of<AuthProvider>(context, listen: false).userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfileData();
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(dateTimeString).toLocal()); }
    catch (e) { return 'Invalid Date'; }
  }

  String _formatLocation(dynamic locationData, String? address) {
    if (address != null && address.isNotEmpty) return address;
    if (locationData is Map) {
      final lon = locationData['longitude']; final lat = locationData['latitude'];
      if (lon is num && lat is num && (lon != 0 || lat != 0)) return '(${lon.toStringAsFixed(2)}, ${lat.toStringAsFixed(2)})';
    } else if (locationData is String && locationData.isNotEmpty && locationData != '(0,0)' && locationData != '(0.0,0.0)') {
      return locationData;
    }
    return 'Location not set';
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final targetUserIdStr = _profileUserId;
    if (targetUserIdStr.isEmpty && _isMyProfile) { setState(() { _isLoadingProfile = false; _errorProfile = "Not authenticated."; }); return; }
    if (targetUserIdStr.isEmpty && !_isMyProfile) { setState(() { _isLoadingProfile = false; _errorProfile = "User ID not provided."; }); return; }
    final targetUserId = int.tryParse(targetUserIdStr);
    if (targetUserId == null) { setState(() { _isLoadingProfile = false; _errorProfile = "Invalid User ID format."; }); return; }

    setState(() { _isLoadingProfile = true; _errorProfile = null; });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userService = Provider.of<UserApiService>(context, listen: false);

    try {
      final data = await userService.getUserProfile(targetUserId, token: authProvider.token);
      if (!mounted) return;
      setState(() {
        _userData = data; _isLoadingProfile = false; _isFollowing = data['is_following'] ?? false;
      });
      _loadTabContent(targetUserId, authProvider.token); // Load tab content after profile header data is fetched
    } catch (e) {
      if (mounted) {
        setState(() { _errorProfile = "Failed to load profile: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoadingProfile = false; });
      }
    }
  }

  Future<void> _loadTabContent(int targetUserId, String? token) async {
    if (!mounted) return;
    setState(() => _isLoadingContent = true);
    final userService = Provider.of<UserApiService>(context, listen: false);

    try {
      final posts = await userService.getUserPosts(targetUserId, token: token, limit: 20);

      List<dynamic> communities = [];
      List<dynamic> events = [];

      if (_isMyProfile && token != null) {
        // Only fetch joined communities and events if it's the current user's profile
        // and they are authenticated.
        communities = await userService.getMyJoinedCommunities(token, limit: 20);
        events = await userService.getMyJoinedEvents(token, limit: 20);
      } else if (!_isMyProfile && token != null) {
        // Fetch *other* user's publicly visible or joined communities/events (if backend supports)
        // Assuming backend /users/{id}/communities and /users/{id}/events exists for this
        // If not, these will be empty lists for now.
        try {
          communities = await userService.getUserCommunities(targetUserId, token: token, limit: 20);
        } catch (e) {
          // print("Failed to get communities for user $targetUserId: $e"); // Debug removed
          communities = []; // Default to empty on error
        }
        try {
          events = await userService.getUserEvents(targetUserId, token: token, limit: 20);
        } catch (e) {
          // print("Failed to get events for user $targetUserId: $e"); // Debug removed
          events = []; // Default to empty on error
        }
      } else {
        // Unauthenticated view of someone else's profile, or self-view while unauth'd (though this path less likely for _isMyProfile case)
        // Fetch public posts, communities/events would depend on public endpoints (not assumed here)
        // For now, keep communities/events empty if not self & unauth'd.
        // print("ProfileScreen: Viewing other user or unauthenticated self. Endpoints for their communities/events not targeted or requires auth."); // Debug removed
      }

      if (!mounted) return;
      setState(() {
        _userPosts = posts;
        _userCommunities = communities;
        _userEvents = events;
        _isLoadingContent = false;
        _errorContent = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorContent = "Failed to load profile content: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoadingContent = false;
        });
      }
    }
  }


  Future<void> _toggleFollow() async { /* ... unchanged, UserApiService correctly imported/used ... */ if (_isFollowActionLoading || !mounted || _isMyProfile) return; final userService = Provider.of<UserApiService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false); final targetUserIdStr = _profileUserId; final targetUserId = int.tryParse(targetUserIdStr); if (!authProvider.isAuthenticated || authProvider.token == null || targetUserId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.'))); return; } setState(() => _isFollowActionLoading = true); final previousIsFollowing = _isFollowing; setState(() => _isFollowing = !_isFollowing); try { Map<String, dynamic> response; if (_isFollowing) response = await userService.followUser(authProvider.token!, targetUserId); else response = await userService.unfollowUser(authProvider.token!, targetUserId); if (mounted && _userData != null && response['new_follower_count'] != null) setState(() => _userData!['followers_count'] = response['new_follower_count']); } catch (e) { if (mounted) { setState(() => _isFollowing = previousIsFollowing); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor)); } } finally { if (mounted) setState(() => _isFollowActionLoading = false); } }
  void _navigateToSettings() { Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsHomeScreen())).then((_) { if(mounted) _loadProfileData(); }); }
  void _navigateToEditProfile() async { final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())); if (result == true && mounted) _loadProfileData(); }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingProfile) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: ProfileLoadingShimmer(isDark: isDark));
    if (_errorProfile != null) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: ProfileErrorView(message: _errorProfile!, isDark: isDark, onRetry: _loadProfileData));
    if (_userData == null) return Scaffold(appBar: AppBar(title: Text(_isMyProfile ? 'My Profile' : (_userData?['name'] ?? 'User Profile'))), body: ProfileErrorView(message: "Profile data unavailable.", isDark: isDark, onRetry: _loadProfileData));

    final String name = _userData!['name'] ?? 'User';
    final String username = _userData!['username'] ?? 'username';
    final String? imageUrl = _isMyProfile ? context.watch<AuthProvider>().userImageUrl : _userData!['image_url'];
    final int followersCount = _userData!['followers_count'] ?? 0;
    final int followingCount = _userData!['following_count'] ?? 0;

    return DefaultTabController( length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber( handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  title: Text(innerBoxIsScrolled ? name : '', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  expandedHeight: 290.0, floating: false, pinned: true, stretch: true,
                  backgroundColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  elevation: innerBoxIsScrolled ? 2.0 : 0.0,
                  flexibleSpace: FlexibleSpaceBar( collapseMode: CollapseMode.pin,
                    background: ProfileHeader(
                      profileUserId: _profileUserId, name: name, username: username, imageUrl: imageUrl,
                      followersCount: followersCount, followingCount: followingCount, isMyProfile: _isMyProfile,
                      isFollowingViewer: _isFollowing, isFollowActionLoading: _isFollowActionLoading,
                      onEditProfile: _navigateToEditProfile, onToggleFollow: _toggleFollow,
                    ),),
                  actions: [ if (_isMyProfile) IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: _navigateToSettings)
                  else PopupMenuButton<String>( icon: const Icon(Icons.more_vert_outlined), onSelected: (value) { /* Handle block/report */ }, itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[ const PopupMenuItem<String>(value: 'block', child: Text('Block User')), const PopupMenuItem<String>(value: 'report', child: Text('Report User', style: TextStyle(color: ThemeConstants.errorColor))), ], ), ],
                  bottom: TabBar( controller: _tabController, labelColor: theme.colorScheme.primary, unselectedLabelColor: Colors.grey.shade500, indicatorColor: theme.colorScheme.primary, indicatorWeight: 2.5,
                    tabs: const [ Tab(text: 'Posts'), Tab(text: 'Communities'), Tab(text: 'Activity') ],),),),];},
          body: TabBarView( controller: _tabController,
            children: [
              ProfileContentTab(isLoading: _isLoadingContent, error: _errorContent, items: _userPosts, emptyMessage: 'No posts to show.', itemBuilder: _buildPostItem, tabKey: 'profile_posts', onRetry: () => _loadTabContent(int.parse(_profileUserId), context.read<AuthProvider>().token)),
              ProfileContentTab(isLoading: _isLoadingContent, error: _errorContent, items: _userCommunities, emptyMessage: _isMyProfile ? 'You haven\'t joined any communities.' : '$name is not part of any communities.', itemBuilder: _buildCommunityItem, tabKey: 'profile_communities', onRetry: () => _loadTabContent(int.parse(_profileUserId), context.read<AuthProvider>().token)),
              ProfileContentTab(isLoading: _isLoadingContent, error: _errorContent, items: _userEvents, emptyMessage: _isMyProfile ? 'No upcoming events or activity.' : '$name has no recent activity.', itemBuilder: _buildEventItem, tabKey: 'profile_activity', onRetry: () => _loadTabContent(int.parse(_profileUserId), context.read<AuthProvider>().token)),
            ],),),),);
  }

  Widget _buildPostItem(BuildContext context, Map<String, dynamic> post) { /* ... logic to build PostCard, unchanged path-wise */
    final postId = post['id']?.toString() ?? 'unknown_post_${post.hashCode}'; final String postAuthorId = post['user_id']?.toString() ?? '';
    final String authorName = post['author_name'] ?? _userData?['username'] ?? 'Anonymous'; final String? authorAvatarUrl = post['author_avatar_url'] ?? (_isMyProfile ? context.read<AuthProvider>().userImageUrl : _userData?['image_url']);
    return Padding( padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding / 2),
      child: PostCard(
        key: ValueKey('profile_post_$postId'), postId: postId, title: post['title'] ?? 'No Title', content: post['content'] ?? '...', authorName: authorName, authorAvatarUrl: authorAvatarUrl, timeAgo: _formatDateTime(post['created_at'] as String?),
        initialUpvotes: post['upvotes'] ?? 0, initialDownvotes: post['downvotes'] ?? 0, initialReplyCount: post['reply_count'] ?? 0, initialFavoriteCount: post['favorite_count'] ?? 0,
        initialHasUpvoted: post['viewer_vote_type'] == 'UP', initialHasDownvoted: post['viewer_vote_type'] == 'DOWN', initialIsFavorited: post['viewer_has_favorited'] ?? false,
        isOwner: _isMyProfile && postAuthorId == _profileUserId, communityName: post['community_name'] as String?, media: post['media'] as List<dynamic>?,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepliesScreen(postId: postId, postTitle: post['title']))),
        onReply: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepliesScreen(postId: postId, postTitle: post['title']))),
        onDelete: (_isMyProfile && postAuthorId == _profileUserId) ? () { /* TODO: Call delete post */ print("Delete post $postId from profile (TODO)");} : null,
      ),);
  }
  Widget _buildCommunityItem(BuildContext context, Map<String, dynamic> community) { /* ... logic to build CommunityCard, unchanged path-wise ... */
    final communityId = community['id']?.toString() ?? 'unknown_comm_${community.hashCode}';
    return Padding( padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: CommunityCard( key: ValueKey('profile_comm_$communityId'), name: community['name'] ?? 'Unnamed Community', memberCount: community['member_count'] ?? 0, onlineCount: community['online_count'] ?? 0, logoUrl: community['logo_url'] as String?, description: community['description'] as String?,
        backgroundColor: ThemeConstants.communityColors[community['id'].hashCode % ThemeConstants.communityColors.length], isJoined: community['is_member_by_viewer'] ?? _isMyProfile,
        onJoin: () { print("Join/Leave ${community['name']} from profile");},
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDetailScreen( communityData: community, initialIsJoined: community['is_member_by_viewer'] ?? _isMyProfile, onToggleJoin: (id, currentStatus) async { return {'statusChanged': false, 'isJoined': currentStatus}; }))),
      ),);
  }
  Widget _buildEventItem(BuildContext context, Map<String, dynamic> eventData) { /* ... logic to build EventCard, unchanged path-wise ... */
    try { final event = EventModel.fromJson(eventData); return Padding( padding: const EdgeInsets.symmetric(vertical: 4.0), child: EventCard( key: ValueKey('profile_event_${event.id}'), event: event, onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tapped event: ${event.title}"))); }, ),);
    } catch (e) { return ListTile(title: Text("Error displaying event: $e", style: const TextStyle(color: Colors.redAccent))); }
  }
}