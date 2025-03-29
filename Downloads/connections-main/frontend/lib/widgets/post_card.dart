import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class PostCard extends StatelessWidget {
  final String title;
  final String content;
  final String? authorName;
  final String? authorAvatar;
  final String timeAgo;
  final int upvotes;
  final int downvotes;
  final int replyCount;
  final bool hasUpvoted;
  final bool hasDownvoted;
  final bool isOwner;
  final String? communityName;
  final Color? communityColor;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onTap;

  const PostCard({
    Key? key,
    required this.title,
    required this.content,
    this.authorName,
    this.authorAvatar,
    required this.timeAgo,
    required this.upvotes,
    required this.downvotes,
    required this.replyCount,
    required this.hasUpvoted,
    required this.hasDownvoted,
    required this.isOwner,
    this.communityName,
    this.communityColor,
    required this.onUpvote,
    required this.onDownvote,
    required this.onReply,
    this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Author, Time, Community Tag
              Row(
                children: [
                  // Author Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ThemeConstants.primaryColor,
                    backgroundImage: authorAvatar != null
                        ? NetworkImage(authorAvatar!)
                        : null,
                    child: authorAvatar == null
                        ? Text(
                            authorName != null && authorName!.isNotEmpty
                                ? authorName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Author and Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName ?? 'Anonymous',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Community Tag (if any)
                  if (communityName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (communityColor ?? ThemeConstants.highlightColor)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (communityColor ?? ThemeConstants.highlightColor)
                              .withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        communityName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: communityColor ?? ThemeConstants.highlightColor,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: ThemeConstants.mediumPadding),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              // Content
              Text(
                content,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: ThemeConstants.mediumPadding),

              // Action Row: Upvote, Downvote, Reply, Delete
              Row(
                children: [
                  // Upvote
                  _buildActionButton(
                    Icons.arrow_upward,
                    upvotes.toString(),
                    hasUpvoted,
                    ThemeConstants.accentColor,
                    onUpvote,
                    isDark,
                  ),

                  // Downvote
                  _buildActionButton(
                    Icons.arrow_downward,
                    downvotes.toString(),
                    hasDownvoted,
                    ThemeConstants.errorColor,
                    onDownvote,
                    isDark,
                  ),

                  // Reply
                  _buildActionButton(
                    Icons.chat_bubble_outline,
                    replyCount.toString(),
                    false,
                    null,
                    onReply,
                    isDark,
                  ),

                  const Spacer(),

                  // Delete (if owner)
                  if (isOwner && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: ThemeConstants.errorColor,
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String count,
    bool isActive,
    Color? activeColor,
    VoidCallback onPressed,
    bool isDark,
  ) {
    final color = isActive
        ? activeColor
        : (isDark ? Colors.white54 : Colors.grey.shade600);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
