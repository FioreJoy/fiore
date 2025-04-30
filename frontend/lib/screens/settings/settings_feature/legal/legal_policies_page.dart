// frontend/lib/screens/settings/settings_feature/legal/legal_policies_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For loading assets
import 'package:flutter_markdown/flutter_markdown.dart'; // Markdown rendering
import 'package:url_launcher/url_launcher.dart'; // For links within markdown

import '../../../../theme/theme_constants.dart'; // Use your theme constants

class LegalPoliciesPage extends StatelessWidget {
  const LegalPoliciesPage({Key? key}) : super(key: key);

  // Function to navigate to the detailed policy display screen
  void _navigateToPolicy(BuildContext context, String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyDisplayScreen(
          title: title,
          markdownAssetPath: assetPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Using provided constants directly
    const bool isDark = true; // Assuming the dark theme is the primary style

    return Scaffold(
      backgroundColor: kDeepMidnightBlue, // Use constant
      appBar: AppBar(
        title: const Text('Legal & Policies', style: TextStyle(color: kLightText)), // Use constant
        backgroundColor: kDeepMidnightBlue, // Use constant
        iconTheme: const IconThemeData(color: kCyan), // Use constant
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: [
          _buildLegalItem(
            context,
            icon: Icons.description_outlined,
            title: "Terms of Service",
            subtitle: "Rules for using Connections",
            // --- Make sure this file exists: assets/legal/terms_of_service.md ---
            onTap: () => _navigateToPolicy(context, "Terms of Service", "assets/legal/terms_of_service.md"),
          ),
          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1), // Use constant
          _buildLegalItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            subtitle: "How we handle your data",
            // --- Make sure this file exists: assets/legal/privacy_policy.md ---
            onTap: () => _navigateToPolicy(context, "Privacy Policy", "assets/legal/privacy_policy.md"),
          ),
          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1), // Use constant
          _buildLegalItem(
            context,
            icon: Icons.rule_outlined,
            title: "Community Guidelines",
            subtitle: "Expected community behavior",
            // --- Make sure this file exists: assets/legal/community_guidelines.md ---
            onTap: () => _navigateToPolicy(context, "Community Guidelines", "assets/legal/community_guidelines.md"),
          ),
          const Divider(color: kSubtleGray, indent: 20, endIndent: 20, height: 1), // Use constant
        ],
      ),
    );
  }

  // Reusable ListTile for legal items
  Widget _buildLegalItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle, // Added subtitle for consistency
        required VoidCallback onTap,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      leading: const Icon(Icons.chevron_right, color: kSubtleGray), // Use simple chevron
      title: Text(title, style: const TextStyle(color: kLightText, fontSize: 16)), // Use constant
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: kSubtleGray, fontSize: 13)) : null, // Use constant
      onTap: onTap,
      splashColor: kCyan.withOpacity(0.1), // Use constant
    );
  }
}

// --- Widget for Displaying Policy Content ---

class PolicyDisplayScreen extends StatefulWidget {
  final String title;
  final String markdownAssetPath;

  const PolicyDisplayScreen({
    Key? key,
    required this.title,
    required this.markdownAssetPath,
  }) : super(key: key);

  @override
  _PolicyDisplayScreenState createState() => _PolicyDisplayScreenState();
}

class _PolicyDisplayScreenState extends State<PolicyDisplayScreen> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final content = await rootBundle.loadString(widget.markdownAssetPath);
      if (mounted) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading markdown asset '${widget.markdownAssetPath}': $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Could not load the document. Please check the file path or try again later.";
        });
      }
    }
  }

  // Helper to launch URL from markdown links
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Using provided constants directly
    const bool isDark = true;

    return Scaffold(
      backgroundColor: kDeepMidnightBlue, // Use constant
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: kLightText)), // Use constant
        backgroundColor: kDeepMidnightBlue, // Use constant
        iconTheme: const IconThemeData(color: kCyan), // Use constant
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kCyan)) // Use constant
          : _error != null
          ? Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_error!, style: const TextStyle(color: kHighlightYellow), textAlign: TextAlign.center) // Use constant
          )
      )
          : _markdownContent == null
          ? const Center(child: Text("Content not available.", style: TextStyle(color: kSubtleGray))) // Use constant
          : Markdown( // Use Markdown widget here
        data: _markdownContent!,
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          // Customize styles to match the dark theme
          p: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: kLightText), // Use constant
          h1: theme.textTheme.headlineMedium?.copyWith(color: kHighlightYellow, fontWeight: FontWeight.bold, height: 2.0, decoration: TextDecoration.underline, decorationColor: kCyan.withOpacity(0.5)), // Use constants
          h2: theme.textTheme.headlineSmall?.copyWith(color: kHighlightYellow, fontWeight: FontWeight.bold, height: 1.8), // Use constant
          h3: theme.textTheme.titleLarge?.copyWith(color: kCyan, fontWeight: FontWeight.w600, height: 1.6), // Use constant
          a: const TextStyle(color: kCyan, decoration: TextDecoration.underline, decorationColor: kCyan), // Link style
          listBullet: const TextStyle(color: kLightText), // Bullet point color
          blockquoteDecoration: BoxDecoration(
            color: Colors.grey.shade800.withOpacity(0.5), // Blockquote background
            borderRadius: BorderRadius.circular(4),
          ),
          blockquotePadding: const EdgeInsets.all(12),
          code: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace', // Use a monospace font for code
            backgroundColor: Colors.black.withOpacity(0.2),
            color: kLightText.withOpacity(0.85),
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3), // Code block background
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onTapLink: (text, href, title) { // Handle link taps
          if (href != null) {
            _launchURL(href, context); // Use your launch function
          }
        },
      ),
    );
  }
}