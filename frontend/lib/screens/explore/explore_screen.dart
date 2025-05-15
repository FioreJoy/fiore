// frontend/lib/screens/explore/explore_screen.dart
import 'package:flutter/material.dart';

// --- Screen Imports for Tabs ---
import '../events/events_list_screen.dart'; // Existing screen for events
import '../communities/communities_screen.dart'; // Existing screen for communities
// import '../search_screen.dart'; // Placeholder for a future dedicated search screen

// --- Theme Imports ---
import '../../theme/theme_constants.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Titles and Icons for the tabs
  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Events', 'icon': Icons.event_available_outlined},
    {'title': 'Communities', 'icon': Icons.people_alt_outlined},
    {'title': 'Search', 'icon': Icons.search_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // The AppBar for ExploreScreen is managed by MainNavigationScreen when this tab is selected.
    // However, ExploreScreen itself needs to provide the TabBar as the 'bottom' of that AppBar.
    // This is typically handled by returning a Scaffold whose AppBar has a 'bottom' property.
    // If MainNavigationScreen dynamically sets the AppBar, we just need to build the body with TabBarView.

    // For this setup, MainNavigationScreen's AppBar is generic.
    // ExploreScreen will build its own AppBar with the TabBar.
    // This means the AppBar defined in MainNavigationScreen for the "Explore" tab will be overridden
    // when this screen is active if ExploreScreen returns its own Scaffold with an AppBar.
    // Let's ensure MainNavigationScreen *doesn't* show its title for the Explore tab index.

    return Scaffold(
      // This AppBar is specific to the Explore tab
      appBar: AppBar(
        // title: const Text('Explore'), // Title is set by MainNavigationScreen, or remove if redundant
        // If MainNavigationScreen's AppBar is used, this title would conflict or be hidden.
        // For clarity, let's assume MainNavigationScreen's AppBar title will be empty for this tab.
        // We just need to provide the TabBar.
        // The `title` for this screen is effectively managed by `MainNavigationScreen`.
        // We only need to provide the `bottom` part for the `TabBar`.
        // However, the `TabBar` needs to be part of an `AppBar`.
        // The cleanest way is for ExploreScreen to have its own AppBar.
        // MainNavigationScreen's AppBar should be hidden or minimal for this tab.
        automaticallyImplyLeading: false, // No back button from MainNavigationScreen
        title: Text(_tabs[_tabController.index]['title'], style: TextStyle(fontWeight: FontWeight.bold)), // Dynamic title
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 2.5,
          tabs: _tabs.map((tab) => Tab(
            icon: Icon(tab['icon'] as IconData?),
            text: tab['title'] as String?,
            iconMargin: const EdgeInsets.only(bottom: 4.0),
          )).toList(),
          onTap: (index) {
            // Optional: Add any logic when a tab is tapped, though TabController handles the switch.
            // This setState is just to update the AppBar title if it's dynamic.
            setState(() {});
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const EventsListScreen(),    // Existing screen
          const CommunitiesScreen(), // Existing screen
          // Placeholder for a dedicated global search screen
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Global Search (Coming Soon)',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Search for events, communities, posts, and users.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
