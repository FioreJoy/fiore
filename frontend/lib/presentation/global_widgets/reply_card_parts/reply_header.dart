import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/theme_constants.dart';
import '../../../../app_constants.dart';

class ReplyHeader extends StatelessWidget {
  final String? authorName;
  final String? authorAvatarUrl;
  final String? timeAgo;
  final Color? authorHighlightColor;
  final bool isOwner;
  final VoidCallback? onDelete;

  const ReplyHeader({
    Key? key,
    this.authorName,
    this.authorAvatarUrl,
    this.timeAgo,
    this.authorHighlightColor,
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
          radius: 14,
          backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          backgroundImage: authorAvatarUrl != null &&
                  authorAvatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(authorAvatarUrl!)
              : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            authorName ?? 'Anonymous',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: authorHighlightColor ??
                    (isDark ? Colors.white70 : Colors.black87)),
          ),
        ),
        if (timeAgo != null)
          Text(
            timeAgo!,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        if (isOwner && onDelete != null)
          SizedBox(
            height: 24, width: 24, // Constrain size of IconButton's tap area
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: ThemeConstants.errorColor.withOpacity(0.8),
              padding: EdgeInsets.zero,
              tooltip: 'Delete Reply',
              onPressed: onDelete,
            ),
          ),
      ],
    );
  }
}
