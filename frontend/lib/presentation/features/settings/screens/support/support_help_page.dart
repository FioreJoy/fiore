import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Core Imports (No ThemeConstants directly needed if using Theme.of(context))
// import '../../../../../core/theme/theme_constants.dart';

class SupportHelpPage extends StatelessWidget {
  const SupportHelpPage({super.key});

  final String faqUrl = 'https://yourdomain.com/faq';
  final String contactEmail = 'support@yourdomain.com';
  final String reportUrl = 'https://yourdomain.com/report';

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // print('Could not launch $urlString'); // Debug removed
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri( scheme: 'mailto', path: email, queryParameters: {'subject': 'App Support Request'},);
    if (!await launchUrl(emailLaunchUri)) { /* print('Could not launch email'); */ } // Debug removed
   }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Not used directly for styling logic in this simplified version

    return Scaffold(
      appBar: AppBar( title: const Text('Support & Help')),
      body: ListView( padding: const EdgeInsets.symmetric(vertical: 10.0), children: [
          _buildSupportItem( context, icon: Icons.quiz_outlined, title: "FAQs", subtitle: "Common questions", onTap: () => _launchURL(faqUrl),),
          Divider(color: theme.dividerColor, indent: 20, endIndent: 20, height: 1),
          _buildSupportItem( context, icon: Icons.email_outlined, title: "Contact Support", subtitle: "Get help via email", onTap: () => _launchEmail(contactEmail),),
          Divider(color: theme.dividerColor, indent: 20, endIndent: 20, height: 1),
          _buildSupportItem( context, icon: Icons.report_problem_outlined, title: "Report a Problem", subtitle: "Bugs or inappropriate content", onTap: () => _launchURL(reportUrl),),
          Divider(color: theme.dividerColor, indent: 20, endIndent: 20, height: 1),
        ],
      ),
    );
  }

   Widget _buildSupportItem( BuildContext context, { required IconData icon, required String title, String? subtitle, required VoidCallback onTap,}) {
     final theme = Theme.of(context);
     return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        leading: Icon(icon, color: theme.colorScheme.primary, size: 24),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: subtitle != null ? Text(subtitle, style: theme.textTheme.bodySmall) : null,
        trailing: Icon(Icons.open_in_new, color: theme.iconTheme.color?.withOpacity(0.6), size: 20),
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
     );
   }
}
