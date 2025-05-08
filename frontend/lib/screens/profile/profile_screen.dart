// frontend/lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

// --- Service Imports ---
import '../../services/api/user_service.dart';
import '../../services/api/auth_service.dart';
import '../../services/auth_provider.dart';

// --- Widget Imports ---
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';

// --- Navigation Imports ---
import '../settings/settings_home_screen.dart';
import '../settings/settings_feature/account/edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({ Key? key }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoadingProfile = false;
  bool _isLoadingStats = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _userStats;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileAndStats();
    });
  }

  Future<void> _loadProfileAndStats() async {
    if (_isLoadingProfile || _isLoadingStats || !mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) setState(() { _userData=null; _userStats=null; _error="Please log in"; _isLoadingProfile=false; _isLoadingStats=false; });
      return;
    }
    setState(() { _isLoadingProfile=true; _isLoadingStats=true; _error=null; });
    try {
      final results = await Future.wait([
        _fetchProfileData(authProvider.token!),
        _fetchStatsData(authProvider.token!),
      ]);
      if (!mounted) return;
      setState(() {
        _userData = results[0]; _userStats = results[1] ?? {}; // Ensure stats is map even if null
        _isLoadingProfile=false; _isLoadingStats=false;
        if (_userData == null) _error = "Failed to load profile data.";
        if (results[1] == null) print("Warning: Failed to load user stats.");
      });
    } catch (e) {
      print("Error loading profile/stats: $e");
      if (mounted) setState(() { _error="Failed to load data: ${e.toString().replaceFirst("Exception: ", "")}"; _isLoadingProfile=false; _isLoadingStats=false; });
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileData(String token) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try { return await authService.getCurrentUserProfile(token); }
    catch (e) { print("Error fetching profile data: $e"); return null; }
  }

  Future<Map<String, dynamic>?> _fetchStatsData(String token) async {
    final userService = Provider.of<UserService>(context, listen: false);
    try { return await userService.getMyStats(token); }
    catch (e) { print("Error fetching stats data: $e"); return null; }
  }

  void _navigateToSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsHomeScreen()),)
        .then((_) => _loadProfileAndStats());
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()),);
    if (result == true && mounted) { _loadProfileAndStats(); }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(dateTimeString).toLocal()); }
    catch (e) { return 'Invalid Date'; }
  }

  String _formatLocation(dynamic locationData, String? address) {
    if (address != null && address.isNotEmpty) return address;
    if (locationData is Map) {
      final lon = locationData['longitude']; final lat = locationData['latitude'];
      if (lon is num && lat is num && (lon != 0 || lat != 0)) { return '(${lon.toStringAsFixed(3)}, ${lat.toStringAsFixed(3)})'; }
    } else if (locationData is String && locationData.isNotEmpty && locationData != '(0,0)') { return locationData; }
    return 'Not set';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!authProvider.isAuthenticated && _userData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _userData=null; _userStats=null; _error="Please log in."; _isLoadingProfile=false; _isLoadingStats=false; });
      });
    } else if (authProvider.isAuthenticated && _userData == null && !_isLoadingProfile && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadProfileAndStats(); });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [ if (authProvider.isAuthenticated) IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: _navigateToSettings)],
        elevation: 0,
        backgroundColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade50,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileAndStats,
        child: _buildBody(authProvider, isDark),
      ),
    );
  }

  // **** MOVE HELPER METHODS INSIDE THE STATE CLASS ****

  Widget _buildBody(AuthProvider authProvider, bool isDark) {
    if ((_isLoadingProfile || _isLoadingStats) && _userData == null && _userStats == null) {
      return _buildLoadingShimmer(isDark);
    }
    if (!authProvider.isAuthenticated) {
      return _buildNotLoggedInView(isDark);
    }
    if (_error != null) {
      return _buildErrorView(_error!, isDark);
    }
    if (_userData != null) {
      return _buildProfileView(isDark);
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildProfileView(bool isDark) {
    final String name = _userData?['name'] ?? 'User';
    final String username = _userData?['username'] ?? 'username';
    // final String email = _userData?['email'] ?? 'No email'; // Hide email for privacy?
    final String gender = _userData?['gender'] ?? 'Not specified';
    final String college = _userData?['college'] ?? 'Not specified';
    final String? imageUrl = context.read<AuthProvider>().userImageUrl ?? _userData?['image_url'];
    final List<String> interests = List<String>.from(_userData?['interests'] ?? []);
    final String joinedDate = _formatDateTime(_userData?['created_at']);
    final String lastSeen = _formatDateTime(_userData?['last_seen']);
    final String displayLocation = _formatLocation(_userData?['current_location'], _userData?['current_location_address']);

    final int followersCount = _userData?['followers_count'] ?? 0;
    final int followingCount = _userData?['following_count'] ?? 0;
    final int communitiesJoined = _userStats?['communities_joined'] ?? 0;
    final int eventsAttended = _userStats?['events_attended'] ?? 0;
    final int postsCreated = _userStats?['posts_created'] ?? 0;

    final Color headerStartColor = isDark ? ThemeConstants.accentColor.withOpacity(0.1) : ThemeConstants.primaryColor.withOpacity(0.05);
    final Color headerEndColor = isDark ? Colors.black.withOpacity(0.0) : Colors.grey.shade50;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // --- Header Section ---
        Container( /* ... Header Container ... */
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration( gradient: LinearGradient(colors: [headerStartColor, headerEndColor], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Column(children: [ Row(children: [
              Container( /* ... Avatar Container ... */
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).cardColor, width: 3), boxShadow: ThemeConstants.softShadow()),
                child: CircleAvatar(radius: 45, backgroundColor: Colors.grey.shade300, backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : const NetworkImage(AppConstants.defaultAvatar) as ImageProvider),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4), Text("@$username", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                const SizedBox(height: 6), Text('Joined: $joinedDate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
              ])),
            ]), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit Profile'), onPressed: _navigateToEditProfile, style: OutlinedButton.styleFrom(foregroundColor: isDark ? ThemeConstants.accentColor : ThemeConstants.primaryColor, side: BorderSide(color: isDark ? ThemeConstants.accentColor.withOpacity(0.5) : ThemeConstants.primaryColor.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
              const SizedBox(width: 16),
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Share'), onPressed: () {}, style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.black54, side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
            ])])
        ),
        // --- Stats Section ---
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Adjusted padding
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildStatItem(context, value: followersCount.toString(), label: 'Followers', isDark: isDark),
            _buildStatItem(context, value: followingCount.toString(), label: 'Following', isDark: isDark),
            _buildStatItem(context, value: postsCreated.toString(), label: 'Posts', isDark: isDark),
          ]),
        ),
        const Divider(height: 1),
        // --- About Section ---
        Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle('About', isDark),
          _buildDetailItem(Icons.wc_outlined, 'Gender', gender, isDark),
          _buildDetailItem(Icons.school_outlined, 'College', college, isDark),
          _buildDetailItem(Icons.location_on_outlined, 'Location', displayLocation, isDark),
        ])),
        // --- Interests Section ---
        if (interests.isNotEmpty) ...[ const Divider(height: 1), Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle('Interests', isDark), const SizedBox(height: 8),
          Wrap(spacing: 8.0, runSpacing: 8.0, children: interests.map((interest) => Chip(label: Text(interest), labelStyle: TextStyle(fontSize: 13, color: isDark ? ThemeConstants.primaryColor : ThemeConstants.accentColor), backgroundColor: isDark ? ThemeConstants.accentColor.withOpacity(0.8) : ThemeConstants.accentColor.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), side: BorderSide.none)).toList()),
        ]))],
        // --- Activity Section ---
        const Divider(height: 1), Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle('Activity', isDark),
          _buildDetailItem(Icons.group_work_outlined, 'Communities Joined', communitiesJoined.toString(), isDark),
          _buildDetailItem(Icons.event_available_outlined, 'Events Attended', eventsAttended.toString(), isDark),
        ])),
        const SizedBox(height: 30),
      ],
    );
  }

  // --- Helper Widgets (Now INSIDE the State class) ---
  Widget _buildStatItem(BuildContext context, {required String value, required String label, required bool isDark}) {
    return Column( mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87));
  }

  Widget _buildDetailItem(IconData icon, String label, String value, bool isDark) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [
      Icon(icon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value.isNotEmpty ? value : 'Not specified', style: Theme.of(context).textTheme.bodyMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
      ])),
    ]));
  }

  Widget _buildLoadingShimmer(bool isDark) {
    final base = isDark?Colors.grey[800]!:Colors.grey[300]!; final high = isDark?Colors.grey[700]!:Colors.grey[100]!;
    return Shimmer.fromColors(baseColor: base, highlightColor: high, child: ListView(padding: EdgeInsets.zero, children: [
      Container(height: 180, color: Colors.white), // Simulate header area
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: List.generate(3, (_) => Expanded(child: Container(height: 70, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))))), // Simulate stats cards
        const SizedBox(height: 24), Container(height: 20, width: 100, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), // Simulate section header
        Container(height: 16, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)), // Simulate detail line
        Container(height: 16, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
        Container(height: 16, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 16)),
        Container(height: 20, width: 100, color: Colors.white, margin: const EdgeInsets.only(bottom: 12)), // Simulate section header
        Container(height: 50, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 16)), // Simulate interests/activity
      ]))
    ]));
  }

  Widget _buildNotLoggedInView(bool isDark) {
    return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.person_off_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
      const SizedBox(height: 20), Text('Please log in to view your profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade700)),
      const SizedBox(height: 8), Text('Manage your profile, activity, and settings.', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade600)),
      const SizedBox(height: 24), ElevatedButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: ThemeConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Log In'))
    ])));
  }

  Widget _buildErrorView(String message, bool isDark) {
    return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)), const SizedBox(height: 24),
      CustomButton( text: 'Retry', icon: Icons.refresh, onPressed: _loadProfileAndStats, type: ButtonType.secondary,), // Use combined load function
    ],),),);
  }

// **** Closing brace for _ProfileScreenState ****
}