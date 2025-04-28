// frontend/lib/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../app_constants.dart'; // Make sure to import AppConstants

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar for other users' messages
          if (!isMe) _buildAvatar(),
          
          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isMe 
                    ? Theme.of(context).primaryColor
                    : isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show sender name for others' messages
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ),
                  
                  // Message content
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : null,
                    ),
                  ),
                  
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe 
                            ? Colors.white.withOpacity(0.7) 
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Avatar for current user's messages (if you want to show it)
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, left: 8.0),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: message.profileImageUrl != null && message.profileImageUrl!.isNotEmpty
            ? NetworkImage(message.profileImageUrl!)
            : null,
        child: message.profileImageUrl == null || message.profileImageUrl!.isEmpty
            ? Text(message.senderName[0].toUpperCase())
            : null,
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      // Today, show time only
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Not today, show date and time
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
