// frontend/lib/screens/main_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Keep provider

// --- Screen Imports ---
// import 'feed/explore_screen.dart'; // Comment out or remove ExploreScreen import
import 'feed/posts_screen.dart';       // **** IMPORT PostsScreen ****
import 'communities/communities_screen.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';

// --- Theme Imports ---
import '../theme/theme_constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // **** UPDATE THE SCREEN LIST ****
  static const List<Widget> _screens = [
    PostsScreen(), // Use PostsScreen for the first tab (index 0)
    CommunitiesScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];
  // **** END SCREEN LIST UPDATE ****

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: ThemeConstants.shortAnimation,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: _screens, // Use the updated list
        physics: const NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
          boxShadow: [ BoxShadow( color: theme.shadowColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -3), ) ],
          border: Border( top: BorderSide( color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            // **** UPDATE LABELS/ICONS IF NEEDED ****
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.dynamic_feed_outlined), // Changed icon?
                  activeIcon: Icon(Icons.dynamic_feed),   // Changed icon?
                  label: 'Feed'),                       // Changed label to 'Feed'
              BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Communities'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Chat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
            // **** END LABEL/ICON UPDATE ****
            currentIndex: _selectedIndex,
            onTap: _onNavItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: ThemeConstants.accentColor,
            unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            selectedFontSize: 12,
            unselectedFontSize: 10,
          ),
        ),
      ),
    );
  }
}