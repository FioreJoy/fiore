import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/theme_constants.dart';
import '../app_constants.dart';
import 'login_screen.dart';
import 'settings.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({Key? key}) : super(key: key);

  @override
  _MeScreenState createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Mock user data
  final Map<String, dynamic> _mockUserStats = {
    'joinedCommunities': 8,
    'eventsParticipated': 15,
    'posts': 27,
    'replies': 42,
  };

  // Mock recent events
  final List<Map<String, dynamic>> _mockRecentEvents = [
    {'name': 'Tech Conference 2023', 'date': '2 days ago', 'communityName': 'Tech Enthusiasts'},
    {'name': 'Book Club Discussion', 'date': '1 week ago', 'communityName': 'Book Club'},
    {'name': 'Morning Fitness Session', 'date': '2 weeks ago', 'communityName': 'Fitness Freaks'},
  ];

  // Generate a gradient color for avatar
  List<Color> _getAvatarGradient(String? seed) {
    if (seed == null || seed.isEmpty) {
      return [ThemeConstants.primaryColor, ThemeConstants.accentColor];
    }

    // Use the first character of the name to seed a predictable but varied color
    final seedValue = seed.toLowerCase().codeUnitAt(0);
    final random = math.Random(seedValue);

    // Generate a random hue based on the seed
    final hue1 = random.nextDouble() * 360;
    final hue2 = (hue1 + 40 + random.nextDouble() * 40) % 360;

    return [
      HSLColor.fromAHSL(1, hue1, 0.7, 0.5).toColor(),
      HSLColor.fromAHSL(1, hue2, 0.8, 0.4).toColor(),
    ];
  }

  // Get first letter of user's name
  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return _buildNotLoggedIn(isDark);
        }

        final apiService = Provider.of<ApiService>(context, listen: false);

        return FutureBuilder<Map<String, dynamic>>(
          future: apiService.fetchUserDetails(authProvider.token!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen(isDark);
            }

            if (snapshot.hasError) {
              return _buildErrorScreen(snapshot.error.toString(), isDark);
            }

            final user = snapshot.data!;
            final avatarGradient = _getAvatarGradient(user['name']);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ThemeConstants.largePadding),
                        decoration: BoxDecoration(
                          color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                          boxShadow: ThemeConstants.softShadow(),
                        ),
                        child: Column(
                          children: [
                            // Avatar with initial
                            Hero(
                              tag: 'profile_avatar',
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: avatarGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: avatarGradient[0].withOpacity(0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitial(user['name']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: ThemeConstants.mediumPadding),

                            // User Name
                            Text(
                              user['name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Username
                            Text(
                              '@${user['username'] ?? 'username'}',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: ThemeConstants.mediumPadding),

                            // Edit Profile Button
                            OutlinedButton.icon(
                              onPressed: () {
                                // Navigate to edit profile
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Profile'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ThemeConstants.accentColor, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ThemeConstants.buttonBorderRadius),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ThemeConstants.mediumPadding,
                                  vertical: ThemeConstants.smallPadding,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stats Section
                      Padding(
                        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stats',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: ThemeConstants.mediumPadding),

                                // Stats grid
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  childAspectRatio: 2,
                                  crossAxisSpacing: ThemeConstants.smallPadding,
                                  mainAxisSpacing: ThemeConstants.smallPadding,
                                  children: [
                                    _buildStatCard(
                                      'Communities',
                                      _mockUserStats['joinedCommunities'].toString(),
                                      Icons.people,
                                      ThemeConstants.accentColor,
                                      isDark,
                                    ),
                                    _buildStatCard(
                                      'Events',
                                      _mockUserStats['eventsParticipated'].toString(),
                                      Icons.event,
                                      ThemeConstants.highlightColor,
                                      isDark,
                                    ),
                                    _buildStatCard(
                                      'Posts',
                                      _mockUserStats['posts'].toString(),
                                      Icons.article,
                                      Colors.orangeAccent,
                                      isDark,
                                    ),
                                    _buildStatCard(
                                      'Replies',
                                      _mockUserStats['replies'].toString(),
                                      Icons.chat_bubble,
                                      Colors.purpleAccent,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Recent Activity Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Activity',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // View all activity
                                      },
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: ThemeConstants.smallPadding),

                                // Recent events list
                                ..._mockRecentEvents.map((event) => _buildActivityItem(
                                  event['name'],
                                  event['date'],
                                  event['communityName'],
                                  isDark,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Account Actions
                      Padding(
                        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: ThemeConstants.mediumPadding),

                                _buildAccountActionButton(
                                  'Privacy Settings',
                                  Icons.lock_outline,
                                  ThemeConstants.accentColor,
                                  isDark,
                                  onTap: () {
                                    // Navigate to privacy settings
                                  },
                                ),

                                _buildAccountActionButton(
                                  'Notification Settings',
                                  Icons.notifications_none,
                                  ThemeConstants.highlightColor,
                                  isDark,
                                  onTap: () {
                                    // Navigate to notification settings
                                  },
                                ),

                                _buildAccountActionButton(
                                  'Help & Support',
                                  Icons.help_outline,
                                  Colors.green,
                                  isDark,
                                  onTap: () {
                                    // Navigate to help & support
                                  },
                                ),

                                _buildAccountActionButton(
                                  'Logout',
                                  Icons.exit_to_app,
                                  ThemeConstants.errorColor,
                                  isDark,
                                  onTap: () {
                                    authProvider.logout();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // App version info
                      Padding(
                        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        child: Text(
                          'Connections v1.2.4',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: ThemeConstants.largePadding),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(ThemeConstants.smallPadding),
      decoration: BoxDecoration(
        color: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String date, String community, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConstants.smallPadding),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ThemeConstants.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'In $community • $date',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionButton(
    String title,
    IconData icon,
    Color color,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: ThemeConstants.smallPadding,
          horizontal: ThemeConstants.smallPadding,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThemeConstants.borderRadius),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn(bool isDark) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 60,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: ThemeConstants.largePadding),
              Text(
                'You are not logged in',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThemeConstants.smallPadding),
              Text(
                'Log in to view your profile and access all features',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThemeConstants.largePadding),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: ThemeConstants.mediumPadding),
                  ),
                  child: const Text('Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: ThemeConstants.accentColor,
            ),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: ThemeConstants.errorColor,
              ),
              const SizedBox(height: ThemeConstants.mediumPadding),
              Text(
                'Error loading profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThemeConstants.smallPadding),
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ThemeConstants.largePadding),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
