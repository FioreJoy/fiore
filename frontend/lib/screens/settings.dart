import 'package:flutter/material.dart';
import '/theme/theme_constants.dart'; // Adjust import path if needed

// Import placeholder detail pages (Create these files next)
import 'settings_feature/account/edit_profile.dart';
import 'settings_feature/account/change_password_page.dart';
import 'settings_feature/account/linked_accounts_page.dart';
import 'settings_feature/account/college_verification_page.dart';
import 'settings_feature/privacy/privacy_security_page.dart'; // Combined privacy settings
import 'settings_feature/privacy/blocked_users.dart';
import 'settings_feature/notifications/notification_settings_page.dart';
import 'settings_feature/preferences/preferences_page.dart'; // Theme, Interests, Location
import 'settings_feature/app/app_settings_page.dart';       // Cache, Version
import 'settings_feature/support/support_help_page.dart';     // FAQs, Contact, Report
import 'settings_feature/legal/legal_policies_page.dart';   // Terms, Privacy, Guidelines
import 'settings_feature/auth/logout_delete_page.dart';   // Logout, Delete

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepMidnightBlue,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: kHighlightYellow, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kDeepMidnightBlue,
        elevation: 0, // Keep it clean
        iconTheme: const IconThemeData(color: kCyan), // Back button color
        leading: IconButton( // Optional: Customize back button if needed
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
          color: kCyan,
           tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader("Account Settings"),
          _buildSettingsItem(
            context,
            icon: Icons.person_outline,
            title: "Edit Profile",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.lock_outline,
            title: "Change Password",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.link,
            title: "Linked Accounts",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.school_outlined,
            title: "College Verification",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),

          _buildSectionHeader("Privacy & Security"),
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Controls", // Combine Profile Vis, Activity, Requests
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.block,
            title: "Blocked Users",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersPage())),
          ),

          _buildSectionHeader("Notification Settings"),
          _buildSettingsItem(
            context,
            icon: Icons.notifications_outlined,
            title: "Notifications", // Combine Push, Email, Sound
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),

           _buildSectionHeader("Preferences"),
          _buildSettingsItem(
            context,
            icon: Icons.palette_outlined,
            title: "Appearance & Preferences", // Combine Theme, Interests, Location
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesPage())),
          ),

          _buildSectionHeader("App Settings"),
           _buildSettingsItem(
            context,
            icon: Icons.settings_applications_outlined,
            title: "App Settings", // Combine Cache, Version
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),


          _buildSectionHeader("Support & Help"),
           _buildSettingsItem(
            context,
            icon: Icons.help_outline,
            title: "Support & Help", // Combine FAQ, Contact, Report
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),

          _buildSectionHeader("Legal & Policies"),
           _buildSettingsItem(
            context,
            icon: Icons.gavel_outlined,
            title: "Legal & Policies", // Combine Terms, Privacy, Community
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),

          _buildSectionHeader("Account Actions"),
          _buildSettingsItem(
            context,
            icon: Icons.exit_to_app,
            title: "Logout / Delete Account",
            iconColor: Colors.redAccent, // Highlight destructive actions
            textColor: Colors.redAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),

          const SizedBox(height: 30), // Add some padding at the bottom
        ],
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, left: 16.0, bottom: 8.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: kHighlightYellow,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // Helper widget for individual settings items
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = kCyan, // Default icon color
    Color textColor = kLightText, // Default text color
  }) {
    return Material( // Use Material for InkWell splash effect
      color: kDeepMidnightBlue, // Match background for seamless look
      child: InkWell(
        onTap: onTap,
        splashColor: kCyan.withOpacity(0.2),
        highlightColor: kCyan.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
              ),
              Icon(Icons.chevron_right, color: kSubtleGray.withOpacity(0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}