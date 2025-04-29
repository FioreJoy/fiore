// frontend/lib/screens/main_navigation_screen.dart

import 'package:flutter/material.dart';

// Import the main screens based on their NEW locations
import 'feed/explore_screen.dart';
import 'communities/communities_screen.dart';
import 'chat/chat_screen.dart'; // <-- CORRECTED IMPORT PATH AND FILE NAME
import 'profile/profile_screen.dart';

import '../theme/theme_constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Define the screens for the bottom navigation using updated paths and names
  static const List<Widget> _screens = [
    ExploreScreen(),
    CommunitiesScreen(),
    ChatScreen(), // <-- CORRECTED CLASS NAME
    ProfileScreen(),
  ];

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
        duration: ThemeConstants.shortAnimation, // Use theme constant
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
        physics: const NeverScrollableScrollPhysics(),
        children: _screens, // Disable swiping between main pages
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1), // Use theme shadow color
              blurRadius: 8,
              offset: const Offset(0, -3),
            )
          ],
          border: Border(
            top: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                width: 0.5),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Explore'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Communities'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Chat'), // Label reflects the section
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onNavItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent, // Use container background
            elevation: 0,
            selectedItemColor: ThemeConstants.accentColor,
            unselectedItemColor:
            isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            selectedFontSize: 12,
            unselectedFontSize: 10,
          ),
        ),
      ),
    );
  }
}