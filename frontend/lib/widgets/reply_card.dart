import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';
import 'custom_card.dart'; // Assuming CustomCard exists

class ReplyCard extends StatelessWidget {
  final String content;
  final String? authorName;
  final String? authorAvatar;
  final String? timeAgo;
  // Removed childReplies - hierarchy handled in RepliesScreen
  final VoidCallback? onReply;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;
  final VoidCallback? onDelete;
  final bool isOwner;
  final bool hasUpvoted;
  final bool hasDownvoted;
  final int? upvotes;
  final int? downvotes;
  final int indentLevel; // Added indentLevel
  final Color? authorHighlightColor; // Keep this for OP highlighting

  const ReplyCard({
    Key? key,
    required this.content,
    this.authorName,
    this.authorAvatar,
    this.timeAgo,
    this.onReply,
    this.onUpvote,
    this.onDownvote,
    this.onDelete,
    this.isOwner = false,
    this.hasUpvoted = false,
    this.hasDownvoted = false,
    this.upvotes,
    this.downvotes,
    required this.indentLevel, // Make required
    this.authorHighlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Calculate left padding based on indent level
    final double indentPadding = indentLevel * 16.0; // Adjust multiplier as needed

    return Padding(
      padding: EdgeInsets.only(left: indentPadding), // Apply indent here
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: 8.0), // Margin between cards
        backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade50,
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding - 4), // Slightly reduce padding
        elevation: indentLevel > 0 ? 0 : 1.0, // Less elevation for nested
        hasBorder: indentLevel > 0, // Add border for nested
        borderColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info row
            Row(
              children: [
                 CircleAvatar( /* ... Avatar ... */ ),
                 const SizedBox(width: 8),
                 Expanded(
                    child: Row(
                      children: [
                        Text( /* ... Author Name ... */ ),
                         if (isOwner) Container( /* ... OP Tag ... */ ),
                      ],
                    ),
                 ),
                 if (timeAgo != null) Text( /* ... Time Ago ... */ ),
                 if (isOwner && onDelete != null) IconButton( /* ... Delete Button ... */ ),
              ],
            ),
            const SizedBox(height: 8),

            // Content
            Text( /* ... Content Text ... */ ),
            const SizedBox(height: 8),

            // Actions row
            Row(
              children: [
                 _buildActionButton( /* ... Upvote ... */ ),
                 _buildActionButton( /* ... Downvote ... */ ),
                 _buildActionButton(icon: Icons.reply, label: 'Reply', onTap: onReply),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool selected = false,
    Color? selectedColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                ? (selectedColor ?? ThemeConstants.primaryColor)
                : Colors.grey.shade600,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                  ? (selectedColor ?? ThemeConstants.primaryColor)
                  : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
