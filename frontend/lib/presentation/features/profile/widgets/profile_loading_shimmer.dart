import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/theme_constants.dart'; // Adjusted path

class ProfileLoadingShimmer extends StatelessWidget {
  final bool isDark;
  const ProfileLoadingShimmer({Key? key, required this.isDark})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          // Header Shimmer
          Container(
            height: 290, // Approximate height of _buildProfileHeader
            color: Colors.white, // Base for shimmer
          ),
          // TabBar placeholder (if needed, or let AppBar handle it)
          // Container(height: kTextTabBarHeight, color: Colors.white),

          // Content Shimmer (simple list)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
              children: [
                // Simulate a few content items
                _buildShimmerItem(),
                const SizedBox(height: ThemeConstants.mediumPadding),
                _buildShimmerItem(),
                const SizedBox(height: ThemeConstants.mediumPadding),
                _buildShimmerItem(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Container(
      height: 120, // Approximate height of a PostCard or similar item
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
      ),
    );
  }
}
