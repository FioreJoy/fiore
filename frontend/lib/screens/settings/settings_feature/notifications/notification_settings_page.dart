// frontend/lib/screens/settings/settings_feature/notifications/notification_settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// --- Updated Service Imports ---
import '../../../../services/api/settings_service.dart'; // Use specific SettingsService
import '../../../../services/auth_provider.dart';

// --- Theme and Constants ---
import '../../../../theme/theme_constants.dart';
import '../../../../widgets/custom_button.dart'; // Assuming path is correct

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  String? _error;
  // Store settings locally, initialize with defaults or fetched values
  Map<String, bool> _currentSettings = {
    'new_post_in_community': true, // Default value
    'new_reply_to_post': true,     // Default value
    'new_event_in_community': true,// Default value
    'event_reminder': true,        // Default value
    'direct_message': false,       // Default value
    // Add more keys as defined by your backend schema
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() { _isLoading = false; _error = "Not authenticated."; });
      return;
    }

    try {
      // Fetch settings without passing the token as a named parameter
      final fetchedSettingsMap = await settingsService.getNotificationSettings();

      if (mounted) {
        setState(() {
          // Update local state, ensuring type safety
          _currentSettings = Map<String, bool>.fromEntries(
              fetchedSettingsMap.entries.map((entry) {
                // Ensure values are booleans, provide default if type is wrong or key missing
                final value = entry.value;
                return MapEntry(entry.key, value is bool ? value : (_currentSettings[entry.key] ?? false));
              })
          );
          // Add any keys missing from response but present in defaults
          _currentSettings.keys.forEach((key) {
            if (!fetchedSettingsMap.containsKey(key)) {
              _currentSettings[key] = _currentSettings[key] ?? false; // Keep default if missing
            }
          });

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

  // Debounce mechanism to avoid rapid API calls when toggling switches
  Timer? _debounce;

  Future<void> _updateSetting(String key, bool value) async {
    if (!mounted) return;

    // Update local state immediately for responsive UI
    setState(() {
      _currentSettings[key] = value;
      _error = null; // Clear previous errors on new action
    });

    // Debounce the API call
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () async { // Wait 750ms after last change
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.'), backgroundColor: Colors.red));
        // Optionally revert local state here if needed
        return;
      }

      try {
        // Send the *entire* settings map to the backend PUT endpoint
        await settingsService.updateNotificationSettings(
          settings: _currentSettings,
        );
        if (mounted) {
          print("Notification settings updated successfully.");
          // Optional: Show a temporary success indicator
          // ScaffoldMessenger.of(context).showSnackBar(
          //    const SnackBar(content: Text('Settings saved.'), duration: Duration(seconds: 1)),
          // );
        }
      } catch (e) {
        print("NotificationSettingsPage: Error updating settings: $e");
        if (mounted) {
          // Show error and potentially revert the specific toggle that failed?
          // Reverting might be confusing, showing a general error is safer.
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save setting: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red)
          );
          // Revert the toggle optimistically? Or reload all settings?
          // Reloading might be best to ensure consistency after an error.
          // _loadSettings(); // Uncomment to force reload on error
          // OR revert the specific key:
          // setState(() => _currentSettings[key] = !value);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel timer if page is disposed
    super.dispose();
  }


  // Helper to build SwitchListTile items
  Widget _buildSwitchItem(String key, String title, String subtitle) {
    // Use a default value if the key is somehow missing after loading
    final bool currentValue = _currentSettings[key] ?? false;

    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: currentValue,
      onChanged: (bool newValue) {
        _updateSetting(key, newValue); // Update state and trigger debounced API call
      },
      activeColor: Theme.of(context).colorScheme.primary,
      secondary: Icon(_getIconForKey(key)), // Get relevant icon
    );
  }

  // Helper to get an icon based on the setting key (customize as needed)
  IconData _getIconForKey(String key) {
    switch (key) {
      case 'new_post_in_community': return Icons.article_outlined;
      case 'new_reply_to_post': return Icons.reply_outlined;
      case 'new_event_in_community': return Icons.event_outlined;
      case 'event_reminder': return Icons.alarm;
      case 'direct_message': return Icons.message_outlined;
      default: return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : ListView(
        children: [
          // Dynamically create list tiles based on keys in _currentSettings
          // Or define them explicitly if the keys are fixed
          _buildSwitchItem(
            'new_post_in_community',
            'New Posts in Communities',
            'Get notified when someone posts in a community you follow.',
          ),
          _buildSwitchItem(
            'new_reply_to_post',
            'Replies to Your Posts/Comments',
            'Get notified when someone replies to you.',
          ),
          _buildSwitchItem(
            'new_event_in_community',
            'New Events in Communities',
            'Get notified about new events in communities you follow.',
          ),
          _buildSwitchItem(
            'event_reminder',
            'Event Reminders',
            'Get reminders for events you have joined.',
          ),
          _buildSwitchItem(
            'direct_message',
            'Direct Messages',
            'Get notified when you receive a direct message (if applicable).',
          ),

          // Add more settings based on your backend schema...
          // Example:
          // const Divider(),
          // _buildSwitchItem(
          //  'marketing_emails',
          //  'Promotions & Updates',
          //  'Receive occasional updates and offers via email.',
          // ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: 16),
      Text(_error ?? 'Failed to load settings.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)), const SizedBox(height: 24),
      CustomButton( text: 'Retry', icon: Icons.refresh, onPressed: _loadSettings, type: ButtonType.secondary,),],),),);
  }
}
