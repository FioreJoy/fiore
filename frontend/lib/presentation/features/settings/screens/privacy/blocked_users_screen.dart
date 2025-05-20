import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Data Layer
import '../../../../../data/datasources/remote/block_api.dart'; // For BlockApiService

// Presentation Layer
import '../../../../providers/auth_provider.dart';
import '../../../../global_widgets/custom_button.dart'; // For retry button

// Core
import '../../../../../core/theme/theme_constants.dart';
import '../../../../../../app_constants.dart'; // For default avatar

// Helper for Time Ago Formatting (If not already in a central util file)
class TimeAgoHelper {
  static String timeAgoSinceDate(String? dateString,
      {bool numericDates = true}) {
    if (dateString == null) return 'Unknown date';
    DateTime? notificationDate = DateTime.tryParse(dateString)?.toLocal();
    if (notificationDate == null) return dateString;
    final date2 = DateTime.now().toLocal();
    final difference = date2.difference(notificationDate);
    if (difference.inSeconds < 5)
      return 'just now';
    else if (difference.inSeconds < 60)
      return '${difference.inSeconds}s ago';
    else if (difference.inMinutes < 60)
      return (difference.inMinutes == 1)
          ? '1m ago'
          : '${difference.inMinutes}m ago';
    else if (difference.inHours < 24)
      return (difference.inHours == 1)
          ? '1h ago'
          : '${difference.inHours}h ago';
    else if (difference.inDays < 7)
      return (difference.inDays == 1) ? '1d ago' : '${difference.inDays}d ago';
    else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return (weeks <= 1) ? '1w ago' : '$weeks w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return (months <= 1) ? '1mo ago' : '$months mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return (years <= 1) ? '1y ago' : '$years y ago';
    }
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _blockedUsers = [];

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
    final blockService =
        Provider.of<BlockService>(context, listen: false); // Use typedef
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      setState(() {
        _isLoading = false;
        _error = "Not auth.";
      });
      return;
    }
    try {
      final fetchedList =
          await blockService.getBlockedUsers(authProvider.token!);
      if (mounted)
        setState(() {
          _blockedUsers = List<dynamic>.from(fetchedList);
          _isLoading = false;
        });
    } catch (e) {
      // print("BlockedUsersScreen error: $e"); // Debug removed
      if (mounted)
        setState(() {
          _isLoading = false;
          _error =
              "Failed to load: ${e.toString().replaceFirst('Exception: ', '')}";
        });
    }
  }

  Future<void> _unblockUser(int userIdToUnblock, String username) async {
    /* ... Unchanged except API service call ... */
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock $username?'),
        content: const Text('They will be able to see your content.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('Unblock')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final blockService =
        Provider.of<BlockService>(context, listen: false); // Use typedef
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Auth error.'), backgroundColor: Colors.red));
      return;
    }
    try {
      await blockService.unblockUser(
          token: authProvider.token!, userIdToUnblock: userIdToUnblock);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$username unblocked.'),
              backgroundColor: ThemeConstants.successColor),
        );
        setState(() => _blockedUsers.removeWhere((user) =>
            user['blocked_user_id'] == userIdToUnblock ||
            user['blocked_id'] == userIdToUnblock));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to unblock $username: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.red),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI logic using local methods for build is fine ... */
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body:
          RefreshIndicator(onRefresh: _fetchBlockedUsers, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    /* ... Ensure correct keys for data ... */
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorView();
    if (_blockedUsers.isEmpty) return _buildEmptyView();
    return ListView.separated(
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final blockedInfo = _blockedUsers[index] as Map<String, dynamic>;
        final int userId = blockedInfo['blocked_id'] ??
            blockedInfo['blocked_user_id'] ??
            0; // Check both keys as per prev. code
        final String username =
            blockedInfo['blocked_username'] ?? 'Unknown User';
        final String? avatarUrl = blockedInfo['blocked_user_avatar_url'];
        final String blockedAt = blockedInfo['blocked_at'] != null
            ? TimeAgoHelper.timeAgoSinceDate(blockedInfo['blocked_at'])
            : 'Unknown date';
        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : const NetworkImage(AppConstants.defaultAvatar)
                    as ImageProvider,
          ),
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text("Blocked $blockedAt"),
          trailing: TextButton(
            child: const Text('Unblock',
                style: TextStyle(color: ThemeConstants.errorColor)),
            onPressed: () => _unblockUser(userId, username),
          ),
        );
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Widget _buildErrorView() {
    /* ... UI unchanged ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(_error ?? 'Failed to load.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _fetchBlockedUsers,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    /* ... UI unchanged ... */ final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Blocked Users',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('You haven\'t blocked anyone yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
