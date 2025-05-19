// frontend/lib/screens/settings/settings_feature/app/app_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // For ThemeProvider

import '../../../../theme/theme_constants.dart'; // For k-style constants if used
import '../../../../app_constants.dart';
import '../../../../services/theme_provider.dart'; // Import ThemeProvider

// Optional: For dynamic version, if you re-enable it
// import 'package:package_info_plus/package_info_plus.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({Key? key}) : super(key: key);

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  String _appVersion = AppConstants.appVersion;
  bool _isLoadingVersion = false;

  @override
  void initState() {
    super.initState();
    // _loadAppVersion(); // Uncomment if using package_info_plus
  }

  /*
  Future<void> _loadAppVersion() async {
    if (!mounted) return;
    setState(() => _isLoadingVersion = true);
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
          _isLoadingVersion = false;
        });
      }
    } catch (e) {
      print("Error loading app version: $e");
      if (mounted) setState(() => _isLoadingVersion = false);
    }
  }
  */

  Future<void> _clearCache() async {
    final theme = Theme.of(context); // Get theme for dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: const Text('Clear Cache?'),
        content: const Text(
            'This will remove temporary files. Some data might need to be re-downloaded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.primary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear Cache', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      print('Clearing cache (Simulated)...');
      // TODO: Implement actual cache clearing
      await Future.delayed(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Cache cleared (Simulated)'),
            backgroundColor: ThemeConstants.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context); // For general theme properties
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Use theme's scaffoldBackgroundColor
      // backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('App Settings'),
        // Use themed AppBar settings
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildSectionHeader(context, "Appearance"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'App Theme',
                prefixIcon: Icon(Icons.palette_outlined, color: theme.colorScheme.primary.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              ),
              value: themeProvider.currentThemeName,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              elevation: 16,
              style: theme.textTheme.bodyLarge,
              dropdownColor: theme.cardColor, // Use card color for dropdown background
              onChanged: (String? newThemeName) {
                if (newThemeName != null) {
                  themeProvider.setThemeByName(newThemeName);
                }
              },
              items: themeProvider.availableThemeNames
                  .map<DropdownMenuItem<String>>((String themeName) {
                return DropdownMenuItem<String>(
                  value: themeName,
                  child: Text(themeName),
                );
              }).toList(),
            ),
          ),

          // Simple Light/Dark/System Toggle (Kept for quick user preference)
          SwitchListTile.adaptive(
            title: const Text('System Theme Override'),
            subtitle: Text('Current: ${themeProvider.themeMode.toString().split('.').last.capitalizeFirst()}'),
            value: themeProvider.themeMode != ThemeMode.system, // True if light or dark is explicitly set
            onChanged: (bool value) {
              // If turning ON override, default to current system brightness
              // If turning OFF override, switch to system
              ThemeMode newMode;
              if (value) { // Override is ON (Light or Dark mode)
                Brightness platformBrightness = MediaQuery.platformBrightnessOf(context);
                newMode = platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
                // Update currentThemeName to match the Fiore Light/Dark palette
                // This part is a bit tricky as setThemeByName is preferred.
                // For simplicity, this toggle will primarily manage the ThemeMode.
                // The specific theme (Fiore Light/Dark) will be applied by toggleSimpleTheme.
                themeProvider.toggleSimpleTheme(newMode);
              } else { // Override is OFF (System mode)
                newMode = ThemeMode.system;
                themeProvider.toggleSimpleTheme(newMode);
              }
            },
            activeColor: theme.colorScheme.secondary,
            secondary: Icon(
              themeProvider.themeMode == ThemeMode.light ? Icons.light_mode_outlined :
              themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined :
              Icons.brightness_auto_outlined, // System
              color: theme.colorScheme.primary.withOpacity(0.7)
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),


          const Divider(indent: 20, endIndent: 20, height: 30),
          _buildSectionHeader(context, "Storage & Data"),
          _buildSettingsItem(
            context,
            icon: Icons.cleaning_services_outlined,
            title: "Clear Cache",
            subtitle: "Remove temporary application data",
            onTap: _clearCache,
            iconColor: theme.colorScheme.secondary,
          ),

          const Divider(indent: 20, endIndent: 20, height: 30),
          _buildSectionHeader(context, "About"),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline_rounded,
            title: "App Version",
            subtitleWidget: _isLoadingVersion
                ? const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                : Text(_appVersion, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            iconColor: theme.colorScheme.secondary,
            // onTap: _loadAppVersion, // Optional: allow tapping to refresh version
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, left: 20.0, bottom: 8.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary.withOpacity(0.8), size: 24),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitleWidget ?? (subtitle != null ? Text(subtitle, style: theme.textTheme.bodySmall) : null),
      trailing: onTap != null ? Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.6), size: 20) : null,
      onTap: onTap,
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
    );
  }
}

// Helper extension for capitalizing first letter
extension StringExtension on String {
    String capitalizeFirst() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}
