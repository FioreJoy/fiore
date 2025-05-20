import 'package:flutter/material.dart';

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _profileVisibleToAll = true;
  bool _activityStatusVisible = true;
  bool _allowMessageRequests = true;
  bool _twoFactorEnabled = false;

  Future<void> _updatePreference(String key, bool value) async {
    // print('Updating $key to $value'); // Debug Removed
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('$key updated (Simulated)'), duration: const Duration(seconds: 1), backgroundColor: ThemeConstants.accentColor), // Using ThemeConstant, assumes theme consistency for now
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Controls')),
      body: ListView( children: [
          _buildSectionHeader(context, "Profile Visibility"),
          SwitchListTile.adaptive(
            title: const Text('Public Profile'), subtitle: const Text('Allow anyone to view your profile'),
            value: _profileVisibleToAll, onChanged: (value) { setState(() => _profileVisibleToAll = value); _updatePreference('profileVisibleToAll', value);},
            activeColor: theme.colorScheme.secondary, secondary: Icon(Icons.visibility_outlined, color: theme.iconTheme.color),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
          _buildSectionHeader(context, "Activity Status"),
          SwitchListTile.adaptive(
            title: const Text('Show Activity Status'), subtitle: const Text('Allow others to see when you are online'),
            value: _activityStatusVisible, onChanged: (value) { setState(() => _activityStatusVisible = value); _updatePreference('activityStatusVisible', value);},
            activeColor: theme.colorScheme.secondary, secondary: Icon(Icons.online_prediction, color: theme.iconTheme.color),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
          _buildSectionHeader(context, "Direct Messages"),
          SwitchListTile.adaptive(
            title: const Text('Allow Message Requests'), subtitle: const Text('Allow non-followers to send requests'),
            value: _allowMessageRequests, onChanged: (value) { setState(() => _allowMessageRequests = value); _updatePreference('allowMessageRequests', value);},
            activeColor: theme.colorScheme.secondary, secondary: Icon(Icons.message_outlined, color: theme.iconTheme.color),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
           _buildSectionHeader(context, "Security"),
          SwitchListTile.adaptive(
            title: const Text('Two-Factor Authentication'), subtitle: Text(_twoFactorEnabled ? 'Enabled' : 'Disabled - Extra security layer'),
            value: _twoFactorEnabled, onChanged: (value) { setState(() => _twoFactorEnabled = value); _updatePreference('twoFactorEnabled', value);},
            activeColor: theme.colorScheme.secondary, secondary: Icon(Icons.security_outlined, color: theme.iconTheme.color),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
        ],
      ),
    );
  }

   Widget _buildSectionHeader(BuildContext context, String title) {
     return Padding(
       padding: const EdgeInsets.only(top: 20.0, left: 20.0, bottom: 8.0, right: 16.0),
       child: Text( title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith( color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 0.7, ),),);
   }
}
