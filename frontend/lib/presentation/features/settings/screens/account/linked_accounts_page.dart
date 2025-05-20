import 'package:flutter/material.dart';

// --- Core Imports ---
import '../../../../../core/theme/theme_constants.dart'; // Using for k-style constants until full theme migration here

// --- Presentation Imports ---
import '../../../../global_widgets/custom_button.dart';

class LinkedAccountsPage extends StatefulWidget {
  const LinkedAccountsPage({super.key});

  @override
  State<LinkedAccountsPage> createState() => _LinkedAccountsPageState();
}

class _LinkedAccountsPageState extends State<LinkedAccountsPage> {
  // Placeholder state - replace with actual linked status
  bool _isGoogleLinked = false;
  bool _isFacebookLinked = false;

  Future<void> _linkAccount(String provider) async {
    // print('Attempting to link $provider...'); // Debug print removed
    // --- TODO: Implement actual linking flow ---
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        if (provider == 'Google') _isGoogleLinked = true;
        if (provider == 'Facebook') _isFacebookLinked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$provider linked (Simulated)'),
            backgroundColor: ThemeConstants.accentColor), // Use ThemeConstants
      );
    }
  }

  Future<void> _unlinkAccount(String provider) async {
    // print('Attempting to unlink $provider...'); // Debug print removed
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        if (provider == 'Google') _isGoogleLinked = false;
        if (provider == 'Facebook') _isFacebookLinked = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$provider unlinked (Simulated)'),
            backgroundColor:
                ThemeConstants.highlightColor), // Use ThemeConstants
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context) for theming
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // backgroundColor: isDark ? ThemeConstants.backgroundDarkest : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Linked Accounts'),
        // backgroundColor: isDark ? ThemeConstants.backgroundDarker : theme.primaryColor,
        // iconTheme: IconThemeData(color: isDark ? ThemeConstants.accentColor : Colors.white),
        // elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildLinkedAccountTile(
            context: context, // Pass context
            providerName: 'Google',
            icon: Icons.g_mobiledata_outlined, // Using a generic G icon for now
            iconColor: Colors.redAccent,
            isLinked: _isGoogleLinked,
            onLink: () => _linkAccount('Google'),
            onUnlink: () => _unlinkAccount('Google'),
          ),
          Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              indent: 20,
              endIndent: 20,
              height: 1),
          _buildLinkedAccountTile(
            context: context, // Pass context
            providerName: 'Facebook',
            icon: Icons.facebook_outlined,
            iconColor: Colors.blueAccent,
            isLinked: _isFacebookLinked,
            onLink: () => _linkAccount('Facebook'),
            onUnlink: () => _unlinkAccount('Facebook'),
          ),
          Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              indent: 20,
              endIndent: 20,
              height: 1),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Linking accounts allows for quicker login and potential future integrations.',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountTile({
    required BuildContext context, // Added context
    required String providerName,
    required IconData icon,
    required Color iconColor,
    required bool isLinked,
    required VoidCallback onLink,
    required VoidCallback onUnlink,
  }) {
    final theme = Theme.of(context); // Get theme
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      leading: Icon(icon, color: iconColor, size: 32),
      title: Text(providerName, style: theme.textTheme.titleMedium),
      trailing: CustomButton(
        text: isLinked ? 'Unlink' : 'Link',
        onPressed: isLinked ? onUnlink : onLink,
        type: isLinked ? ButtonType.outline : ButtonType.primary,
        // Customizing button further based on theme and state:
        foregroundColor: isLinked
            ? theme.colorScheme.error
            : null, // Default for primary, error for outline unlink
        borderColor: isLinked ? theme.colorScheme.error.withOpacity(0.7) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        fontSize: 13,
      ),
      splashColor: iconColor.withOpacity(0.1),
    );
  }
}
