import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Core Imports
import '../../../../../core/theme/theme_constants.dart';

class LegalPoliciesPage extends StatelessWidget {
  const LegalPoliciesPage({super.key});

  final String termsUrl = 'https://yourdomain.com/terms'; // Placeholder
  final String privacyUrl = 'https://yourdomain.com/privacy'; // Placeholder
  final String guidelinesUrl =
      'https://yourdomain.com/guidelines'; // Placeholder

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // print('Could not launch $urlString'); // Debug print removed
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Use theme for styling
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Legal & Policies')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildLegalItem(
            context,
            icon: Icons.description_outlined,
            title: "Terms of Service",
            onTap: () => _launchURL(termsUrl),
          ),
          Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              indent: 20,
              endIndent: 20,
              height: 1),
          _buildLegalItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            onTap: () => _launchURL(privacyUrl),
          ),
          Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              indent: 20,
              endIndent: 20,
              height: 1),
          _buildLegalItem(
            context,
            icon: Icons.rule_outlined,
            title: "Community Guidelines",
            onTap: () => _launchURL(guidelinesUrl),
          ),
          Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              indent: 20,
              endIndent: 20,
              height: 1),
        ],
      ),
    );
  }

  Widget _buildLegalItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      leading: Icon(icon, color: theme.colorScheme.primary, size: 24),
      title: Text(title, style: theme.textTheme.titleMedium),
      trailing: Icon(Icons.open_in_new,
          color: theme.iconTheme.color?.withOpacity(0.6), size: 20),
      onTap: onTap,
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
    );
  }
}
