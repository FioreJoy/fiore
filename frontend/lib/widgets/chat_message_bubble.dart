// frontend/lib/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart'; // To check mime types
import 'package:open_filex/open_filex.dart'; // To open files
// Import your download service if you implement one, or url_launcher
// import 'package:url_launcher/url_launcher.dart'; // Example

// <<< Use relative import >>>
import '../models/chat_message_data.dart';

class ChatMessageBubble extends StatelessWidget {
  // <<< Expect ChatMessageData and int? >>>
  final ChatMessageData message;
  final int? currentUserId;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  // <<< Compare message.userId (int) with currentUserId (int?) >>>
  bool get _isMe => currentUserId != null && message.userId == currentUserId;

  // --- Widget to display attachment based on type ---
  Widget _buildAttachmentWidget(BuildContext context) {
    // <<< Access fields via message.fieldName >>>
    if (message.attachmentUrl == null) return const SizedBox.shrink();

    final String displayFilename = message.attachmentFilename ?? 'Attachment';
    final String type = message.attachmentType ?? 'file';
    final String attachmentUrl = message.attachmentUrl!;
    final bool useMyStyle = _isMe; // Use internal getter

    // Image Attachment
    if (type.startsWith('image')) {
      return GestureDetector(
        onTap: () {
          // TODO: Implement full-screen image view
          print('Tapped image: $attachmentUrl');
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: CachedNetworkImage(
              imageUrl: attachmentUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (context, url, error) => Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: Center(child: Icon(Icons.error_outline, color: Colors.grey.shade600))), // Error Icon
            ),
          ),
        ),
      );
    }
    // Video Attachment
    else if (type.startsWith('video')) {
      return GestureDetector(
        onTap: () async {
          // TODO: Implement video player or opening URL
          print('Tapped video: $attachmentUrl');
          // Example using url_launcher (add url_launcher to pubspec.yaml)
          // final uri = Uri.parse(attachmentUrl);
          // if (await canLaunchUrl(uri)) {
          //   await launchUrl(uri, mode: LaunchMode.externalApplication);
          // } else {
          //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open video: $attachmentUrl')));
          // }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video playback not yet implemented.')));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined, size: 40, color: useMyStyle ? Colors.white70: Colors.black54),
              const SizedBox(width: 8),
              Flexible(child: Text(displayFilename, style: TextStyle(color: useMyStyle ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }
    // PDF Attachment
    else if (type == 'pdf' || lookupMimeType(displayFilename)?.contains('pdf') == true) {
      return InkWell(
        onTap: () async {
          // TODO: Implement file downloading and opening using open_filex
          print('Tapped PDF: $attachmentUrl');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening PDF... (Download/Open logic needed)')));
          // Example flow:
          // 1. Call a service method: await DownloadService.downloadAndOpenFile(attachmentUrl, displayFilename);
          // 2. DownloadService uses http/dio to download to temp path_provider dir
          // 3. DownloadService calls OpenFilex.open(filePath);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade100.withOpacity(useMyStyle ? 0.9 : 0.7),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: Colors.red.shade800),
              const SizedBox(width: 8),
              Flexible(child: Text(displayFilename, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }
    // Generic File Attachment
    else {
      return InkWell(
        onTap: () async {
          // TODO: Implement file downloading and opening
          print('Tapped file: $attachmentUrl');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening file... (Download/Open logic needed)')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade100.withOpacity(useMyStyle ? 0.9 : 0.7),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, color: Colors.blueGrey.shade800),
              const SizedBox(width: 8),
              Flexible(child: Text(displayFilename, style: TextStyle(color: Colors.blueGrey.shade900, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isBubbleMe = _isMe; // Use internal getter
    final bubbleColor = isBubbleMe ? theme.colorScheme.primary : theme.colorScheme.surface;
    // Provide a default color if onPrimary/onSurface are somehow null
    final textColor = (isBubbleMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface) ?? (isBubbleMe ? Colors.white : Colors.black);

    return Align(
      alignment: isBubbleMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: isBubbleMe ? const Radius.circular(16.0) : Radius.zero,
            bottomRight: isBubbleMe ? Radius.zero : const Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isBubbleMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // <<< Access username via message.username >>>
            if (!isBubbleMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  message.username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ),

            // Display Attachment OR Text
            // <<< Access attachmentUrl via message.attachmentUrl >>>
            if (message.attachmentUrl != null)
              Padding(
                // Add vertical padding around attachment if there's no text,
                // or only top padding if text follows
                padding: EdgeInsets.symmetric(vertical: message.content.isEmpty ? 4.0 : 0).copyWith(top: 4.0),
                child: _buildAttachmentWidget(context),
              ),

            // <<< Access content via message.content >>>
            if (message.content.isNotEmpty)
              Padding(
                // Add top padding only if there was an attachment above
                padding: EdgeInsets.only(top: message.attachmentUrl != null ? 4.0 : 0),
                child: Text(
                  message.content,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),

            const SizedBox(height: 4),
            // <<< Access timestamp via message.timestamp >>>
            Text(
              // Consider showing date if older? For now just time.
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}