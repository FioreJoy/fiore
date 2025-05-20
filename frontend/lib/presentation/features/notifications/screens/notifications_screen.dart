import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Presentation Layer ---
import '../../../providers/notification_provider.dart'; // Corrected path
import '../../../global_widgets/notification_item_card.dart'; // Corrected path
import '../../../global_widgets/custom_button.dart'; // Corrected path

// --- Data Layer ---
import '../../../../data/models/notification_model.dart'; // Corrected path

// --- Core ---
import '../../../../core/theme/theme_constants.dart'; // Corrected path

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !provider.isLoadingMore &&
          provider.canLoadMore) {
        // It's important that fetchNotifications can handle being called
        // even if the current state doesn't strictly need more data yet.
        // It internally checks _isLoadingMore and _canLoadMore again.
        provider.fetchNotifications();
      }
    });
    // Initial fetch might be triggered by provider itself or here after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider =
            Provider.of<NotificationProvider>(context, listen: false);
        // If notifications are empty and not loading, fetch them.
        // Or, if provider handles initial fetch, this might be redundant or for explicit reload.
        if (provider.notifications.isEmpty && !provider.isLoading) {
          provider.resetAndFetchNotifications();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    await Provider.of<NotificationProvider>(context, listen: false)
        .resetAndFetchNotifications();
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (!notification.isRead) {
      provider.markNotificationAsRead(notification.id);
    }
    String? entityType = notification.relatedEntity?.type
        ?.toString()
        .split('.')
        .last; // Get enum value string
    int? entityId = notification.relatedEntity?.id;
    String? entityTitle = notification.relatedEntity?.title;

    // print("Notification tapped: Type: ${notification.type}, Entity: $entityType ($entityId) - ${entityTitle ?? ''}"); // Debug print removed

    if (entityType != null && entityId != null) {
      // TODO: Implement actual navigation based on entityType and entityId
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to $entityType ID: $entityId')));
    } else {
      // print("Notification tapped (no entity): ${notification.message}"); // Debug print removed
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(notification.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notificationProvider.unreadCount > 0 &&
              !notificationProvider.isLoading)
            TextButton(
              onPressed: () async {
                await notificationProvider.markAllNotificationsAsRead();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('All marked as read.'),
                        duration: Duration(seconds: 1)),
                  );
              },
              child: Text('Mark All Read',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: notificationProvider.isLoading ||
                    notificationProvider.isLoadingMore
                ? null
                : _refreshNotifications,
          ),
        ],
      ),
      body: _buildBody(notificationProvider, isDark),
    );
  }

  Widget _buildBody(NotificationProvider provider, bool isDark) {
    if (provider.isLoading && provider.notifications.isEmpty)
      return _buildLoadingShimmer();
    if (provider.error != null && provider.notifications.isEmpty)
      return _buildErrorView(provider.error!, isDark, provider);
    if (provider.notifications.isEmpty)
      return _buildEmptyView(isDark, provider);

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.separated(
        controller: _scrollController,
        itemCount:
            provider.notifications.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.notifications.length && provider.isLoadingMore)
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2.0)));
          if (index >= provider.notifications.length)
            return const SizedBox.shrink();
          final notification = provider.notifications[index];
          return NotificationItemCard(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onMarkAsRead: () =>
                provider.markNotificationAsRead(notification.id),
          );
        },
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    /* ... UI unchanged ... */ final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: double.infinity,
                        height: 14.0,
                        color: Colors.white),
                    const SizedBox(height: 6),
                    Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 12.0,
                        color: Colors.white),
                    const SizedBox(height: 4),
                    Container(
                        width: MediaQuery.of(context).size.width * 0.3,
                        height: 10.0,
                        color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(
      String errorMsg, bool isDark, NotificationProvider provider) {
    /* ... UI unchanged ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text('Failed to Load Notifications',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: ThemeConstants.largePadding),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: () => provider.resetAndFetchNotifications(),
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark, NotificationProvider provider) {
    /* ... UI unchanged ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Notifications Yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              'When you get new notifications, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Refresh',
              icon: Icons.refresh,
              onPressed: () => provider.resetAndFetchNotifications(),
              type: ButtonType.outline,
            ),
          ],
        ),
      ),
    );
  }
}
