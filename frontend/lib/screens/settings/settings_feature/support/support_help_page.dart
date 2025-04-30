// frontend/lib/screens/settings/settings_feature/support/support_help_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import '../../../../theme/theme_constants.dart'; // Use your theme constants

class SupportHelpPage extends StatelessWidget {
  const SupportHelpPage({Key? key}) : super(key: key);

  // --- TODO: Replace with your actual URLs/Emails ---
  final String contactEmail = 'support@connectionsapp.com';
  final String reportUrl = 'https://connectionsapp.com/report'; // Example URL for reporting form
  // --- End TODO ---

  // Helper to launch URL
  Future<void> _launchURL(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $urlString');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString'), backgroundColor: kHighlightYellow),
        );
      }
    }
  }

  // Helper to launch email
  Future<void> _launchEmail(String email, BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Connections App Support Request'},
    );
    if (!await launchUrl(emailLaunchUri)) {
      print('Could not launch email to $email');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app for: $email'), backgroundColor: kHighlightYellow),
        );
      }
    }
  }

  // --- FAQ Data (Consider moving to a separate file/service if it gets large) ---
  final List<Map<String, String>> faqs = const [
    {
      'question': 'How do I create a community?',
      'answer': 'Navigate to the Communities tab and tap the "+" button (Floating Action Button) in the bottom right corner. Fill in the required details like name, description, interest category, and optionally a location and logo.',
    },
    {
      'question': 'How do I report inappropriate content?',
      'answer': 'You can report posts, replies, or users directly from the content itself using the options menu (usually represented by "..."). Alternatively, use the "Report a Problem" link on this page to access our reporting form or guidelines.',
    },
    {
      'question': 'How do I join an event?',
      'answer': 'You can find events listed within communities or potentially on an "Explore" feed. Tap on an event card to see details and use the "Join Event" button if there are available spots.',
    },
    {
      'question': 'Can I change my username?',
      'answer': 'Yes, you can change your username, name, college, and profile picture in the "Edit Profile" section, accessible from your main profile screen or the Account Settings.',
    },
    // Add more relevant FAQs here
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Using provided constants directly
    const bool isDark = true; // Assuming the dark theme is the primary style based on constants used

    return Scaffold(
      backgroundColor: kDeepMidnightBlue, // Use constant
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(color: kLightText)), // Use constant
        backgroundColor: kDeepMidnightBlue, // Use constant
        iconTheme: const IconThemeData(color: kCyan), // Use constant
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          // --- FAQs Section ---
          _buildSectionHeader(context, "Frequently Asked Questions"),
          ...faqs.map((faq) => _buildFaqItem(
              context,
              question: faq['question']!,
              answer: faq['answer']!,
              isDark: isDark // Pass isDark for styling consistency
          )).toList(),

          const SizedBox(height: 10),
          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1),

          // --- Contact Section ---
          _buildSectionHeader(context, "Contact Us"),
          _buildSupportItem(
            context,
            icon: Icons.email_outlined,
            title: "Email Support",
            subtitle: contactEmail, // Display the email
            onTap: () => _launchEmail(contactEmail, context),
          ),

          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1),

          // --- Report Section ---
          _buildSectionHeader(context, "Report Issues"),
          _buildSupportItem(
            context,
            icon: Icons.report_problem_outlined,
            title: "Report a Problem",
            subtitle: "Report bugs or violations",
            onTap: () => _launchURL(reportUrl, context), // Link to a report form/page
          ),
          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1),
        ],
      ),
    );
  }

  // Reusable Section Header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, left: 20.0, bottom: 8.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle( // Use constants for colors
          fontWeight: FontWeight.bold,
          color: kHighlightYellow,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // Reusable ListTile for contact/report items
  Widget _buildSupportItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      leading: Icon(icon, color: kCyan, size: 24), // Use constant
      title: Text(title, style: const TextStyle(color: kLightText, fontSize: 16)), // Use constant
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: kSubtleGray, fontSize: 13)) : null, // Use constant
      trailing: Icon(Icons.open_in_new, color: kSubtleGray.withOpacity(0.7), size: 20),
      onTap: onTap,
      splashColor: kCyan.withOpacity(0.1), // Use constant
    );
  }

  // Widget for FAQ items using ExpansionTile
  Widget _buildFaqItem(BuildContext context, {required String question, required String answer, required bool isDark}) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
        iconColor: kCyan, // Use constant
        collapsedIconColor: kSubtleGray, // Use constant
        leading: const Icon(Icons.help_outline, color: kCyan), // Use constant
        title: Text(
          question,
          style: const TextStyle(color: kLightText, fontWeight: FontWeight.w500), // Use constant
        ),
        childrenPadding: const EdgeInsets.only(left: 20.0 + 24.0 + 16.0, right: 20.0, bottom: 16.0, top: 0),
        children: <Widget>[
          Text(
            answer,
            style: const TextStyle(color: kSubtleGray, height: 1.4), // Use constant
          ),
        ],
      ),
    );
  }
}