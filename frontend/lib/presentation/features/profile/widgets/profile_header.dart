import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; // To check auth status for buttons

import '../../../../core/theme/theme_constants.dart';
import '../../../../../app_constants.dart'; // For default avatar
import '../../../global_widgets/custom_button.dart';
import '../../../providers/auth_provider.dart'; // For auth status

class ProfileHeader extends StatelessWidget {
  final String profileUserId; // ID of the profile being viewed
  final String name;
  final String username;
  final String? imageUrl;
  final int followersCount;
  final int followingCount;
  final bool isMyProfile;
  final bool
      isFollowingViewer; // Whether the *viewer* is following this profile
  final bool isFollowActionLoading;
  final VoidCallback onEditProfile;
  final VoidCallback onToggleFollow;

  const ProfileHeader({
    Key? key,
    required this.profileUserId,
    required this.name,
    required this.username,
    this.imageUrl,
    required this.followersCount,
    required this.followingCount,
    required this.isMyProfile,
    required this.isFollowingViewer,
    required this.isFollowActionLoading,
    required this.onEditProfile,
    required this.onToggleFollow,
  }) : super(key: key);

  Widget _buildHeaderStat(String value, String label, bool isDark,
      ThemeData theme, BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Consider navigating to followers/following list screen
        // e.g., Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(userId: profileUserId, type: label)));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigate to $label list (TODO)')));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color)),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    ImageProvider displayImageProvider;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      displayImageProvider = CachedNetworkImageProvider(imageUrl!);
    } else {
      displayImageProvider = const NetworkImage(AppConstants.defaultAvatar);
    }

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight * 0.1,
        left: 20, right: 20,
        bottom: kTextTabBarHeight + 20, // For TabBar below
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  ThemeConstants.backgroundDark.withOpacity(0.6),
                  ThemeConstants.backgroundDarker.withOpacity(0.4)
                ]
              : [
                  Colors.blueGrey.shade50.withOpacity(0.7),
                  Colors.grey.shade50.withOpacity(0.1)
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'profile_avatar_$profileUserId', // Use passed profileUserId
            child: CircleAvatar(
              radius: 45,
              backgroundColor:
                  isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              backgroundImage: displayImageProvider,
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? Colors.white : theme.textTheme.bodyLarge?.color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text("@$username",
              style: theme.textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeaderStat(followersCount.toString(), "Followers", isDark,
                  theme, context),
              Container(
                  height: 20,
                  width: 1,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 16)),
              _buildHeaderStat(followingCount.toString(), "Following", isDark,
                  theme, context),
            ],
          ),
          const SizedBox(height: 12),
          if (isMyProfile)
            SizedBox(
                width: 170,
                child: CustomButton(
                    text: 'Edit Profile',
                    onPressed: onEditProfile,
                    type: ButtonType.outline,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    icon: Icons.edit_outlined,
                    fontSize: 13))
          else if (authProvider
              .isAuthenticated) // Show follow/unfollow only if viewer is logged in
            SizedBox(
              width: 170,
              child: CustomButton(
                text: isFollowingViewer ? 'Unfollow' : 'Follow',
                onPressed: onToggleFollow,
                isLoading: isFollowActionLoading,
                type:
                    isFollowingViewer ? ButtonType.outline : ButtonType.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                icon: isFollowingViewer
                    ? Icons.person_remove_outlined
                    : Icons.person_add_alt_1,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}
