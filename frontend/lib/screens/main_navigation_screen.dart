// frontend/lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Screen Imports (Update path for EventsScreen) ---
import 'feed/posts_screen.dart';
import 'events/events_list_screen.dart'; // <-- CORRECTED PATH
import 'notifications_screen.dart';
import 'communities/communities_screen.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';

// --- Service Imports ---
import '../services/notification_provider.dart';
import '../services/auth_provider.dart';

// --- Theme Imports ---
import '../theme/theme_constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  // Ensure class name matches the renamed screen file
  static final List<Widget> _screens = [
    const PostsScreen(),
    const EventsListScreen(), // <-- Use EventsListScreen
    const NotificationsScreen(),
    const CommunitiesScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _pageController = PageController(initialPage: _selectedIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (_selectedIndex == index) return;
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadNotificationCount = context.watch<NotificationProvider>().unreadCount;
    final clampedSelectedIndex = _selectedIndex.clamp(0, _screens.length - 1);

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: _screens.length,
        itemBuilder: (BuildContext context, int index) {
          return _screens[index];
        },
        onPageChanged: (index) {
          if (index >= 0 && index < _screens.length && mounted) {
            setState(() => _selectedIndex = index);
          }
        },
        physics: const NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
          boxShadow: [ BoxShadow(color: theme.shadowColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2),) ],
          border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(clampedSelectedIndex == 0 ? Icons.dynamic_feed : Icons.dynamic_feed_outlined), label: 'Feed'),
              BottomNavigationBarItem(icon: Icon(clampedSelectedIndex == 1 ? Icons.event : Icons.event_outlined), label: 'Events'),
              BottomNavigationBarItem(
                  icon: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                    Icon(clampedSelectedIndex == 2 ? Icons.notifications : Icons.notifications_none_outlined),
                    if (unreadNotificationCount > 0)
                      Positioned(top: -5, right: -7, child: Container(padding: EdgeInsets.all(unreadNotificationCount > 9 ? 2.5 : 3.5), decoration: BoxDecoration(color: ThemeConstants.errorColor, shape: BoxShape.circle, border: Border.all(color: theme.bottomNavigationBarTheme.backgroundColor ?? theme.canvasColor, width: 1.5)), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Text(unreadNotificationCount > 99 ? '99+' : unreadNotificationCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                  ]), label: 'Alerts'),
              BottomNavigationBarItem(icon: Icon(clampedSelectedIndex == 3 ? Icons.people : Icons.people_outline), label: 'Communities'),
              BottomNavigationBarItem(icon: Icon(clampedSelectedIndex == 4 ? Icons.chat_bubble : Icons.chat_bubble_outline), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(clampedSelectedIndex == 5 ? Icons.person : Icons.person_outline), label: 'Profile'),
            ],
            currentIndex: clampedSelectedIndex,
            onTap: _onNavItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: ThemeConstants.accentColor,
            unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            showSelectedLabels: true,
            showUnselectedLabels: true,
          ),
        ),
      ),
    );
  }
}
