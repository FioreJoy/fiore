import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart';
import '../../../../../../app_constants.dart';
import '../../../../../core/theme/theme_provider.dart'; // For ThemeProvider

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({Key? key}) : super(key: key);

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  String _appVersion = AppConstants.appVersion;
  bool _isLoadingVersion = false; // In case package_info_plus is re-enabled

  @override
  void initState() {
    super.initState();
    // _loadAppVersion(); // If package_info_plus is used later
  }

  Future<void> _clearCache() async {
    final theme = Theme.of(context);
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
              child: Text('Cancel',
                  style: TextStyle(color: theme.colorScheme.primary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear Cache',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // print('Clearing cache (Simulated)...'); // Debug print removed
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cache cleared (Simulated)'),
              backgroundColor: ThemeConstants.successColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildSectionHeader(context, "Appearance"),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'App Theme',
                prefixIcon: Icon(Icons.palette_outlined,
                    color: theme.colorScheme.primary.withOpacity(0.7)),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(ThemeConstants.borderRadius)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              ),
              value: themeProvider.currentThemeName,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              elevation: 16,
              style: theme.textTheme.bodyLarge,
              dropdownColor: theme.cardColor,
              onChanged: (String? newThemeName) {
                if (newThemeName != null)
                  themeProvider.setThemeByName(newThemeName);
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
          SwitchListTile.adaptive(
            title: const Text('System Theme Override'),
            subtitle: Text(
                'Current: ${themeProvider.themeMode.toString().split('.').last.capitalizeFirst()}'),
            value: themeProvider.themeMode != ThemeMode.system,
            onChanged: (bool value) {
              ThemeMode newMode;
              if (value) {
                Brightness platformBrightness =
                    MediaQuery.platformBrightnessOf(context);
                newMode = platformBrightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light;
                themeProvider.toggleSimpleTheme(newMode);
              } else {
                newMode = ThemeMode.system;
                themeProvider.toggleSimpleTheme(newMode);
              }
            },
            activeColor: theme.colorScheme.secondary,
            secondary: Icon(
                themeProvider.themeMode == ThemeMode.light
                    ? Icons.light_mode_outlined
                    : themeProvider.themeMode == ThemeMode.dark
                        ? Icons.dark_mode_outlined
                        : Icons.brightness_auto_outlined,
                color: theme.colorScheme.primary.withOpacity(0.7)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          ),
          const Divider(indent: 20, endIndent: 20, height: 30),
          _buildSectionHeader(context, "Storage & Data"),
          _buildSettingsItem(
            context,
            icon: Icons.cleaning_services_outlined,
            title: "Clear Cache",
            subtitle: "Remove temporary app data",
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
                ? const SizedBox(
                    height: 10,
                    width: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5))
                : Text(_appVersion,
                    style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            iconColor: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    /* ... Unchanged ... */ return Padding(
      padding: const EdgeInsets.only(
          top: 15.0, left: 20.0, bottom: 8.0, right: 16.0),
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
    /* ... Unchanged ... */ final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      leading: Icon(icon,
          color: iconColor ?? theme.colorScheme.primary.withOpacity(0.8),
          size: 24),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitleWidget ??
          (subtitle != null
              ? Text(subtitle, style: theme.textTheme.bodySmall)
              : null),
      trailing: onTap != null
          ? Icon(Icons.chevron_right,
              color: theme.iconTheme.color?.withOpacity(0.6), size: 20)
          : null,
      onTap: onTap,
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
    );
  }
}

extension StringExtensionCapitalize on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
