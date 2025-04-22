import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For network images
import 'package:shimmer/shimmer.dart'; // For loading shimmer

import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../theme/theme_constants.dart';
import '../app_constants.dart'; // For default avatar
import 'settings.dart'; // To navigate to settings screen

class MeScreen extends StatefulWidget {
  const MeScreen({Key? key}) : super(key: key);

  @override
  _MeScreenState createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  bool _isLoading = false;
  Map<String, dynamic>? _userData; // Store fetched user data

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is ready for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load data only if authenticated, otherwise AuthProvider listener will trigger rebuild
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && _userData == null) { // Load only if logged in and data isn't already loaded
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    // Avoid reload if already loading
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Ensure token exists before proceeding
    if (authProvider.token == null) {
      print("MeScreen: Cannot load user data, token is null.");
      if (mounted) setState(() => _isLoading = false);
      // Optionally trigger logout or show error
      // authProvider.logout();
      return;
    }

    try {
      // Corrected method name
      final data = await apiService.fetchUserData(authProvider.token);
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
        // Update AuthProvider with the latest data if needed
        // authProvider.updateUserData(data); // You might need a method like this in AuthProvider
      }
    } catch (e) {
      print("Error loading user data in MeScreen: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
        );
      }
    }
  }

  // Function to handle navigation to settings
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      // Refresh data when returning from settings in case profile was updated
      _loadUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    // Listen to AuthProvider changes
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If authentication state changes to false, clear user data
    if (!authProvider.isAuthenticated && _userData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() { _userData = null; });
        }
      });
    }
    // If authentication state changes to true and data is missing, trigger load
    else if (authProvider.isAuthenticated && _userData == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadUserData();
        }
      });
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _navigateToSettings,
          ),
        ],
        elevation: 1, // Slight elevation
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData, // Allow pull-to-refresh
        child: _isLoading && _userData == null // Show shimmer only on initial load
            ? _buildLoadingShimmer(isDark)
            : !authProvider.isAuthenticated // Show login prompt if not logged in
            ? _buildNotLoggedInView(isDark)
            : _buildProfileView(isDark), // Show profile if logged in
      ),
    );
  }

  Widget _buildProfileView(bool isDark) {
    if (_userData == null) {
      // This case might happen briefly if loading fails after being authenticated
      return _buildErrorView("Could not load profile data.", isDark);
    }

    // Safely access user data with defaults
    final String name = _userData!['name'] ?? 'N/A';
    final String username = _userData!['username'] ?? 'N/A';
    final String email = _userData!['email'] ?? 'N/A';
    final String gender = _userData!['gender'] ?? 'N/A';
    final String college = _userData!['college'] ?? 'N/A';
    final String? imageUrl = _userData!['image_url']; // Use image_url from API response
    final List<String> interests = List<String>.from(_userData!['interests'] ?? []);
    final String joinedDate = _userData!['created_at'] != null
        ? ThemeConstants.formatDateTime(_userData!['created_at']) // Use formatter
        : 'N/A';
    // final location = _userData!['current_location']; // This is a Map<String, double>?


    return ListView( // Use ListView for scrollable content
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      children: [
        // Profile Header
        Row(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: imageUrl != null
                  ? CachedNetworkImageProvider(imageUrl) // Use CachedNetworkImageProvider
                  : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
            ),
            const SizedBox(width: ThemeConstants.mediumPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Joined: $joinedDate', // Display formatted date
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Optional: Edit Profile Button (can also be in settings)
            // IconButton(
            //   icon: Icon(Icons.edit_outlined, color: ThemeConstants.accentColor),
            //   tooltip: 'Edit Profile',
            //   onPressed: () { /* Navigate to EditProfileScreen */ },
            // ),
          ],
        ),
        const SizedBox(height: ThemeConstants.largePadding),
        const Divider(),
        const SizedBox(height: ThemeConstants.mediumPadding),

        // Profile Details Section
        _buildSectionTitle('About Me', isDark),
        _buildDetailItem(Icons.email_outlined, 'Email', email, isDark),
        _buildDetailItem(Icons.wc_outlined, 'Gender', gender, isDark),
        _buildDetailItem(Icons.school_outlined, 'College', college, isDark),
        // TODO: Add location display if needed
        // _buildDetailItem(Icons.location_on_outlined, 'Location', formatLocation(location), isDark),

        const SizedBox(height: ThemeConstants.mediumPadding),

        // Interests Section
        _buildSectionTitle('Interests', isDark),
        interests.isEmpty
            ? Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: Text('No interests added yet.', style: TextStyle(color: Colors.grey.shade500)),
        )
            : Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: interests.map((interest) => Chip(
            label: Text(interest),
            backgroundColor: ThemeConstants.accentColor.withOpacity(0.1),
            labelStyle: TextStyle(color: ThemeConstants.accentColor, fontSize: 12),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            side: BorderSide(color: ThemeConstants.accentColor.withOpacity(0.3)),
          )).toList(),
        ),

        const SizedBox(height: ThemeConstants.largePadding),
        const Divider(),
        const SizedBox(height: ThemeConstants.mediumPadding),

        // Links to other profile sections (Posts, Communities, etc.) - Optional
        // _buildProfileLinkItem(Icons.article_outlined, 'My Posts', () { /* Navigate */ }),
        // _buildProfileLinkItem(Icons.people_outline, 'My Communities', () { /* Navigate */ }),
        // _buildProfileLinkItem(Icons.event_note, 'My Events', () { /* Navigate */ }),

      ],
    );
  }

  // Helper for Section Titles
  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? ThemeConstants.accentColor : ThemeConstants.primaryColor,
        ),
      ),
    );
  }

  // Helper for Detail Items
  Widget _buildDetailItem(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          const SizedBox(width: 16),
          Text('$label:', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }

  // Helper for Profile Link Items (Optional)
  Widget _buildProfileLinkItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: ThemeConstants.accentColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }


  // Loading Shimmer Widget
  Widget _buildLoadingShimmer(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView( // Use ListView structure for shimmer
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 45),
              const SizedBox(width: ThemeConstants.mediumPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 20, color: Colors.white), // Name shimmer
                    const SizedBox(height: 8),
                    Container(width: 100, height: 16, color: Colors.white), // Username shimmer
                    const SizedBox(height: 8),
                    Container(width: 120, height: 14, color: Colors.white), // Joined date shimmer
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ThemeConstants.largePadding),
          const Divider(),
          const SizedBox(height: ThemeConstants.mediumPadding),
          // Shimmer for details section
          Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)),
          Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
          Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
          Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
          const SizedBox(height: ThemeConstants.mediumPadding),
          Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)),
          Wrap(
            spacing: 8.0, runSpacing: 4.0,
            children: List.generate(5, (_) => Chip(label: Container(width: 60, height: 14, color: Colors.white))),
          ),
          const SizedBox(height: ThemeConstants.largePadding),
          const Divider(),
        ],
      ),
    );
  }

  // Not Logged In View
  Widget _buildNotLoggedInView(bool isDark) {
    // Identical to the one in chatroom_screen - Consider extracting to a common widget
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          const SizedBox(height: 20),
          Text('Please log in to view your profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Manage your communities, posts, and settings', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            // Use context.pushReplacementNamed or similar if using named routes
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'), // Navigate to root (Login)
            style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: ThemeConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  // Error View
  Widget _buildErrorView(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 60),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _loadUserData,
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }

} // End of _MeScreenState class