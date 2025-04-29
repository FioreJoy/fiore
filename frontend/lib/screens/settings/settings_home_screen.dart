// frontend/lib/screens/settings/settings_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Updated Imports for Settings Sub-screens ---
import 'settings_feature/account/edit_profile.dart';
import 'settings_feature/account/change_password_page.dart';
import 'settings_feature/notifications/notification_settings_page.dart';
import 'settings_feature/privacy/privacy_security_page.dart';
import 'settings_feature/privacy/blocked_users.dart';
import 'settings_feature/app/app_settings_page.dart';
import 'settings_feature/legal/legal_policies_page.dart';
import 'settings_feature/support/support_help_page.dart';
import 'settings_feature/auth/logout_delete_page.dart';

// --- Placeholder Imports (Existing) ---

// --- Services/Providers ---
import '../../services/auth_provider.dart';
import '../../services/theme_provider.dart'; // <-- New Import for Theme toggle

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  // Helper to create list tiles
  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
    Color? iconColor,
    bool requiresAuth = false,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool canNavigate = !requiresAuth || authProvider.isAuthenticated;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: canNavigate
          ? const Icon(Icons.chevron_right)
          : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
      onTap: canNavigate
          ? () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      )
          : () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access this setting.')),
      ),
      enabled: canNavigate,
    );
  }

  // Helper for section headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context); // <-- New

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 1,
      ),
      body: ListView(
        children: <Widget>[
          _buildSectionHeader(context, 'Account Settings'),
          _buildSettingsItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update your name, username, college, avatar',
            targetScreen: const EditProfileScreen(),
            requiresAuth: true,
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your login password',
            targetScreen: const ChangePasswordPage(),
            requiresAuth: true,
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.verified_user_outlined,
            title: 'College Verification',
            subtitle: 'Verify your student status',
            targetScreen: const CollegeVerificationPage(),
            requiresAuth: true,
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.link,
            title: 'Linked Accounts',
            subtitle: 'Manage connected social accounts',
            targetScreen: const LinkedAccountsPage(),
            requiresAuth: true,
          ),

          _buildSectionHeader(context, 'App & Preferences'),
          _buildSettingsItem(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage push and email notifications',
            targetScreen: const NotificationSettingsPage(),
            requiresAuth: true,
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.tune_outlined,
            title: 'Preferences',
            subtitle: 'Feed customization, content filters',
            targetScreen: const PreferencesPage(),
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.settings_applications_outlined,
            title: 'App Settings',
            subtitle: 'Theme, data usage, language',
            targetScreen: const AppSettingsPage(),
          ),

          // Dark Mode Toggle (added after App Settings)
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
            value: themeProvider.themeMode == ThemeMode.dark ||
                (themeProvider.themeMode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark),
            onChanged: (bool value) {
              context.read<ThemeProvider>().toggleTheme(value);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          ),

          _buildSectionHeader(context, 'Privacy & Security'),
          _buildSettingsItem(
            context: context,
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Account visibility, data permissions',
            targetScreen: const PrivacySecurityPage(),
            requiresAuth: true,
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.block,
            title: 'Blocked Users',
            subtitle: 'Manage users you have blocked',
            targetScreen: const BlockedUsersScreen(),
            requiresAuth: true,
          ),

          _buildSectionHeader(context, 'Support & Legal'),
          _buildSettingsItem(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'FAQ, contact support',
            targetScreen: const SupportHelpPage(),
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.gavel_outlined,
            title: 'Legal & Policies',
            subtitle: 'Terms of Service, Privacy Policy',
            targetScreen: const LegalPoliciesPage(),
          ),

          _buildSectionHeader(context, 'Authentication'),
          _buildSettingsItem(
            context: context,
            icon: Icons.exit_to_app,
            iconColor: ThemeConstants.errorColor,
            title: 'Logout / Delete Account',
            subtitle: 'Sign out or permanently delete your account',
            targetScreen: const LogoutDeletePage(),
            requiresAuth: true,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// --- Placeholder Screens (no changes) ---
class CollegeVerificationPage extends StatelessWidget {
  const CollegeVerificationPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("College Verification")));
}

class LinkedAccountsPage extends StatelessWidget {
  const LinkedAccountsPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Linked Accounts")));
}

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Preferences")));
}
