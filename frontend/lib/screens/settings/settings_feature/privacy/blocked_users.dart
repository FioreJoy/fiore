// frontend/lib/screens/settings/settings_feature/privacy/blocked_users.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Updated Service Imports ---
import '../../../../services/api/block_service.dart'; // Use specific BlockService
import '../../../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../../../widgets/custom_button.dart'; // For retry and potentially unblock

// --- Theme and Constants ---
import '../../../../theme/theme_constants.dart';
import '../../../../app_constants.dart'; // For default avatar

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _blockedUsers = []; // Store list of blocked user maps

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final blockService = Provider.of<BlockService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Still need to check if authenticated before making the call
    if (!authProvider.isAuthenticated) {
      setState(() { _isLoading = false; _error = "Not authenticated or configuration error."; });
      return;
    }

    try {
      // <<< FIX: Removed explicit token parameter >>>
      // Assumes BlockService uses an ApiClient that handles auth
      final fetchedList = await blockService.getBlockedUsers();
      if (mounted) {
        setState(() {
          // Assuming the list contains Maps matching BlockedUserDisplay schema
          _blockedUsers = List<dynamic>.from(fetchedList);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("BlockedUsersScreen: Error loading blocked users: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load blocked users: ${e.toString().replaceFirst('Exception: ', '')}";
        });
      }
    }
  }

  Future<void> _unblockUser(int userIdToUnblock, String username) async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock $username?'),
        content: const Text('Are you sure you want to unblock this user? They will be able to see your content and interact with you again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('Unblock')
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final blockService = Provider.of<BlockService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Still need to check if authenticated before making the call
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error or configuration error.'), backgroundColor: Colors.red));
      return;
    }

    try {
      // <<< FIX: Removed explicit token parameter >>>
      // Assumes BlockService uses an ApiClient that handles auth
      await blockService.unblockUser(userIdToUnblock: userIdToUnblock);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$username unblocked successfully.'), backgroundColor: ThemeConstants.successColor),
        );
        // Remove the user from the local list immediately for faster UI update
        setState(() {
          _blockedUsers.removeWhere((user) => user['blocked_user_id'] == userIdToUnblock);
        });
        // Optionally call _fetchBlockedUsers() again to ensure sync, but removing locally is faster.
        // _fetchBlockedUsers();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock $username: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: RefreshIndicator( // Allow pull-to-refresh
        onRefresh: _fetchBlockedUsers,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView();
    }
    if (_blockedUsers.isEmpty) {
      return _buildEmptyView();
    }

    // Display the list
    return ListView.separated(
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final blockedInfo = _blockedUsers[index] as Map<String, dynamic>;
        final int userId = blockedInfo['blocked_user_id'] ?? 0;
        final String username = blockedInfo['blocked_username'] ?? 'Unknown User';
        final String? avatarUrl = blockedInfo['blocked_user_avatar_url']; // Get avatar URL if backend sends it
        final String blockedAt = blockedInfo['blocked_at'] != null
            ? TimeAgo.timeAgoSinceDate(blockedInfo['blocked_at']) // Use time ago format
            : 'Unknown date';

        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
          ),
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text("Blocked $blockedAt"),
          trailing: TextButton(
            child: const Text('Unblock', style: TextStyle(color: ThemeConstants.errorColor)),
            onPressed: () => _unblockUser(userId, username),
          ),
          // Optional: onTap to navigate to user profile? (if possible)
          // onTap: () { ... },
        );
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Widget _buildErrorView() {
    return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: 16),
      Text(_error ?? 'Failed to load blocked users.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)), const SizedBox(height: 24),
      CustomButton( text: 'Retry', icon: Icons.refresh, onPressed: _fetchBlockedUsers, type: ButtonType.secondary,),],),),);
  }

  Widget _buildEmptyView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.person_off_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400), const SizedBox(height: 16),
      Text('No Blocked Users', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      const SizedBox(height: 8),
      Text('You haven\'t blocked anyone yet.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
    ],),),);
  }
}


// --- Helper for Time Ago Formatting (Simple Example) ---
// Consider using the `timeago` package for more robust formatting: https://pub.dev/packages/timeago
class TimeAgo {
  static String timeAgoSinceDate(String dateString, {bool numericDates = true}) {
    DateTime? notificationDate = DateTime.tryParse(dateString)?.toLocal();
    if (notificationDate == null) return dateString; // Return original if parsing fails

    final date2 = DateTime.now().toLocal();
    final difference = date2.difference(notificationDate);

    if (difference.inSeconds < 5) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return (difference.inMinutes == 1) ? '1 minute ago' : '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return (difference.inHours == 1) ? '1 hour ago' : '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return (difference.inDays == 1) ? '1 day ago' : '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      // Roughly weeks
      final weeks = (difference.inDays / 7).floor();
      return (weeks <= 1) ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      // Roughly months
      final months = (difference.inDays / 30).floor();
      return (months <= 1) ? '1 month ago' : '$months months ago';
    } else {
      // Roughly years
      final years = (difference.inDays / 365).floor();
      return (years <= 1) ? '1 year ago' : '$years years ago';
    }
  }
}