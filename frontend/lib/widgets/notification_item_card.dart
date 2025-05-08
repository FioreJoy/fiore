// frontend/lib/widgets/notification_item_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart'; // Corrected import if needed
import '../theme/theme_constants.dart';
import '../app_constants.dart';

class NotificationItemCard extends StatelessWidget {
  final NotificationModel notification; // Type should be recognized now
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;

  const NotificationItemCard({
    Key? key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
  }) : super(key: key);

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  IconData _getIconForNotificationType(NotificationType type) { // Type should be recognized
    switch (type) {
      case NotificationType.newFollower:
        return Icons.person_add_alt_1_outlined;
      case NotificationType.postReply:
      case NotificationType.replyReply:
        return Icons.comment_outlined;
      case NotificationType.postVote:
      case NotificationType.replyVote:
        return Icons.thumb_up_alt_outlined;
      case NotificationType.postFavorite:
      case NotificationType.replyFavorite:
        return Icons.favorite_border_outlined;
      case NotificationType.eventInvite:
        return Icons.event_available_outlined;
      case NotificationType.eventReminder:
        return Icons.alarm_outlined;
      case NotificationType.eventUpdate:
        return Icons.edit_calendar_outlined;
      case NotificationType.communityInvite:
        return Icons.group_add_outlined;
      case NotificationType.communityPost:
      case NotificationType.newCommunityEvent:
        return Icons.article_outlined;
      case NotificationType.userMention:
        return Icons.alternate_email_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isRead = notification.isRead;

    final Color cardColor = isRead
        ? (isDark ? ThemeConstants.backgroundDarker.withOpacity(0.7) : Colors.grey.shade100)
        : (isDark ? ThemeConstants.backgroundDark.withOpacity(0.9) : Colors.white);
    final Color textColor = isRead
        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade700)
        : (isDark ? Colors.white : Colors.black87);
    final Color subtitleColor = isRead
        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade500)
        : (isDark ? Colors.white70 : Colors.grey.shade600);


    return Material(
      color: cardColor,
      child: InkWell(
        onTap: () {
          onTap?.call();
          if (!isRead && onMarkAsRead != null) {
            onMarkAsRead!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ThemeConstants.mediumPadding,
              vertical: ThemeConstants.smallPadding + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isRead
                        ? (isDark ? Colors.grey.shade700 : Colors.grey.shade200)
                        : theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: notification.actor?.avatarUrl != null && notification.actor!.avatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(notification.actor!.avatarUrl!)
                        : null,
                    child: notification.actor?.avatarUrl == null || notification.actor!.avatarUrl!.isEmpty
                        ? Icon(
                            _getIconForNotificationType(notification.type),
                            size: 20,
                            color: isRead
                                ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                                : theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  if (!isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: ThemeConstants.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: ThemeConstants.mediumPadding - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
