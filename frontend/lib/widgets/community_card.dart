import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/theme_constants.dart';

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
    required this.onlineCount,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust text styling based on card width
        final bool isNarrow = constraints.maxWidth < 180;
        final double nameSize = isNarrow ? 13.0 : 15.0;
        final double descSize = isNarrow ? 10.0 : 12.0;
        final int descMaxLines = isNarrow ? 2 : 3;
        final double iconSize = isNarrow ? 14.0 : 16.0;

        return Material(
          color: isDark ? ThemeConstants.backgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with color and logo
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [backgroundColor.withOpacity(0.8), backgroundColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Logo (centered top)
                        Positioned.fill(
                          child: Center(
                            child: Hero(
                              tag: 'community_logo_${key.toString()}',
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                backgroundImage: logoUrl != null
                                    ? CachedNetworkImageProvider(logoUrl!)
                                    : null,
                                child: logoUrl == null
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content area (Flexible to handle varying heights)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Community name
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: nameSize,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Description with flexible height
                          Expanded(
                            child: Text(
                              description ?? 'No description',
                              style: TextStyle(
                                fontSize: descSize,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                height: 1.2,
                              ),
                              maxLines: descMaxLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Stats row
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: iconSize,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount',
                                style: TextStyle(
                                  fontSize: descSize,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.circle,
                                size: iconSize - 4,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$onlineCount',
                                style: TextStyle(
                                  fontSize: descSize,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              // Join button - made smaller & more compact
                              SizedBox(
                                height: 28,
                                width: isNarrow ? 50 : 60,
                                child: TextButton(
                                  onPressed: onJoin,
                                  style: TextButton.styleFrom(
                                    backgroundColor: isJoined
                                        ? Colors.grey.withOpacity(0.2)
                                        : backgroundColor.withOpacity(0.2),
                                    foregroundColor: isJoined
                                        ? Colors.grey
                                        : backgroundColor,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                        color: isJoined
                                            ? Colors.grey
                                            : backgroundColor,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isJoined ? 'Leave' : 'Join',
                                    style: TextStyle(
                                      fontSize: descSize,
                                      fontWeight: FontWeight.bold,
                                    ),
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
    );
  }
}
