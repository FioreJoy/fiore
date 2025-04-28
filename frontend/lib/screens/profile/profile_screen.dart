import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/services.dart'; // For clipboard

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
  
  int _communitiesJoined = 0;
  int _eventsAttended = 0;
  int _postsCreated = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoad(); // Call the initial loading logic
    });
  }

  Future<void> _initialLoad() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && _userData == null) {
      await _loadUserData();
    } else if (authProvider.isAuthenticated) {
      await _loadUserStats();
    }
  }

  Future<void> _loadUserData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) {
        setState(() {
          _error = "Not authenticated.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userData = await authService.getCurrentUserProfile(authProvider.token!);
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
        await _loadUserStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load profile data: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserStats() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      print("Cannot load stats: Not authenticated.");
      return;
    }

    try {
      final stats = await authService.getUserStats(authProvider.token!);
      if (mounted) {
        setState(() {
          _communitiesJoined = stats['communities_joined'] ?? 0;
          _eventsAttended = stats['events_attended'] ?? 0;
          _postsCreated = stats['posts_created'] ?? 0;
        });
      }
    } catch (e) {
      print("Error loading user stats: $e");
    }
  }

  // Define the missing methods
  String formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime);
    return DateFormat('MMM dd, yyyy').format(date);
  }
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
  void _editProfile() {
    // Implement the edit profile functionality
  }

  void _shareProfile() {
    // Implement the share profile functionality
  }

  String formatLocation(dynamic locationData) {
    if (locationData is Map) {
      final lon = locationData['longitude'];
      final lat = locationData['latitude'];
      if (lon is num && lat is num) return '(${lon.toStringAsFixed(4)}, ${lat.toStringAsFixed(4)})';
    } else if (locationData is String && locationData.isNotEmpty) return locationData;
    return '(0,0)';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!authProvider.isAuthenticated && _userData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _userData = null; _error = null; });
      });
    } else if (authProvider.isAuthenticated && _userData == null && !_isLoading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUserData();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (authProvider.isAuthenticated)
            IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: _navigateToSettings),
        ],
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: _buildBody(authProvider, isDark),
      ),
    );
  }

  Widget _buildBody(AuthProvider authProvider, bool isDark) {
    if (_isLoading && _userData == null) {
      return _buildLoadingShimmer(isDark);
    } else if (!authProvider.isAuthenticated) {
      return _buildNotLoggedInView(isDark);
    } else if (_error != null) {
      return _buildErrorView(_error!, isDark);
    } else if (_userData != null) {
      return _buildProfileView(isDark);
    } else {
      return const Center(child: Text("Loading profile..."));
    }
  }

  Widget _buildProfileView(bool isDark) {
    final String name = _userData!['name'] ?? 'N/A';
    final String username = _userData!['username'] ?? 'N/A';
    final String email = _userData!['email'] ?? 'N/A';
    final String gender = _userData!['gender'] ?? 'N/A';
    final String college = _userData!['college'] ?? 'N/A';
    final String? imageUrl = Provider.of<AuthProvider>(context, listen: false).userImageUrl ?? _userData!['image_url'];
    final List<String> interests = List<String>.from(_userData!['interests'] ?? []);
    final String joinedDate = formatDateTime(_userData!['created_at']);
    final String lastSeen = formatDateTime(_userData!['last_seen']);
    final location = _userData!['current_location'];

    final int joinedCommunities = _communitiesJoined;
    final int joinedEvents = _eventsAttended;
    final int posts = _postsCreated;
    final int followers = _userData!['followers_count'] as int? ?? 0;

    final Color headerStartColor = isDark
        ? ThemeConstants.accentColor.withOpacity(0.7)
        : ThemeConstants.accentColor.withOpacity(0.1);
    final Color headerEndColor = isDark
        ? ThemeConstants.accentColor.withOpacity(0.3)
        : ThemeConstants.accentColor.withOpacity(0.05);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [headerStartColor, headerEndColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(ThemeConstants.mediumPadding,
                                            ThemeConstants.mediumPadding,
                                            ThemeConstants.mediumPadding,
                                            ThemeConstants.largePadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImageProvider(imageUrl)
                          : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider,
                    ),
                  ),
                  const SizedBox(width: ThemeConstants.mediumPadding),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Joined: $joinedDate',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                        Text(
                          'Last Seen: $lastSeen',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(top: ThemeConstants.mediumPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : ThemeConstants.accentColor,
                        foregroundColor: isDark ? ThemeConstants.accentColor : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    OutlinedButton.icon(
                      onPressed: _shareProfile,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : ThemeConstants.accentColor,
                        side: BorderSide(
                          color: isDark ? Colors.white : ThemeConstants.accentColor,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Stats', isDark),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildStatCard(
                    context,
                    icon: Icons.people,
                    value: joinedCommunities.toString(),
                    label: 'Communities',
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    context,
                    icon: Icons.event,
                    value: joinedEvents.toString(),
                    label: 'Events',
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    context,
                    icon: Icons.forum,
                    value: posts.toString(),
                    label: 'Posts',
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    context,
                    icon: Icons.person_add,
                    value: followers.toString(),
                    label: 'Followers',
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('About Me', isDark),
              _buildDetailItem(Icons.email_outlined, 'Email', email, isDark),
              _buildDetailItem(Icons.wc_outlined, 'Gender', gender, isDark),
              _buildDetailItem(Icons.school_outlined, 'College', college, isDark),
              _buildDetailItem(Icons.location_on_outlined, 'Location', formatLocation(location), isDark),
            ],
          ),
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Interests', isDark),
              const SizedBox(height: 10),
              interests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: Text(
                      'No interests added yet.',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 10.0,
                    runSpacing: 8.0,
                    children: interests.map((interest) => Chip(
                      avatar: Icon(
                        Icons.local_offer,
                        size: 16,
                        color: ThemeConstants.accentColor,
                      ),
                      label: Text(interest),
                      backgroundColor: isDark
                          ? ThemeConstants.accentColor.withOpacity(0.2)
                          : ThemeConstants.accentColor.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white : ThemeConstants.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: ThemeConstants.accentColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                    )).toList(),
                  ),
            ],
          ),
        ),

        const SizedBox(height: ThemeConstants.largePadding),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shadowColor: Colors.black26,
        color: isDark ? Colors.grey.shade800 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: ThemeConstants.accentColor,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildDetailItem(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeConstants.accentColor.withOpacity(0.2)
                  : ThemeConstants.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? ThemeConstants.accentColor : ThemeConstants.accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDark) { /* Keep original */ final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300; final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100; return Shimmer.fromColors( baseColor: baseColor, highlightColor: highlightColor, child: ListView( padding: const EdgeInsets.all(ThemeConstants.mediumPadding), children: [ Row( children: [ const CircleAvatar(radius: 45), const SizedBox(width: ThemeConstants.mediumPadding), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Container(width: 150, height: 20, color: Colors.white), const SizedBox(height: 8), Container(width: 100, height: 16, color: Colors.white), const SizedBox(height: 8), Container(width: 120, height: 14, color: Colors.white),],),),],), const SizedBox(height: ThemeConstants.largePadding), const Divider(), const SizedBox(height: ThemeConstants.mediumPadding), Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), Container(width: double.infinity, height: 16, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), const SizedBox(height: ThemeConstants.mediumPadding), Container(width: double.infinity, height: 20, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), Wrap( spacing: 8.0, runSpacing: 4.0, children: List.generate(5, (_) => Chip(label: Container(width: 60, height: 14, color: Colors.white))),),],),); }
  Widget _buildNotLoggedInView(bool isDark) { /* Keep original */ return Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.person_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400), const SizedBox(height: 20), Text('Please log in to view your profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)), const SizedBox(height: 8), Text('Manage your communities, posts, and settings', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton( onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Log In'),),],),); }
  Widget _buildErrorView(String message, bool isDark) { /* Keep original */ return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 60), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)), const SizedBox(height: 24), CustomButton( text: 'Retry', icon: Icons.refresh, onPressed: _loadUserData, type: ButtonType.secondary,),],),),); }
}