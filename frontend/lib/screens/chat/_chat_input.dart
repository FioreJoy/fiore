// frontend/lib/screens/chat/_chat_input.dart

import 'package:flutter/material.dart';
import '../../theme/theme_constants.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController messageController;
  final Function(String) onSendMessage; // Callback accepts message text
  final bool isSending;
  final bool isConnected; // Is WS connected to the correct room?

  const ChatInput({
    Key? key,
    required this.messageController,
    required this.onSendMessage,
    required this.isSending,
    required this.isConnected,
  }) : super(key: key);

  void _handleSend() {
    final text = messageController.text.trim();
    if (text.isNotEmpty && !isSending && isConnected) {
      onSendMessage(text); // Call the callback passed from parent
      // Clearing happens in the parent (_sendMessage) after successful WS send attempt
      // messageController.clear(); // Don't clear here
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Determine if sending is possible
    final bool canSend = isConnected && !isSending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
          .copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0), // Adjust for keyboard/system intrusions
      decoration: BoxDecoration(
        color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // TODO: Add attachment button if needed
          // IconButton(onPressed: (){}, icon: Icon(Icons.add_circle_outline)),

          Expanded(
            child: TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: canSend ? 'Type a message...' : (isConnected ? 'Ready to send...' : 'Connect to chat...'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
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
              onSubmitted: canSend ? (_) => _handleSend() : null,
              enabled: canSend, // Enable only if connected and not sending
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: canSend ? ThemeConstants.accentColor : Colors.grey,
            child: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    tooltip: "Send Message",
                    onPressed: canSend ? _handleSend : null, // Enable based on state
                  ),
          ),
        ],
      ),
    );
  }
}
