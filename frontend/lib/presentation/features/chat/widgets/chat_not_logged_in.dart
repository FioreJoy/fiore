import 'package:flutter/material.dart';

import '../../../../core/theme/theme_constants.dart';
// No need for custom_button here, using ElevatedButton directly.

class ChatNotLoggedInView extends StatelessWidget {
  final bool isDark;

  const ChatNotLoggedInView({
    Key? key,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Use current theme
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 80,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
            const SizedBox(height: 20),
            Text('Login to Chat',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Join communities and events to start chatting with others!',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Go to Login'),
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConstants.accentColor,
                  foregroundColor: ThemeConstants
                      .primaryColor, // Ensure text color is readable
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            )
          ],
        ),
      ),
    );
  }
}
