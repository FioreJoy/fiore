// frontend/lib/screens/chat/_chat_messages_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // To get current user ID

import '../../models/chat_message_data.dart';
import '../../models/message_model.dart'; // UI model for bubble
import '../../widgets/chat_message_bubble.dart';
import '../../services/auth_provider.dart';
import '../../theme/theme_constants.dart'; // For error color

class ChatMessagesView extends StatelessWidget {
  final List<ChatMessageData> messages;
  final ScrollController scrollController;
  final bool isLoading; // Indicates loading more or initial load
  final String? error;
  final String currentUserId; // Passed from parent state
  final bool canLoadMore;   // Flag from parent state

  const ChatMessagesView({
    Key? key,
    required this.messages,
    required this.scrollController,
    required this.isLoading,
    this.error,
    required this.currentUserId,
    required this.canLoadMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool showTopLoader = isLoading && messages.isNotEmpty; // Show loader only when loading more

    // Handle error state
    if (error != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Error loading messages: $error",
            style: const TextStyle(color: ThemeConstants.errorColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Handle initial loading state
    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle empty message list state
    if (!isLoading && messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.\nStart the conversation!',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
      );
    }

    // Build the list
    return Column(
      children: [
        // Top loading indicator for pagination
        if (showTopLoader)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
          ),
        // The actual message list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8.0),
            itemCount: messages.length,
            // Consider using reverse: true if you want messages to build from bottom up,
            // but loading older messages at the top becomes more complex.
            // reverse: false, (default)
            itemBuilder: (context, index) {
              final messageData = messages[index];
              final int? currentUserIdInt = int.tryParse(currentUserId); // Parse safely
              final bool isCurrentUserMessage = currentUserIdInt != null && messageData.user_id == currentUserIdInt;

              // Adapt ChatMessageData to the UI Model (MessageModel) for the bubble
              final displayMessage = MessageModel(
                id: messageData.message_id.toString(),
                userId: messageData.user_id.toString(),
                username: isCurrentUserMessage ? "Me" : messageData.username,
                content: messageData.content,
                timestamp: messageData.timestamp,
                isCurrentUser: isCurrentUserMessage,
                // Pass other fields like reactions/imageUrl if available in ChatMessageData
              );
              // Use a key for performance if list updates frequently
              return ChatMessageBubble(key: ValueKey(displayMessage.id) ,message: displayMessage);
            },
          ),
        ),
      ],
    );
  }
}
