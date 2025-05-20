import 'package:flutter/material.dart';

// --- Screen Imports for Tabs (Corrected Paths) ---
import '../../events/screens/events_list_screen.dart';
import '../../communities/screens/communities_screen.dart';
// No SearchScreen import yet as it's a placeholder in this screen

// --- Core Imports ---
// import '../../../../core/theme/theme_constants.dart'; // Not directly used, but AppBar uses theme

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Events', 'icon': Icons.event_available_outlined},
    {'title': 'Communities', 'icon': Icons.people_alt_outlined},
    {'title': 'Search', 'icon': Icons.search_outlined}, // Placeholder tab
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      // Update AppBar title dynamically when tab changes, if needed
      if (mounted) {
        setState(() {});
      }
    });
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false, // No back button if this is a root tab screen
        title: Text(_tabs[_tabController.index]['title'],
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black)), // Dynamic title
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 2.5,
          tabs: _tabs
              .map((tab) => Tab(
                    icon: Icon(tab['icon'] as IconData?),
                    text: tab['title'] as String?,
                    iconMargin: const EdgeInsets.only(bottom: 4.0),
                  ))
              .toList(),
          // onTap handled by TabController listener if AppBar title needs update
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const EventsListScreen(),
          const CommunitiesScreen(),
          // Placeholder for Search
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
