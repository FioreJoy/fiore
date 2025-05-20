import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/theme_constants.dart'; // For padding constants
import 'profile_loading_shimmer.dart'; // Import the content loading shimmer for the tab

class ProfileContentTab extends StatelessWidget {
  final bool isLoading; // Specific to this tab's content
  final String? error;
  final List<dynamic> items;
  final String emptyMessage;
  final Widget Function(BuildContext context, Map<String, dynamic> itemData)
      itemBuilder;
  final String tabKey; // For PageStorageKey
  final VoidCallback? onRetry; // If loading fails for this tab

  const ProfileContentTab({
    Key? key,
    required this.isLoading,
    this.error,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
    required this.tabKey,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // This SafeArea is important because ProfileScreen uses NestedScrollView,
    // and content within TabBarView might get obscured by top elements
    // if not properly handled with SliverOverlapAbsorber/Injector (which is done in parent).
    // This specific SafeArea is for the *content* of the tab itself.
    return SafeArea(
      top: false, // The parent SliverAppBar already handles top safe area.
      bottom: false,
      child: Builder(
        // Needed to get correct context for NestedScrollView
        builder: (BuildContext context) {
          if (isLoading) {
            // Use a simpler shimmer for tab content
            return ListView.builder(
              padding: const EdgeInsets.all(
                  ThemeConstants.smallPadding), // Adjusted from medium to small
              itemCount: 5,
              itemBuilder: (ctx, idx) => Shimmer.fromColors(
                baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                child: Container(
                  height: 100, // Approximate item height
                  margin: const EdgeInsets.only(
                      bottom: ThemeConstants.smallPadding),
                  decoration: BoxDecoration(
                    color: Colors.white, // Base for shimmer
                    borderRadius: BorderRadius.circular(
                        ThemeConstants.cardBorderRadius / 2),
                  ),
                ),
              ),
            );
          }

          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConstants.largePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: ThemeConstants.errorColor.withOpacity(0.8),
                        size: 40),
                    const SizedBox(height: ThemeConstants.mediumPadding),
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700)),
                    if (onRetry != null) ...[
                      const SizedBox(height: ThemeConstants.mediumPadding),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.1),
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                      )
                    ]
                  ],
                ),
              ),
            );
          }

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConstants.largePadding * 2),
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // For CustomScrollView context within NestedScrollView
          return CustomScrollView(
            key: PageStorageKey<String>(tabKey), // Keep state for each tab
            slivers: <Widget>[
              // This SliverOverlapInjector is crucial when TabBarView is inside NestedScrollView
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ThemeConstants.smallPadding / 2,
                    vertical: ThemeConstants
                        .smallPadding), // Reduced padding for list
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return itemBuilder(
                          context, items[index] as Map<String, dynamic>);
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
