// frontend/lib/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // For NumberFormat to format bytes

import '../models/message_model.dart'; // Contains MediaItem model
import '../app_constants.dart';
import '../theme/theme_constants.dart';

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  // Helper to format file size
  String _formatBytes(int? bytes, {int decimals = 1}) {
    if (bytes == null || bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    // Use NumberFormat for locale-aware formatting if needed, or simple toStringAsFixed
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Widget _buildAvatar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? backgroundImage;
    if (message.profileImageUrl != null && message.profileImageUrl!.isNotEmpty) {
      backgroundImage = CachedNetworkImageProvider(message.profileImageUrl!);
    } else {
      // Fallback to default only if truly no image AND no initials possible.
      // Initials are preferred over a generic placeholder if name exists.
      if (message.senderName.isEmpty) {
        backgroundImage = const NetworkImage(AppConstants.defaultAvatar);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0, left: 8.0),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        backgroundImage: backgroundImage,
        child: backgroundImage == null && message.senderName.isNotEmpty
            ? Text(
          message.senderName[0].toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildMediaAttachmentsWidget(BuildContext context) {
    if (message.media == null || message.media!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> mediaWidgets = [];

    for (var mediaItem in message.media!) {
      if (mediaItem.url == null) continue;

      Widget mediaDisplay;
      final bool isImage = mediaItem.mimeType.startsWith('image/');

      if (isImage) {
        mediaDisplay = Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
              maxHeight: 250, // Increased max height for better image preview
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: CachedNetworkImage(
                imageUrl: mediaItem.url!,
                fit: BoxFit.contain, // Contain to see full image better
                placeholder: (context, url) => Container(
                  height: 150, width: 150, // Placeholder size
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5))),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150, width: 150, // Error placeholder size
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
                ),
              ),
            ),
          ),
        );
      } else {
        // Non-image file: Display as a tappable link/card
        mediaDisplay = Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: InkWell(
            onTap: () async {
              final uri = Uri.parse(mediaItem.url!);
              if (await canLaunchUrl(uri)) {
                // For web, externalApplication might not always force download without backend headers.
                // For mobile, it should work fine.
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: ${mediaItem.originalFilename ?? 'attachment'}')));
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: (isMe ? Theme.of(context).primaryColorDark.withOpacity(0.7) : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark? Colors.grey.shade600 : Colors.grey.shade400, width: 0.5)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 24, color: isMe ? Colors.white.withOpacity(0.8) : (isDark ? Colors.grey.shade200 : Colors.grey.shade800)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mediaItem.originalFilename ?? 'Download Attachment',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.95) : Colors.black),
                            // decoration: TextDecoration.underline, // Optional underline
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (mediaItem.fileSize != null)
                          Text(
                            _formatBytes(mediaItem.fileSize, decimals: 1),
                            style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withOpacity(0.7) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.download_for_offline_outlined, size: 20, color: isMe ? Colors.white.withOpacity(0.7) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        );
      }
      mediaWidgets.add(mediaDisplay);
    }
    // Display media items in a Column within the bubble
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: mediaWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(context),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isMe ? theme.colorScheme.primary : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(message.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.grey.shade300 : ThemeConstants.accentColor)),
                    ),
                  if (message.content.isNotEmpty)
                    Text(message.content, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87), fontSize: 15)),

                  _buildMediaAttachmentsWidget(context), // Display media

                  Padding(
                    padding: EdgeInsets.only(top: (message.content.isNotEmpty || (message.media?.isNotEmpty ?? false)) ? 5.0 : 0),
                    child: Text(_formatTime(message.timestamp), style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withOpacity(0.7) : (isDark ? Colors.grey.shade500 : Colors.grey.shade600))),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) _buildAvatar(context),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDate == today) return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    else if (today.difference(messageDate).inDays == 1) return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    else return '${DateFormat.MMMd().format(timestamp)} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}