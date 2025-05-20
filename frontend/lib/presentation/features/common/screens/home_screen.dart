import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Service/Provider Imports ---
// import '../../../../services/auth_provider.dart'; // AuthProvider is usually not directly used in HomeScreen like this after refactor
import '../../../providers/auth_provider.dart'; // Path from main_navigation_screen
import '../../../../core/theme/theme_provider.dart'; // Corrected path
import '../../../../core/theme/theme_constants.dart';

// --- Screen Imports for Tabs (paths relative to common/screens) ---
import '../../feed/screens/explore_screen.dart'; // Corrected Path
// Corrected: CommunitiesScreen itself needs path updates for its internal imports.
// For now, this import refers to its new location.
import '../../communities/screens/communities_screen.dart';
import '../../chat/screens/chat_list_screen.dart'; // Changed from ChatroomScreen/ChatScreen to ChatListScreen
import '../../profile/screens/profile_screen.dart'; // Corrected path

// Note: main_navigation_screen.dart handles the main app structure including this HomeScreen's display logic.
// The original HomeScreen was simple, this one is adapted from your 'fiore/frontend/lib/screens/home_screen.dart' provided,
// which seemed more like a primary navigation container. If the 'home_screen.dart'
// inside 'screens/feed/' in your gitingest was the *actual* home feed, that one will be updated separately.
// This version will act as a placeholder or can be integrated if its logic (pageview + custom bottom nav) is preferred.

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  late final PageController _pageController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _screens = <Widget>[
      const ExploreScreen(), // Assuming feed/explore_screen is the main explore tab
      const CommunitiesScreen(),
      const ChatListScreen(), // Changed to ChatListScreen
      const ProfileScreen(),
    ];

    _pageController = PageController(initialPage: _selectedIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: ThemeConstants.shortAnimation,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation
    _animationController.forward();
    // print("HomeScreen initState completed"); // Debug comment removed
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    // print("HomeScreen disposed"); // Debug comment removed
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (mounted) {
      setState(() {
        _selectedIndex = index;
        // Animate to the new page
        _pageController.animateToPage(
          index,
          duration: ThemeConstants.mediumAnimation,
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Watch for theme changes
    final isDark = themeProvider.currentTheme.brightness ==
        Brightness.dark; // Use currentTheme's brightness

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            if (mounted) {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          children: _screens,
          physics:
              const NeverScrollableScrollPhysics(), // Typically controlled by bottom nav taps
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor:
            isDark ? ThemeConstants.backgroundDarker : Colors.white,
        selectedItemColor: ThemeConstants.accentColor,
        unselectedItemColor:
            isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        showUnselectedLabels: true, // Keep labels for better UX
        items: [
          // Ensure badgeCount handling or removal if not implemented fully in NotificationProvider yet
          _buildNavItem(Icons.explore_outlined, Icons.explore, 'Explore',
              _selectedIndex, 0),
          _buildNavItem(Icons.people_outline, Icons.people, 'Communities',
              _selectedIndex, 1),
          _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat',
              _selectedIndex, 2),
          _buildNavItem(
              Icons.person_outline, Icons.person, 'Profile', _selectedIndex, 3),
        ],
        elevation: 8,
      ),
    );
  }

  // Corrected parameter order for badge
  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int currentViewIndex, // Current selected index of the PageView
    int itemIndex, // Index of this specific nav item
    // int badgeCount,    // Assuming badgeCount logic will be added later or comes from a provider
  ) {
    final bool isSelected = currentViewIndex == itemIndex;
    // final int badgeCount = 0; // Placeholder until badge logic is restored/sourced

    return BottomNavigationBarItem(
      icon: Icon(isSelected ? activeIcon : icon),
      // Icon(
      //   isSelected ? activeIcon : icon,
      // ),
      // TODO: Restore badge logic when NotificationProvider or similar is integrated for these badges
      // if (badgeCount > 0)
      //   Positioned(
      //     right: 0,
      //     top: 0,
      //     child: Container(
      //       padding: const EdgeInsets.all(2),
      //       decoration: const BoxDecoration(
      //         color: ThemeConstants.errorColor,
      //         shape: BoxShape.circle,
      //       ),
      //       constraints: const BoxConstraints(
      //         minWidth: 14,
      //         minHeight: 14,
      //       ),
      //       child: Text(
      //         badgeCount > 9 ? '9+' : badgeCount.toString(),
      //         style: const TextStyle(
      //           color: Colors.white,
      //           fontSize: 8,
      //           fontWeight: FontWeight.bold,
      //         ),
      //         textAlign: TextAlign.center,
      //       ),
      //     ),
      //   ),
      label: label,
    );
  }
}
