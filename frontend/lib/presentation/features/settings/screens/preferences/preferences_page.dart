import 'package:flutter/material.dart';
// For this placeholder, provider and complex state management are not used,
// but paths for theme and global widgets are corrected.
// If real logic were added, would need provider and service imports.

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart'; // Corrected Path, only for k-style color if really needed

// --- Presentation Imports ---
// import '../../../../global_widgets/custom_button.dart'; // Not used here
// import '../../../../providers/theme_provider.dart'; // If using ThemeProvider

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  // Using local state for theme toggle for this simple example
  // In a real app, this would be driven by ThemeProvider
  bool isDark = true; // Placeholder for theme state
  bool _locationVisible = true;
  List<String> _selectedInterests = ['Movies', 'Hackathons'];

  final List<String> _availableInterests = [
    'Movies',
    'Sports',
    'Hackathons',
    'Music',
    'Gaming',
    'Art',
    'Travel',
    'Food'
  ];

  void _toggleTheme(bool value) {
    setState(() => isDark = value);
    // In real app: Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
    // print('Dark Mode Toggled (local state): $isDark'); // Debug
  }

  void _toggleLocation(bool value) {
    setState(() => _locationVisible = value);
    // TODO: Save preference
    // print('Location Visibility Toggled: $_locationVisible'); // Debug
  }

  void _updateInterests() {
    // print('Update Interests Tapped. Current: $_selectedInterests'); // Debug
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest selection placeholder')));
  }

  @override
  Widget build(BuildContext context) {
    // For real app, get actual isDark from ThemeProvider
    // final themeProvider = Provider.of<ThemeProvider>(context);
    // isDark = themeProvider.themeMode == ThemeMode.dark ||
    //          (themeProvider.themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final currentTheme = Theme.of(context); // Use current theme for colors

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildSectionHeader(context, "Appearance"),
          SwitchListTile.adaptive(
            title: const Text('Dark Mode'),
            subtitle: const Text('Reduce eye strain'),
            value: isDark,
            onChanged: _toggleTheme,
            activeColor: currentTheme.colorScheme.secondary,
            secondary: Icon(Icons.dark_mode_outlined,
                color: currentTheme.iconTheme.color),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
          Divider(
              color: currentTheme.dividerColor,
              indent: 20,
              endIndent: 20,
              height: 20),
          _buildSectionHeader(context, "Content"),
          _buildPreferenceItem(
            context: context,
            icon: Icons.interests_outlined,
            title: "Preferred Interests",
            subtitle: _selectedInterests.isNotEmpty
                ? 'Tap to update (${_selectedInterests.join(', ')})'
                : 'Tap to select interests',
            onTap: _updateInterests,
          ),
          Divider(
              color: currentTheme.dividerColor,
              indent: 20,
              endIndent: 20,
              height: 20),
          _buildSectionHeader(context, "Location"),
          SwitchListTile.adaptive(
            title: const Text('Location Suggestions'),
            subtitle: const Text('Allow suggestions based on location'),
            value: _locationVisible,
            onChanged: _toggleLocation,
            activeColor: currentTheme.colorScheme.secondary,
            secondary: Icon(Icons.location_on_outlined,
                color: currentTheme.iconTheme.color),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    /* ... Use Theme.of(context) ... */
    return Padding(
      padding: const EdgeInsets.only(
          top: 15.0, left: 20.0, bottom: 5.0, right: 20.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
      ),
    );
  }

  Widget _buildPreferenceItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    /* ... Use Theme.of(context) ... */
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(Icons.chevron_right,
          color: theme.iconTheme.color?.withOpacity(0.6)),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
    );
  }
}
