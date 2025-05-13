// frontend/lib/widgets/community_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/theme_constants.dart';
import '../app_constants.dart'; // For default avatar if logoUrl is null

class CommunityCard extends StatelessWidget {
  final String name;
  final String? description;
  final int memberCount;
  final int onlineCount; // Assuming this will be provided by backend or calculated
  final String? logoUrl;
  final Color backgroundColor; // Primary color for the card theme
  final bool isJoined;
  final VoidCallback onJoin; // Callback for join/leave action
  final VoidCallback onTap;  // Callback for tapping the card itself

  const CommunityCard({
    Key? key,
    required this.name,
    this.description,
    required this.memberCount,
    this.onlineCount = 0, // Default to 0 if not provided
    this.logoUrl,
    required this.backgroundColor,
    required this.isJoined,
    required this.onJoin,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? ThemeConstants.backgroundDark : Colors.white,
      borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
      elevation: 2.5,
      shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
        splashColor: backgroundColor.withOpacity(0.2),
        highlightColor: backgroundColor.withOpacity(0.1),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Logo and Background Color
              Container(
                height: 85, // Slightly taller header
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [backgroundColor.withOpacity(0.7), backgroundColor.withOpacity(0.95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'community_logo_${key.toString()}', // Unique tag
                    child: CircleAvatar(
                      radius: 32, // Slightly larger avatar
                      backgroundColor: Colors.white.withOpacity(0.25),
                      backgroundImage: logoUrl != null && logoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(logoUrl!)
                          : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider, // Fallback
                      child: (logoUrl == null || logoUrl!.isEmpty) && name.isNotEmpty
                          ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                  ),
                ),
              ),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (description != null && description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(), // Pushes stats and button to bottom
                      Row( // Stats and Join Button
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row( // Member and Online Counts
                            children: [
                              Icon(Icons.group_outlined, size: 15, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text('$memberCount', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(width: 8),
                              Icon(Icons.circle, size: 8, color: Colors.tealAccent[400]), // Online indicator
                              const SizedBox(width: 3),
                              Text('$onlineCount', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                          SizedBox( // Join/Leave Button
                            height: 28,
                            child: TextButton(
                              onPressed: onJoin,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: isJoined
                                    ? (isDark ? Colors.grey.shade700 : Colors.grey.shade200)
                                    : backgroundColor.withOpacity(isDark ? 0.4 : 0.2),
                                foregroundColor: isJoined
                                    ? (isDark ? Colors.white70 : Colors.black54)
                                    : (isDark ? backgroundColor.brighten(0.3) : backgroundColor.darken(0.1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isJoined
                                        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade300)
                                        : backgroundColor.withOpacity(0.7),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                isJoined ? 'Joined' : 'Join',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extensions for Color
extension ColorBrightness on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color brighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslBright = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslBright.toColor();
  }
}