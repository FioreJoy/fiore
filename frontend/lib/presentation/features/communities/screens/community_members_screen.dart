import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/community_api.dart'; // For CommunityApiService
import '../../../../data/datasources/remote/user_api.dart'; // For UserApiService (follow/unfollow)

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/custom_button.dart';
import '../../profile/screens/profile_screen.dart'; // For navigating to member profiles

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';
import '../../../../../app_constants.dart'; // For AppConstants.appName if used

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityMembersScreen({
    Key? key,
    required this.communityId,
    required this.communityName,
  }) : super(key: key);

  @override
  _CommunityMembersScreenState createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _members = [];
  Map<int, bool> _followStatusMap = {};

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final communityService =
        Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final fetchedList = await communityService.getCommunityMembers(
        int.parse(widget.communityId),
        token: authProvider.token,
      );
      if (mounted)
        setState(() {
          _members = List<dynamic>.from(fetchedList);
          _isLoading = false;
        });
    } catch (e) {
      // print("CommunityMembersScreen: Error loading members: $e"); // Debug print removed
      if (mounted)
        setState(() {
          _isLoading = false;
          _error =
              "Failed to load members: ${e.toString().replaceFirst('Exception: ', '')}";
        });
    }
  }

  Future<void> _toggleFollow(
      int targetUserId, bool isCurrentlyFollowing) async {
    if (!mounted) return;
    final userService = Provider.of<UserService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in.')));
      return;
    }
    setState(() => _followStatusMap[targetUserId] = !isCurrentlyFollowing);
    try {
      if (!isCurrentlyFollowing)
        await userService.followUser(authProvider.token!, targetUserId);
      else
        await userService.unfollowUser(authProvider.token!, targetUserId);
    } catch (e) {
      if (mounted) {
        setState(() => _followStatusMap[targetUserId] = isCurrentlyFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Action failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.communityName} - Members')),
      body: RefreshIndicator(
          onRefresh: _fetchMembers, child: _buildBody(authProvider.userId)),
    );
  }

  Widget _buildBody(String? currentUserId) {
    /* ... UI methods remain largely the same, only imports fixed above ... */
    if (_isLoading) return _buildLoadingShimmer();
    if (_error != null) return _buildErrorView();
    if (_members.isEmpty) return _buildEmptyView();
    return ListView.separated(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final memberMap = _members[index] as Map<String, dynamic>?;
        if (memberMap == null) return const SizedBox.shrink();
        final int memberId = memberMap['id'] ?? 0;
        final String username = memberMap['username'] ?? 'User';
        final String name = memberMap['name'] ?? 'Unknown Name';
        final String? avatarUrl = memberMap['image_url'];
        final bool isCurrentUser = currentUserId == memberId.toString();
        final bool isFollowing = _followStatusMap[memberId] ??
            (memberMap['is_followed_by_viewer'] ?? false);
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : const NetworkImage(AppConstants.defaultAvatar)
                    as ImageProvider,
            child: (avatarUrl == null || avatarUrl.isEmpty) && name.isNotEmpty
                ? Text(name[0].toUpperCase())
                : null,
          ),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('@$username'),
          trailing: isCurrentUser
              ? const Chip(
                  label: Text('You'),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  visualDensity: VisualDensity.compact)
              : CustomButton(
                  text: isFollowing ? 'Unfollow' : 'Follow',
                  onPressed: () => _toggleFollow(memberId, isFollowing),
                  type: isFollowing ? ButtonType.outline : ButtonType.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(userIdToView: memberId.toString()),
            ),
          ),
        );
      },
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 70),
    );
  }

  Widget _buildLoadingShimmer() {
    /* ... UI unchanged ... */ final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(children: [
            const CircleAvatar(radius: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                      width: double.infinity,
                      height: 14.0,
                      color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: 12.0,
                      color: Colors.white),
                ])),
            Container(
                width: 80,
                height: 30,
                color: Colors.white,
                margin: const EdgeInsets.only(left: 10)),
          ]),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    /* ... UI unchanged ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(_error ?? 'Failed to load members.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _fetchMembers,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    /* ... UI unchanged ... */ final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Members Yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Be the first to join or invite others!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
