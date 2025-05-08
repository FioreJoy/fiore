// frontend/lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double elevation;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final PreferredSizeWidget? bottom;
  final double height;
  final int? notificationBadgeCount; // Optional: for a badge on an action item

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.elevation = 0, // Default to flat for modern look
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.bottom,
    this.height = kToolbarHeight,
    this.notificationBadgeCount, // Initialize
  }) : super(key: key);

  // Helper to build a badge on an icon (can be used for action items)
  static Widget buildActionWithBadge({
    required BuildContext context, // Required to access theme
    required Widget iconWidget, // The actual Icon or IconButton
    required int count,
    VoidCallback? onPressed,
  }) {
    if (count <= 0) {
      return iconWidget; // Return original widget if no count
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget, // The base icon/button
        Positioned(
          top: 4, // Adjust as needed for your icon size
          right: 0, // Adjust
          child: Container(
            padding: EdgeInsets.all(count > 9 ? 3 : 4),
            decoration: BoxDecoration(
              color: ThemeConstants.errorColor,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).appBarTheme.backgroundColor ?? ThemeConstants.primaryColor,
                  width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors based on theme if not provided
    final effectiveBackgroundColor = backgroundColor ?? (isDark ? ThemeConstants.backgroundDarker : ThemeConstants.primaryColor);
    final effectiveForegroundColor = foregroundColor ?? (isDark ? Colors.white : Colors.white);

    List<Widget>? effectiveActions = actions;
    if (notificationBadgeCount != null && notificationBadgeCount! > 0 && actions != null) {
      // Example: Assuming the *first* action is the notification bell.
      // This is a simplistic assumption; a more robust way would be to identify
      // the notification bell by a key or type if the actions list is dynamic.
      if (actions!.isNotEmpty && actions![0] is IconButton && (actions![0] as IconButton).tooltip == 'Notifications') {
         effectiveActions = List.from(actions!); // Create a mutable copy
         effectiveActions![0] = buildActionWithBadge(
           context: context,
           iconWidget: actions![0], // The original IconButton
           count: notificationBadgeCount!,
         );
      } else if (actions!.isNotEmpty && actions!.last is IconButton && (actions!.last as IconButton).tooltip == 'Notifications') {
        // Example: if the last action is the bell
         effectiveActions = List.from(actions!);
         effectiveActions![actions!.length -1] = buildActionWithBadge(
           context: context,
           iconWidget: actions!.last,
           count: notificationBadgeCount!,
         );
      }
      // If you have a more specific way to identify the notification icon in 'actions', modify above.
    }


    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20, // Standard title size
          fontWeight: FontWeight.bold,
          color: effectiveForegroundColor,
        ),
      ),
      actions: effectiveActions, // Use potentially modified actions
      leading: leading,
      elevation: elevation,
      centerTitle: centerTitle,
      backgroundColor: effectiveBackgroundColor,
      foregroundColor: effectiveForegroundColor, // For icon color and back button
      iconTheme: IconThemeData(color: effectiveForegroundColor), // Ensure back button color
      actionsIconTheme: IconThemeData(color: effectiveForegroundColor), // Ensure actions icon color
      bottom: bottom,
      // Removed shape for a more standard AppBar look, can be added back if specific design is needed
      // shape: const RoundedRectangleBorder(
      //   borderRadius: BorderRadius.only(
      //     bottomLeft: Radius.circular(0), // Flat bottom edge
      //     bottomRight: Radius.circular(0),
      //   ),
      // ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0.0));
}
