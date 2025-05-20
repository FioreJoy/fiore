import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// Data Layer Imports
import '../../../../../data/datasources/remote/settings_api.dart'; // For SettingsApiService

// Presentation Layer Imports
import '../../../../providers/auth_provider.dart';
import '../../../../global_widgets/custom_button.dart';

// Core Imports
import '../../../../../core/theme/theme_constants.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  _NotificationSettingsPageState createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, bool> _currentSettings = {
    'new_post_in_community': true,
    'new_reply_to_post': true,
    'new_event_in_community': true,
    'event_reminder': true,
    'direct_message': false,
    'notify_event_update': true,
  };
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final settingsService =
        Provider.of<SettingsService>(context, listen: false); // Use typedef
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = "Not auth.";
        });
      return;
    }
    try {
      final fetchedSettingsMap =
          await settingsService.getNotificationSettings(authProvider.token!);
      if (mounted)
        setState(() {
          _currentSettings = {
            for (var key in _currentSettings.keys)
              key: fetchedSettingsMap[key] is bool
                  ? fetchedSettingsMap[key]
                  : _currentSettings[key]!,
          };
          _isLoading = false;
        });
    } catch (e) {
      /* print("NotifSettings: Error loading: $e"); */ if (mounted)
        setState(() {
          _isLoading = false;
          _error = "Failed: ${e.toString().replaceFirst('Exception: ', '')}";
        });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (!mounted) return;
    setState(() {
      _currentSettings[key] = value;
      _error = null;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final settingsService = Provider.of<SettingsService>(context,
          listen: false); // Use typedef
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Auth error.')));
        return;
      }
      try {
        await settingsService.updateNotificationSettings(
          token: authProvider.token!,
          settings: _currentSettings,
        );
        if (mounted) {/* print("Settings updated for $key: $value"); */}
      } catch (e) {
        /* print("NotifSettings: Error updating '$key': $e"); */ if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Failed: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: ThemeConstants.errorColor));
      }
    });
  }

  Widget _buildSwitchItem(
      String key, String title, String subtitle, IconData icon) {
    /* ... Unchanged from settings_home, path corrections done by build context theme usage ... */
    final bool currentValue = _currentSettings[key] ?? false;
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: currentValue,
      onChanged: (bool newValue) => _updateSetting(key, newValue),
      activeColor: Theme.of(context).colorScheme.primary,
      secondary: Icon(icon,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.mediumPadding, vertical: 6.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI similar, only core path corrections above ... */
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(isDark)
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  child: ListView(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.all(ThemeConstants.mediumPadding)
                                .copyWith(bottom: ThemeConstants.smallPadding),
                        child: Text(
                          "Manage what you get notified about.",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700),
                        ),
                      ),
                      _buildSwitchItem(
                          'new_post_in_community',
                          'New Posts in Communities',
                          'When someone posts in followed communities.',
                          Icons.article_outlined),
                      _buildSwitchItem(
                          'new_reply_to_post',
                          'Replies to You',
                          'When someone replies to your posts or comments.',
                          Icons.reply_outlined),
                      _buildSwitchItem(
                          'new_event_in_community',
                          'New Events in Communities',
                          'New events in followed communities.',
                          Icons.event_note_outlined),
                      _buildSwitchItem(
                          'event_reminder',
                          'Event Reminders',
                          'Reminders for events you joined.',
                          Icons.alarm_on_outlined),
                      _buildSwitchItem(
                          'notify_event_update',
                          'Event Updates',
                          'When details of an event you joined change.',
                          Icons.edit_calendar_outlined),
                      _buildSwitchItem(
                          'direct_message',
                          'Direct Messages',
                          'When you receive a new direct message.',
                          Icons.message_outlined),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    /* ... Unchanged from notifications_screen.dart copy ... */ return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text('Failed to Load Settings',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(_error ?? "Unknown error.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
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
