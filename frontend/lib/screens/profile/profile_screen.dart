// frontend/lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Updated Service Imports ---
import '../../services/api/auth_service.dart'; // Use AuthService for profile actions
import '../../services/auth_provider.dart'; // To get token and user state

// --- Widget Imports ---
import '../../widgets/custom_card.dart'; // Assuming used for layout?
import '../../widgets/custom_button.dart'; // For retry button

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart'; // For default avatar

// --- Navigation Imports ---
import '../settings/settings_home_screen.dart'; // Updated path

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching main tabs

  bool _isLoading = false;
  Map<String, dynamic>? _userData; // Store fetched user data
  String? _error; // Store error message

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback for initial load after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && _userData == null) {
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted || _isLoading) return; // Prevent concurrent loads

    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });

    // Use specific AuthService via Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      print("ProfileScreen: Cannot load user data, token is null.");
      if (mounted) setState(() { _isLoading = false; _error = "Not logged in."; });
      return;
    }

    try {
      // Call AuthService to get profile data
      final data = await authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
          // Update image URL in AuthProvider if it changed
          if (authProvider.userImageUrl != data['image_url']) {
            authProvider.updateUserImageUrl(data['image_url']);
          }
        });
      }
    } catch (e) {
      print("Error loading user data in ProfileScreen: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // Function to handle navigation to settings
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsHomeScreen()), // Use renamed screen
    ).then((_) {
      // Refresh data when returning from settings in case profile was updated
      print("ProfileScreen: Returning from settings, reloading data...");
      _loadUserData(); // Trigger reload
    });
  }

  // Format date helper (moved from ThemeConstants or define here)
  String formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      // Handle both String and DateTime objects potentially coming from JSON
      DateTime? dt;
      if (timestamp is String) {
        dt = DateTime.tryParse(timestamp)?.toLocal();
      } else if (timestamp is DateTime) {
        dt = timestamp.toLocal();
      }
      if (dt != null) {
        // Example format: Jan 15, 2024, 10:30 AM
        return DateFormat('MMM d, yyyy, hh:mm a').format(dt);
      }
    } catch (e) {
      print("Error formatting timestamp '$timestamp': $e");
    }
    return 'Invalid Date'; // Fallback for parsing errors
  }

  // Format location helper
  String formatLocation(dynamic locationData) {
    if (locationData is Map) {
      final lon = locationData['longitude'];
      final lat = locationData['latitude'];
      if (lon is num && lat is num) {
        return '(${lon.toStringAsFixed(4)}, ${lat.toStringAsFixed(4)})';
      }
    } else if (locationData is String && locationData.isNotEmpty) {
      // If backend sends string directly, return it (or parse if needed)
      return locationData;
    }
    return 'N/A';
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state

    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Handle logout state change
    if (!authProvider.isAuthenticated && _userData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _userData = null; _error = null; });
      });
    }
    // Handle login state change if data wasn't loaded
    else if (authProvider.isAuthenticated && _userData == null && !_isLoading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUserData();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (authProvider.isAuthenticated) // Only show settings if logged in
            IconButton( icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: _navigateToSettings, ),
        ],
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: _buildBody(authProvider, isDark), // Delegate body build
      ),
    );
  }

  // --- Body Build Logic ---
  Widget _buildBody(AuthProvider authProvider, bool isDark) {
    if (_isLoading && _userData == null) {
      return _buildLoadingShimmer(isDark); // Shimmer on initial load
    } else if (!authProvider.isAuthenticated) {
      return _buildNotLoggedInView(isDark); // Show login prompt
    } else if (_error != null) {
      return _buildErrorView(_error!, isDark); // Show error view
    } else if (_userData != null) {
      return _buildProfileView(isDark); // Show profile
    } else {
      // Fallback: Should ideally not be reached if logic is correct
      return const Center(child: Text("Loading profile..."));
    }
  }


  // --- Profile View (when data is loaded) ---
  Widget _buildProfileView(bool isDark) {
    // Data extraction (already checked _userData != null)
    final String name = _userData!['name'] ?? 'N/A';
    final String username = _userData!['username'] ?? 'N/A';
    final String email = _userData!['email'] ?? 'N/A';
    final String gender = _userData!['gender'] ?? 'N/A';
    final String college = _userData!['college'] ?? 'N/A';
    // Use image URL from AuthProvider as it might be updated more recently after profile edit
    final String? imageUrl = Provider.of<AuthProvider>(context, listen: false).userImageUrl ?? _userData!['image_url'];
    final List<String> interests = List<String>.from(_userData!['interests'] ?? []);
    final String joinedDate = formatDateTime(_userData!['created_at']);
    final String lastSeen = formatDateTime(_userData!['last_seen']);
    final location = _userData!['current_location']; // Map<String, double>? or String?

    return ListView(
      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
      children: [
        // Profile Header
        Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
          CircleAvatar( radius: 45, backgroundColor: Colors.grey.shade300,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
          ),
          const SizedBox(width: ThemeConstants.mediumPadding),
          Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text( name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis,),
            const SizedBox(height: 4),
            Text( '@$username', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),),
            const SizedBox(height: 6),
            Text( 'Joined: $joinedDate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),),
            Text( 'Last Seen: $lastSeen', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),),
          ],),),
        ],),
        const SizedBox(height: ThemeConstants.largePadding),
        const Divider(),
        const SizedBox(height: ThemeConstants.mediumPadding),

        // Profile Details Section
        _buildSectionTitle('About Me', isDark),
        _buildDetailItem(Icons.email_outlined, 'Email', email, isDark),
        _buildDetailItem(Icons.wc_outlined, 'Gender', gender, isDark),
        _buildDetailItem(Icons.school_outlined, 'College', college, isDark),
        _buildDetailItem(Icons.location_on_outlined, 'Location', formatLocation(location), isDark), // Use formatter
        const SizedBox(height: ThemeConstants.mediumPadding),

        // Interests Section
        _buildSectionTitle('Interests', isDark),
        interests.isEmpty
            ? Padding( padding: const EdgeInsets.only(left: 16.0, top: 8.0), child: Text('No interests added yet.', style: TextStyle(color: Colors.grey.shade500)),)
            : Padding( // Add padding around chips
          padding: const EdgeInsets.only(left: 8.0),
          child: Wrap( spacing: 8.0, runSpacing: 4.0, children: interests.map((interest) => Chip(
            label: Text(interest), backgroundColor: ThemeConstants.accentColor.withOpacity(0.1),
            labelStyle: TextStyle(color: ThemeConstants.accentColor, fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            side: BorderSide(color: ThemeConstants.accentColor.withOpacity(0.3)),
          )).toList(),),
        ),
        const SizedBox(height: ThemeConstants.largePadding),
        const Divider(),
        // Add links to user's posts/activity later if needed
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildSectionTitle(String title, bool isDark) { /* Keep original */ return Padding( padding: const EdgeInsets.only(bottom: 12.0), child: Text( title, style: Theme.of(context).textTheme.titleLarge?.copyWith( fontWeight: FontWeight.w600, color: isDark ? ThemeConstants.accentColor : ThemeConstants.primaryColor,),),); }
  Widget _buildDetailItem(IconData icon, String label, String value, bool isDark) { /* Keep original */ return Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( children: [ Icon(icon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), const SizedBox(width: 16), Text('$label:', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)), const SizedBox(width: 8), Expanded(child: Text(value, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),],),); }
  Widget _buildLoadingShimmer(bool isDark) { /* Keep original */ final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300; final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100; return Shimmer.fromColors( baseColor: baseColor, highlightColor: highlightColor, child: ListView( padding: const EdgeInsets.all(ThemeConstants.mediumPadding), children: [ Row( children: [ const CircleAvatar(radius: 45), const SizedBox(width: ThemeConstants.mediumPadding), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Container(width: 150, height: 20, color: Colors.white), const SizedBox(height: 8), Container(width: 100, height: 16, color: Colors.white), const SizedBox(height: 8), Container(width: 120, height: 14, color: Colors.white),],),),],), const SizedBox(height: ThemeConstants.largePadding), const Divider(), const SizedBox(height: ThemeConstants.mediumPadding), Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), const SizedBox(height: ThemeConstants.mediumPadding), Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), Wrap( spacing: 8.0, runSpacing: 4.0, children: List.generate(5, (_) => Chip(label: Container(width: 60, height: 14, color: Colors.white))),),],),); }
  Widget _buildNotLoggedInView(bool isDark) { /* Keep original */ return Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.person_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400), const SizedBox(height: 20), Text('Please log in to view your profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)), const SizedBox(height: 8), Text('Manage your communities, posts, and settings', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton( onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Log In'),),],),); }
  Widget _buildErrorView(String message, bool isDark) { /* Keep original */ return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 60), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)), const SizedBox(height: 24), CustomButton( text: 'Retry', icon: Icons.refresh, onPressed: _loadUserData, type: ButtonType.secondary,),],),),); }

}