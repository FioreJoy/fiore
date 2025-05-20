import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback, SystemChannels
import '../../../../core/theme/theme_constants.dart';

class ChatMessageInputBar extends StatelessWidget {
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final bool isSendingMessage;
  final bool showEmojiPicker; // To decide icon
  final bool canSendMessage; // Combined logic from parent
  final VoidCallback onSendMessage;
  final VoidCallback onToggleEmojiPicker;
  final VoidCallback onPickImages;

  const ChatMessageInputBar({
    Key? key,
    required this.messageController,
    required this.messageFocusNode,
    required this.isSendingMessage,
    required this.showEmojiPicker,
    required this.canSendMessage,
    required this.onSendMessage,
    required this.onToggleEmojiPicker,
    required this.onPickImages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        // For bottom padding on iOS/some Android
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end, // Align items to the bottom
          children: [
            // Emoji Picker Toggle
            IconButton(
              icon: Icon(
                showEmojiPicker
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              tooltip: showEmojiPicker ? "Show Keyboard" : "Show Emojis",
              onPressed: onToggleEmojiPicker,
            ),
            // Image Picker
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              tooltip: "Attach Images",
              onPressed: onPickImages,
            ),
            // Message Text Field
            Expanded(
              child: TextField(
                controller: messageController,
                focusNode: messageFocusNode,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? ThemeConstants.backgroundDark
                      : Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 5, // Allow multiline input
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: canSendMessage ? (_) => onSendMessage() : null,
                enabled: !isSendingMessage, // Disable while sending
                onTap: () {
                  // If emoji picker is shown, tapping the text field should hide it
                  if (showEmojiPicker) {
                    onToggleEmojiPicker(); // This will set _showEmojiPicker to false in parent
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  canSendMessage ? ThemeConstants.accentColor : Colors.grey,
              child: isSendingMessage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                      tooltip: "Send Message",
                      onPressed: canSendMessage ? onSendMessage : null,
                    ),
            )
          ],
        ),
      ),
    );
  }
}
