import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

enum ButtonType {
  primary,
  secondary,
  outline,
  text,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsets? padding;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get colors based on button type
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = theme.colorScheme.primary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case ButtonType.secondary:
        backgroundColor = theme.colorScheme.secondary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case ButtonType.outline:
        backgroundColor = Colors.transparent;
        textColor = isDark ? Colors.white : theme.colorScheme.primary;
        borderColor = isDark ? Colors.white : theme.colorScheme.primary;
        break;
      case ButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = isDark ? Colors.white : theme.colorScheme.primary;
        borderColor = Colors.transparent;
        break;
    }

    // Button content with optional icon and loader
    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: textColor),
        if ((icon != null || isLoading) && text.isNotEmpty)
          const SizedBox(width: 8),
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
      ],
    );

    // Base button with styling
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        disabledBackgroundColor: backgroundColor.withOpacity(0.6),
        disabledForegroundColor: textColor.withOpacity(0.6),
        side: type == ButtonType.outline
            ? BorderSide(color: borderColor, width: 1.5)
            : null,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: type == ButtonType.text || type == ButtonType.outline ? 0 : 2,
        shadowColor: type == ButtonType.text || type == ButtonType.outline
            ? Colors.transparent
            : Colors.black.withOpacity(0.2),
      ),
      child: buttonContent,
    );

    // Optionally wrap in a container for full width
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
