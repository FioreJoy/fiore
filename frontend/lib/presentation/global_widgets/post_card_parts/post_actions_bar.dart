import 'package:flutter/material.dart';
import '../../../core/theme/theme_constants.dart'; // Adjusted path

class PostActionsBar extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final int replyCount;
  final int favoriteCount;
  final bool hasUpvoted;
  final bool hasDownvoted;
  final bool isFavorited;
  final bool isVoteLoading;
  final bool isFavoriteLoading;

  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onReply;
  final VoidCallback onFavorite;
  // No onDelete here as it's usually in the header's "more options"

  const PostActionsBar({
    Key? key,
    required this.upvotes,
    required this.downvotes,
    required this.replyCount,
    required this.favoriteCount,
    required this.hasUpvoted,
    required this.hasDownvoted,
    required this.isFavorited,
    required this.isVoteLoading,
    required this.isFavoriteLoading,
    required this.onUpvote,
    required this.onDownvote,
    required this.onReply,
    required this.onFavorite,
  }) : super(key: key);

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onPressed,
    Color? activeColor,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color inactiveColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color color =
        isActive ? (activeColor ?? theme.colorScheme.primary) : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading || onPressed == null ? null : onPressed,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 1.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 1.8, color: color),
                )
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildActionButton(
                context,
                icon: hasUpvoted
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                label: upvotes.toString(),
                isActive: hasUpvoted,
                activeColor: ThemeConstants.accentColor,
                isLoading: isVoteLoading &&
                    hasUpvoted, // Show loading only if this action is loading
                onPressed: onUpvote,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                context,
                icon: hasDownvoted
                    ? Icons.thumb_down_alt_rounded
                    : Icons.thumb_down_alt_outlined,
                label: downvotes.toString(),
                isActive: hasDownvoted,
                activeColor: ThemeConstants.errorColor,
                isLoading: isVoteLoading &&
                    hasDownvoted, // Show loading only if this action is loading
                onPressed: onDownvote,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                label: replyCount.toString(),
                isActive: false, // Reply button usually isn't "active" visually
                onPressed: onReply,
              ),
            ],
          ),
          _buildActionButton(
            context,
            icon: isFavorited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: favoriteCount.toString(),
            isActive: isFavorited,
            activeColor:
                Colors.pinkAccent.shade100, // A lighter pink for favorite
            isLoading: isFavoriteLoading,
            onPressed: onFavorite,
          ),
        ],
      ),
    );
  }
}
