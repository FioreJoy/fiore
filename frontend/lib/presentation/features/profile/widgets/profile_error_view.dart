import 'package:flutter/material.dart';
import '../../../../core/theme/theme_constants.dart';
import '../../../global_widgets/custom_button.dart'; // Adjusted path

class ProfileErrorView extends StatelessWidget {
  final String message;
  final bool isDark;
  final VoidCallback onRetry;

  const ProfileErrorView({
    Key? key,
    required this.message,
    required this.isDark,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
            const SizedBox(height: ThemeConstants.largePadding),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
