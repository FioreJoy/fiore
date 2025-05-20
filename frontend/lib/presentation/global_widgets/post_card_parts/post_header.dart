import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/theme_constants.dart';
import '../../../../app_constants.dart';

class PostHeader extends StatelessWidget {
  final String postId; // Used for Hero tag potentially
  final String? authorName;
  final String? authorAvatarUrl;
  final String timeAgo;
  final String? communityName;
  final Color? communityColor;
  final bool isOwner;
  final VoidCallback? onDelete;

  const PostHeader({
    Key? key,
    required this.postId,
    this.authorName,
    this.authorAvatarUrl,
    required this.timeAgo,
    this.communityName,
    this.communityColor,
    required this.isOwner,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          backgroundImage: authorAvatarUrl != null &&
                  authorAvatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(authorAvatarUrl!)
              : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authorName ?? 'Anonymous',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            ],
          ),
        ),
        if (communityName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (communityColor ?? ThemeConstants.highlightColor)
                  .withOpacity(isDark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (communityColor ?? ThemeConstants.highlightColor)
                      .withOpacity(0.5),
                  width: 0.8),
            ),
            child: Text(
              communityName!,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: communityColor ?? ThemeConstants.highlightColor),
            ),
          ),
        if (isOwner && onDelete != null)
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            onPressed: () {
              // Simple more options for now: just delete.
              // Could expand to show a menu with Edit, Delete etc.
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Wrap(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined,
                          color: ThemeConstants.errorColor),
                      title: const Text('Delete Post',
                          style: TextStyle(color: ThemeConstants.errorColor)),
                      onTap: () {
                        Navigator.of(ctx).pop(); // Close bottom sheet
                        onDelete!(); // Call the delete callback
                      },
                    ),
                  ],
                ),
              );
            },
            tooltip: 'More options',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
