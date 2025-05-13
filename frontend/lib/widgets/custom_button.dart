// frontend/lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
import '../theme/theme_constants.dart'; // Ensure this path is correct

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
  final Color? backgroundColor; // <-- ADDED
  final Color? foregroundColor; // <-- ADDED
  final Color? borderColor;     // <-- ADDED (useful for outline type)
  final double? height;          // <-- ADDED (optional height)
  final double? fontSize;        // <-- ADDED (optional font size)

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding,
    this.backgroundColor, // <-- ADDED
    this.foregroundColor, // <-- ADDED
    this.borderColor,     // <-- ADDED
    this.height,          // <-- ADDED
    this.fontSize,        // <-- ADDED
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine default colors based on button type if custom ones are not provided
    Color effectiveBackgroundColor;
    Color effectiveForegroundColor;
    Color effectiveBorderColor;

    switch (type) {
      case ButtonType.primary:
        effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.primary;
        effectiveForegroundColor = foregroundColor ?? (ThemeData.estimateBrightnessForColor(effectiveBackgroundColor) == Brightness.dark ? Colors.white : Colors.black);
        effectiveBorderColor = borderColor ?? Colors.transparent;
        break;
      case ButtonType.secondary:
        effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.secondary;
        effectiveForegroundColor = foregroundColor ?? (ThemeData.estimateBrightnessForColor(effectiveBackgroundColor) == Brightness.dark ? Colors.white : Colors.black);
        effectiveBorderColor = borderColor ?? Colors.transparent;
        break;
      case ButtonType.outline:
        effectiveBackgroundColor = backgroundColor ?? Colors.transparent;
        effectiveForegroundColor = foregroundColor ?? (isDark ? ThemeConstants.accentColor : theme.colorScheme.primary);
        effectiveBorderColor = borderColor ?? (isDark ? ThemeConstants.accentColor.withOpacity(0.7) : theme.colorScheme.primary);
        break;
      case ButtonType.text:
        effectiveBackgroundColor = backgroundColor ?? Colors.transparent;
        effectiveForegroundColor = foregroundColor ?? (isDark ? ThemeConstants.accentColor : theme.colorScheme.primary);
        effectiveBorderColor = borderColor ?? Colors.transparent;
        break;
    }

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: (fontSize ?? 16) * 1.25, // Scale loader with font size
            height: (fontSize ?? 16) * 1.25,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveForegroundColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: (fontSize ?? 16) * 1.1, color: effectiveForegroundColor), // Scale icon
        if ((icon != null || isLoading) && text.isNotEmpty)
          const SizedBox(width: 8),
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize ?? 16,
              fontWeight: FontWeight.bold,
              color: effectiveForegroundColor,
            ),
          ),
      ],
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: effectiveBackgroundColor,
      foregroundColor: effectiveForegroundColor,
      disabledBackgroundColor: effectiveBackgroundColor.withOpacity(0.5),
      disabledForegroundColor: effectiveForegroundColor.withOpacity(0.5),
      side: (type == ButtonType.outline || (borderColor != null && borderColor != Colors.transparent))
          ? BorderSide(color: effectiveBorderColor, width: 1.5)
          : null,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.buttonBorderRadius),
      ),
      elevation: type == ButtonType.text || type == ButtonType.outline ? 0 : 2,
      shadowColor: type == ButtonType.text || type == ButtonType.outline
          ? Colors.transparent
          : Colors.black.withOpacity(0.15),
      minimumSize: height != null ? Size(0, height!) : null, // Apply height if provided
    );

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: buttonContent,
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}