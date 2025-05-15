// frontend/lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Screen Imports ---
import 'notifications_screen.dart';
import 'profile/profile_screen.dart'; 

// --- New Stub Screen Imports ---
import 'feed/home_feed_screen.dart'; 
import 'explore/explore_screen.dart'; 
import 'chat/chat_list_screen.dart';  // For "Chat" tab

// --- Create Action Screens ---
import 'create/create_post_screen.dart';
import '../widgets/create_event_dialog.dart'; 
import 'communities/create_community_screen.dart';


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

  // MODIFIED: Made _screens non-static and final, initialized directly.
  // ChatScreen is replaced by ChatListScreen for the tab.
  final List<Widget> _screens = [
    const HomeFeedScreen(),   
    const ExploreScreen(),    
    const ChatListScreen(),   // Tab 2: Chat List
    const ProfileScreen(),    
  ];

  // Titles for the AppBar corresponding to each tab
  // MODIFIED: Removed ChatScreen from here as ChatListScreen will be used.
  static const List<String> _appBarTitles = [
    'Home',
    'Explore', // ExploreScreen will have its own AppBar with TabBar
    'Messages', // Title for ChatListScreen
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0; // Default to Home
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

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).canvasColor, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeConstants.cardBorderRadius)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Create Event'),
                onTap: () {
                  Navigator.pop(context); 
                  showDialog(
                    context: context,
                    builder: (BuildContext context) => CreateEventDialog(
                      communityId: "1", // Placeholder - Needs context
                      onSubmit: (title, description, locationAddress, dateTime, maxParticipants, imageFile, latitude, longitude) {
                        print('Event created: $title');
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.post_add_outlined),
                title: const Text('Create Post'),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Create Community'),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCommunityScreen()));
                },
              ),
              const SizedBox(height: 10), 
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadNotificationCount = notificationProvider.unreadCount;
    final clampedSelectedIndex = _selectedIndex.clamp(0, _screens.length - 1);

    String currentAppBarTitle = _appBarTitles[clampedSelectedIndex];
    bool showMainAppBar = true;

    // ExploreScreen has its own AppBar with TabBar
    if (clampedSelectedIndex == 1) { // Index 1 is ExploreScreen
      showMainAppBar = false; 
    }


    return Scaffold(
      appBar: showMainAppBar ? AppBar(
        title: Text(currentAppBarTitle),
        centerTitle: false, 
        backgroundColor: isDark ? ThemeConstants.backgroundDarker : ThemeConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: isDark ? 0.5 : 1.0, 
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_outlined),
                if (unreadNotificationCount > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: EdgeInsets.all(unreadNotificationCount > 9 ? 2.5 : 3.5),
                      decoration: BoxDecoration(
                        color: ThemeConstants.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.appBarTheme.backgroundColor ?? theme.canvasColor, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unreadNotificationCount > 99 ? '99+' : unreadNotificationCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
            },
          ),
          const SizedBox(width: 8), 
        ],
      ) : null, // Set AppBar to null if ExploreScreen is active
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        tooltip: 'Create',
        backgroundColor: ThemeConstants.accentColor,
        foregroundColor: ThemeConstants.primaryColor, 
        elevation: 4.0,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
        elevation: 8, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_filled, label: 'Home', index: 0, context: context),
            _buildNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explore', index: 1, context: context),
            const SizedBox(width: 40), 
            _buildNavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', index: 2, context: context),
            _buildNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 3, context: context),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavItemTapped(index),
        customBorder: const CircleBorder(),
        splashColor: ThemeConstants.accentColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? ThemeConstants.accentColor : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? ThemeConstants.accentColor : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
