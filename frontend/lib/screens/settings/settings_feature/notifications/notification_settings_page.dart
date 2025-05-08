// frontend/lib/screens/settings/settings_feature/notifications/notification_settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../../../services/api/settings_service.dart';
import '../../../../services/auth_provider.dart';
import '../../../../theme/theme_constants.dart';
import '../../../../widgets/custom_button.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  String? _error;

  // Keys must match the Pydantic schema (NotificationSettings) and backend DB columns
  Map<String, bool> _currentSettings = {
    'new_post_in_community': true,
    'new_reply_to_post': true,
    'new_event_in_community': true,
    'event_reminder': true,
    'direct_message': false, // As per schema default
    'notify_event_update': true, // New setting from backend plan
    // Add other settings as they are defined in your backend User model's notify_* columns
    // 'notify_post_vote': true,
    // 'notify_user_mention': true,
  };

  // For debouncing API calls
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) setState(() { _isLoading = false; _error = "Not authenticated."; });
      return;
    }

    try {
      final fetchedSettingsMap = await settingsService.getNotificationSettings(authProvider.token!);
      if (mounted) {
        setState(() {
          // Update local state with fetched values, falling back to current defaults if a key is missing
          _currentSettings = {
            for (var key in _currentSettings.keys)
              key: fetchedSettingsMap[key] is bool ? fetchedSettingsMap[key] : _currentSettings[key]!,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print("NotificationSettingsPage: Error loading settings: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load settings: ${e.toString().replaceFirst('Exception: ', '')}";
        });
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (!mounted) return;
    setState(() { _currentSettings[key] = value; _error = null; });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.')));
        // Optionally revert state: _loadSettings();
        return;
      }

      try {
        // Send the entire currentSettings map for update
        await settingsService.updateNotificationSettings(
          token: authProvider.token!,
          settings: _currentSettings,
        );
        if (mounted) {
          print("Notification settings updated for key: $key, value: $value");
          // Optional: subtle success feedback
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Preference saved.'), duration: Duration(seconds: 1)),
          // );
        }
      } catch (e) {
        print("NotificationSettingsPage: Error updating setting '$key': $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save setting: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor)
          );
          // Revert this specific toggle on API error to reflect actual server state
          // Or call _loadSettings() to resync everything.
          // For simplicity, we'll let the UI stay as is and user can retry or refresh.
          // setState(() => _currentSettings[key] = !value); // Revert UI
        }
      }
    });
  }

  Widget _buildSwitchItem(String key, String title, String subtitle, IconData icon) {
    final bool currentValue = _currentSettings[key] ?? false; // Default to false if key somehow missing
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: currentValue,
      onChanged: (bool newValue) => _updateSetting(key, newValue),
      activeColor: Theme.of(context).colorScheme.primary,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 6.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView(isDark)
          : RefreshIndicator( // Allow pull-to-refresh
              onRefresh: _loadSettings,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding).copyWith(bottom: ThemeConstants.smallPadding),
                    child: Text(
                      "Manage what you get notified about.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700
                      ),
                    ),
                  ),
                  _buildSwitchItem(
                    'new_post_in_community',
                    'New Posts in Communities',
                    'When someone posts in communities you follow.',
                    Icons.article_outlined,
                  ),
                  _buildSwitchItem(
                    'new_reply_to_post',
                    'Replies to You',
                    'When someone replies to your posts or comments.',
                    Icons.reply_outlined,
                  ),
                  _buildSwitchItem(
                    'new_event_in_community',
                    'New Events in Communities',
                    'When new events are created in communities you follow.',
                    Icons.event_note_outlined,
                  ),
                  _buildSwitchItem(
                    'event_reminder',
                    'Event Reminders',
                    'Reminders for events you have joined.',
                    Icons.alarm_on_outlined,
                  ),
                   _buildSwitchItem( // New setting
                    'notify_event_update', // Key matches DB column & Pydantic schema
                    'Event Updates',
                    'When details of an event you joined are changed.',
                    Icons.edit_calendar_outlined,
                  ),
                  _buildSwitchItem(
                    'direct_message',
                    'Direct Messages',
                    'When you receive a new direct message (if feature exists).',
                    Icons.message_outlined,
                  ),
                  // Add more settings here as they become available
                  // Example:
                  // const Divider(indent: 16, endIndent: 16),
                  // _buildSwitchItem(
                  //   'notify_post_vote', // Needs backend column and enum mapping
                  //   'Votes on Your Posts',
                  //   'When someone upvotes or downvotes your post.',
                  //   Icons.thumb_up_alt_outlined,
                  // ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text('Failed to Load Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(_error ?? "An unknown error occurred.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: ThemeConstants.largePadding),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _loadSettings,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
