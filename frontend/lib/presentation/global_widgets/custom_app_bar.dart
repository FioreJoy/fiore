import 'package:flutter/material.dart';
import '../../core/theme/theme_constants.dart'; // Corrected path

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
  final int? notificationBadgeCount;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.elevation = 0,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.bottom,
    this.height = kToolbarHeight,
    this.notificationBadgeCount,
  }) : super(key: key);

  static Widget buildActionWithBadge({
    required BuildContext context,
    required Widget iconWidget,
    required int count,
    VoidCallback? onPressed,
  }) {
    /* ... Unchanged ... */ if (count <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          top: 4,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(count > 9 ? 3 : 4),
            decoration: BoxDecoration(
              color: ThemeConstants.errorColor,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).appBarTheme.backgroundColor ??
                      ThemeConstants.primaryColor,
                  width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI using theme variables, corrected imports will be sufficient ... */
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBackgroundColor = backgroundColor ??
        (isDark
            ? ThemeConstants.backgroundDarker
            : ThemeConstants.primaryColor);
    final effectiveForegroundColor =
        foregroundColor ?? (isDark ? Colors.white : Colors.white);
    List<Widget>? effectiveActions = actions;
    if (notificationBadgeCount != null &&
        notificationBadgeCount! > 0 &&
        actions != null) {
      if (actions!.isNotEmpty &&
          actions![0] is IconButton &&
          (actions![0] as IconButton).tooltip == 'Notifications') {
        effectiveActions = List.from(actions!);
        effectiveActions![0] = buildActionWithBadge(
          context: context,
          iconWidget: actions![0],
          count: notificationBadgeCount!,
        );
      } else if (actions!.isNotEmpty &&
          actions!.last is IconButton &&
          (actions!.last as IconButton).tooltip == 'Notifications') {
        effectiveActions = List.from(actions!);
        effectiveActions![actions!.length - 1] = buildActionWithBadge(
          context: context,
          iconWidget: actions!.last,
          count: notificationBadgeCount!,
        );
      }
    }
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: effectiveForegroundColor,
        ),
      ),
      actions: effectiveActions,
      leading: leading,
      elevation: elevation,
      centerTitle: centerTitle,
      backgroundColor: effectiveBackgroundColor,
      foregroundColor: effectiveForegroundColor,
      iconTheme: IconThemeData(color: effectiveForegroundColor),
      actionsIconTheme: IconThemeData(color: effectiveForegroundColor),
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0.0));
}
