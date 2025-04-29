// frontend/lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Provider Imports ---
// Correct path if home_screen is in /screens
// <<< FIX: Use correct path and class name for Theme Provider >>>
import '../services/theme_provider.dart'; // Path to the ThemeProvider we created

// --- Theme and Constants ---
import '../theme/theme_constants.dart'; // Correct path if home_screen is in /screens

// --- Screen Imports (Using relative paths from /screens) ---
// Assuming explore_screen.dart is in /screens/feed/
import 'feed/explore_screen.dart';
// Assuming communities_screen.dart is in /screens/communities/
import 'communities/communities_screen.dart';
// Assuming chat_screen.dart is in /screens/chat/
import 'chat/chat_screen.dart';
// Assuming profile_screen.dart is in /screens/profile/
import 'profile/profile_screen.dart';

// IMPORTANT: Make sure the actual class names inside these files match
// ExploreScreen, CommunitiesScreen, ChatScreen, ProfileScreen respectively.

class HomeScreen extends StatefulWidget {
  // This widget likely doesn't need to be stateful if navigation
  // state is handled by MainNavigationScreen. Consider making it StatelessWidget.
  // For now, keeping StatefulWidget structure as provided.
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Note: If this HomeScreen is always nested inside MainNavigationScreen,
  // the _selectedIndex, _pageController logic might be redundant here
  // and should primarily live in MainNavigationScreen.
  // Assuming for now this structure is intended.

  int _selectedIndex = 0; // Default to Explore
  late final List<Widget> _screens;
  late final PageController _pageController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _screens = <Widget>[
      // <<< FIX: Use correct Class Names (ensure these exist) >>>
      const ExploreScreen(),
      const CommunitiesScreen(),
      const ChatScreen(),
      const ProfileScreen(), // Changed from MeScreen to match common naming
    ];

    _pageController = PageController(initialPage: _selectedIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: ThemeConstants.shortAnimation,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation( parent: _animationController, curve: Curves.easeInOut, ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // This function might be handled by MainNavigationScreen instead
  void _onNavItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: ThemeConstants.mediumAnimation,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // <<< FIX: Use correct Provider class: ThemeProvider >>>
    final themeProvider = Provider.of<ThemeProvider>(context);
    // <<< FIX: Use correct getter: themeMode >>>
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // Usually, the Scaffold including BottomNavigationBar lives in MainNavigationScreen.
    // If HomeScreen is *just* the content area, it might not need its own Scaffold.
    // Assuming here it *does* build the main content structure including the PageView.
    return Scaffold(
      // AppBar might be handled by individual screens or MainNavigationScreen
      // appBar: AppBar(title: Text('Home')), // Example if needed here

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
          // onPageChanged typically isn't needed with NeverScrollableScrollPhysics
        ),
      ),

      // If this is nested, the BottomNavBar should be in the parent (MainNavigationScreen)
      // If this IS the main screen WITH the nav bar:
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _selectedIndex,
      //   onTap: _onNavItemTapped,
      //   type: BottomNavigationBarType.fixed,
      //   backgroundColor: isDark ? ThemeConstants.backgroundDarker : Colors.white,
      //   selectedItemColor: ThemeConstants.accentColor,
      //   unselectedItemColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      //   showUnselectedLabels: true,
      //   selectedFontSize: 12,
      //   unselectedFontSize: 12,
      //   items: [
      //     _buildNavItem(Icons.explore_outlined, Icons.explore, 'Explore', 0, 0),
      //     _buildNavItem(Icons.people_outline, Icons.people, 'Communities', 1, 0),
      //     _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', 2, 0),
      //     _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 3, 0),
      //   ],
      //   elevation: 8,
      // ),
    );
  }

// This helper might also belong in MainNavigationScreen
// BottomNavigationBarItem _buildNavItem(
//   IconData icon, IconData activeIcon, String label, int index, int badgeCount) {
//     bool isSelected = _selectedIndex == index;
//     return BottomNavigationBarItem(
//       icon: Stack( /* ... badge logic ... */ children: [ Icon(isSelected ? activeIcon : icon), /* badge */ ],),
//       label: label,
//     );
// }
}