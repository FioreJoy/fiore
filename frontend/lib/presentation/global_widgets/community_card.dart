import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Core Imports
import '../../core/theme/theme_constants.dart'; // Corrected Path
import '../../../app_constants.dart'; // Corrected Path

class CommunityCard extends StatelessWidget {
  final String name;
  final String? description;
  final int memberCount;
  final int onlineCount;
  final String? logoUrl;
  final Color backgroundColor;
  final bool isJoined;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const CommunityCard({
    Key? key,
    required this.name,
    this.description,
    required this.memberCount,
    this.onlineCount = 0,
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
            borderRadius:
                BorderRadius.circular(ThemeConstants.cardBorderRadius),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 85,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      backgroundColor.withOpacity(0.7),
                      backgroundColor.withOpacity(0.95)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'community_logo_${key.toString()}',
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      backgroundImage: logoUrl != null && logoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(logoUrl!)
                          : const NetworkImage(AppConstants.defaultAvatar)
                              as ImageProvider,
                      child: (logoUrl == null || logoUrl!.isEmpty) &&
                              name.isNotEmpty
                          ? Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          if (description != null &&
                              description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 15, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text('$memberCount',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              const SizedBox(width: 8),
                              Icon(Icons.circle,
                                  size: 8, color: Colors.tealAccent[400]),
                              const SizedBox(width: 3),
                              Text('$onlineCount',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              onPressed: onJoin,
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: isJoined
                                    ? (isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200)
                                    : backgroundColor
                                        .withOpacity(isDark ? 0.4 : 0.2),
                                foregroundColor: isJoined
                                    ? (isDark ? Colors.white70 : Colors.black54)
                                    : (isDark
                                        ? backgroundColor.brighten(0.3)
                                        : backgroundColor.darken(0.1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isJoined
                                        ? (isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade300)
                                        : backgroundColor.withOpacity(0.7),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                isJoined ? 'Joined' : 'Join',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
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

// ColorBrightness extension remains the same
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
    final hslBright =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslBright.toColor();
  }
}
