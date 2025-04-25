import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/message_model.dart';
import '../theme/theme_constants.dart';

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;

  const ChatMessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors based on sender (self or others)
    final Color bubbleColor = message.isCurrentUser
        ? (isDark ? ThemeConstants.accentColor.withOpacity(0.5) : ThemeConstants.accentColor.withOpacity(0.2))
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    final Color textColor = message.isCurrentUser
        ? (isDark ? Colors.white : ThemeConstants.accentColor)
        : (isDark ? Colors.white : Colors.black87);

    // Format timestamp
    final formattedTime = DateFormat('h:mm a').format(message.timestamp);

    // Create a default avatar widget
    Widget avatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: message.isCurrentUser
          ? ThemeConstants.accentColor.withOpacity(0.3)
          : Colors.grey.shade300,
      child: Text(
        message.username.isNotEmpty ? message.username[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: message.isCurrentUser
              ? ThemeConstants.accentColor
              : Colors.grey.shade700,
        ),
      ),
    );

    // If user has a profile image, use it
    if (message.profileImageUrl != null && message.profileImageUrl!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: 16,
        backgroundImage: CachedNetworkImageProvider(message.profileImageUrl!),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Align user messages to the right, others to the left
        mainAxisAlignment: message.isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Only show avatar for other users' messages on the left side
          if (!message.isCurrentUser) avatarWidget,

          // Add some spacing between avatar and bubble
          if (!message.isCurrentUser) const SizedBox(width: 8),

          // Message bubble with constraints
          ConstrainedBox(
            constraints: BoxConstraints(
              // Limit the bubble width to a percentage of the screen
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: message.isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Username (only for others, not self)
                if (!message.isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                    child: Text(
                      message.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),

                // The message bubble
                Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: message.isCurrentUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: message.isCurrentUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Message content
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Timestamp
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Show avatar for current user's messages on the right side
          if (message.isCurrentUser) const SizedBox(width: 8),
          if (message.isCurrentUser) avatarWidget,
        ],
      ),
    );
  }
}
