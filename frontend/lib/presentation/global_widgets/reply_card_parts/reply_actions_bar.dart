import 'package:flutter/material.dart';
import '../../../core/theme/theme_constants.dart';

class ReplyActionsBar extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final int favoriteCount;
  final bool hasUpvoted;
  final bool hasDownvoted;
  final bool isFavorited;
  final bool isVoteLoading;
  final bool isFavoriteLoading;

  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback? onReplyToThis; // To reply specifically to this reply
  final VoidCallback onFavorite;

  const ReplyActionsBar({
    Key? key,
    required this.upvotes,
    required this.downvotes,
    required this.favoriteCount,
    required this.hasUpvoted,
    required this.hasDownvoted,
    required this.isFavorited,
    required this.isVoteLoading,
    required this.isFavoriteLoading,
    required this.onUpvote,
    required this.onDownvote,
    this.onReplyToThis,
    required this.onFavorite,
  }) : super(key: key);

  Widget _buildActionButton({
    required BuildContext context,
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
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: color))
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Adding left padding here to align actions with text under avatar+name in header
    return Padding(
      padding: const EdgeInsets.only(
          left: 14.0 + 8.0 - 6.0,
          top: 8.0), // Similar to ReplyCard's original alignment
      child: Row(
        children: [
          _buildActionButton(
            context: context,
            icon: hasUpvoted
                ? Icons.arrow_upward_rounded
                : Icons.arrow_upward_outlined,
            label: upvotes.toString(),
            isActive: hasUpvoted,
            activeColor: ThemeConstants.accentColor,
            isLoading: isVoteLoading && hasUpvoted,
            onPressed: onUpvote,
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            context: context,
            icon: hasDownvoted
                ? Icons.arrow_downward_rounded
                : Icons.arrow_downward_outlined,
            label: downvotes.toString(),
            isActive: hasDownvoted,
            activeColor: ThemeConstants.errorColor,
            isLoading: isVoteLoading && hasDownvoted,
            onPressed: onDownvote,
          ),
          const SizedBox(width: 10),
          if (onReplyToThis !=
              null) // Only show reply button if callback is provided
            _buildActionButton(
              context: context,
              icon: Icons.reply_rounded,
              label: 'Reply',
              isActive: false,
              onPressed: onReplyToThis,
            ),
          if (onReplyToThis != null) const SizedBox(width: 10),
          _buildActionButton(
            context: context,
            icon: isFavorited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: favoriteCount.toString(),
            isActive: isFavorited,
            activeColor: Colors.pinkAccent.shade100,
            isLoading: isFavoriteLoading,
            onPressed: onFavorite,
          ),
          // Add more actions like share, report if needed
        ],
      ),
    );
  }
}
