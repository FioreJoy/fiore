import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_constants.dart';
import '../../../../data/models/chat_message_data.dart';
import '../../../../data/models/message_model.dart'; // For MediaItem
import '../../../global_widgets/chat_message_bubble.dart';
import '../../../providers/auth_provider.dart'; // For current user ID and avatar

class ChatMessagesList extends StatelessWidget {
  final bool isLoadingMessages;
  final List<ChatMessageData> messages;
  final bool canLoadMoreMessages; // To show top loader conditionally
  final ScrollController scrollController;
  final Map<int, String?> userAvatarCache; // Pass down the avatar cache

  const ChatMessagesList({
    Key? key,
    required this.isLoadingMessages,
    required this.messages,
    required this.canLoadMoreMessages,
    required this.scrollController,
    required this.userAvatarCache,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).userId ?? '';

    bool showTopLoader =
        isLoadingMessages && messages.isNotEmpty && canLoadMoreMessages;

    return Column(
      children: [
        if (showTopLoader)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        Expanded(
          child: (isLoadingMessages && messages.isEmpty)
              ? Center(
                  child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor))
              : messages.isEmpty
                  ? Center(
                      child: Text('No messages yet. Be the first!',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600)))
                  : ListView.builder(
                      controller: scrollController,
                      reverse:
                          false, // To keep messages at the bottom and load more at top
                      padding: const EdgeInsets.symmetric(
                          horizontal: ThemeConstants.smallPadding,
                          vertical: 8.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageData = messages[index];
                        final bool isCurrentUserMessage = currentUserId
                                .isNotEmpty &&
                            (messageData.user_id.toString() == currentUserId);

                        // Fetch avatar from cache or AuthProvider for current user
                        String? senderAvatarUrl =
                            userAvatarCache[messageData.user_id];
                        if (isCurrentUserMessage) {
                          senderAvatarUrl =
                              Provider.of<AuthProvider>(context, listen: false)
                                      .userImageUrl ??
                                  senderAvatarUrl;
                        }

                        List<MediaItem>? uiMediaItems;
                        if (messageData.media.isNotEmpty) {
                          uiMediaItems = messageData.media
                              .map((backendMedia) => MediaItem(
                                    // Assuming MediaItem.id is String and backendMedia.id can be int or String
                                    id: backendMedia.id.toString(),
                                    url: backendMedia.url,
                                    mimeType: backendMedia.mimeType,
                                    originalFilename:
                                        backendMedia.originalFilename,
                                    fileSize: backendMedia.fileSizeBytes,
                                  ))
                              .toList();
                        }

                        final displayMessage = MessageModel(
                            id: messageData.message_id.toString(),
                            senderId: messageData.user_id.toString(),
                            senderName: messageData.username,
                            content: messageData.content,
                            timestamp: messageData.timestamp,
                            profileImageUrl: senderAvatarUrl,
                            media: uiMediaItems);
                        return ChatMessageBubble(
                            message: displayMessage,
                            isMe: isCurrentUserMessage);
                      },
                    ),
        ),
      ],
    );
  }
}
