// frontend/lib/screens/communities/communities_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Corrected Service Imports ---
import '../../services/api/community_service.dart'; // Use specific service
import '../../services/auth_provider.dart';
// Import user service if needed to fetch initial joined status
// import '../../services/api/user_service.dart';

// --- Corrected Widget Imports ---
import '../../widgets/community_card.dart';
import '../../widgets/custom_card.dart'; // Used in error UI
import '../../widgets/custom_button.dart'; // Used in error/empty UI

// --- Corrected Theme and Constants ---
import '../../theme/theme_constants.dart';

// --- Corrected Navigation Imports ---
import 'create_community_screen.dart'; // Correct path
import 'community_detail_screen.dart'; // Correct path

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with AutomaticKeepAliveClientMixin {
  // Show joined only toggle
  bool _showJoinedOnly = false;
  @override
  bool get wantKeepAlive => true;

  // State Variables
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSortOption = 'latest';
  Future<List<dynamic>>? _loadCommunitiesFuture;
  String? _error; // Store error message

  // Store local join status for optimistic UI updates
  // Key: communityId (String), Value: isJoined (bool)
  final Map<String, bool> _joinedStatusMap = {};

  // --- Static Data for UI ---
  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.access_time},
    {'id': 'popular', 'label': 'Most Popular', 'icon': Icons.trending_up},
    {'id': 'active', 'label': 'Most Active', 'icon': Icons.bolt},
    {'id': 'nearby', 'label': 'Nearby', 'icon': Icons.location_on},
  ];

  final List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.public},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    {'id': 'gaming', 'label': 'Gaming', 'icon': Icons.sports_esports},
    {'id': 'tech', 'label': 'Tech', 'icon': Icons.code},
    {'id': 'science', 'label': 'Science', 'icon': Icons.science},
    {'id': 'music', 'label': 'Music', 'icon': Icons.music_note},
    {'id': 'sports', 'label': 'Sports', 'icon': Icons.sports},
    {'id': 'college_events', 'label': 'College Events', 'icon': Icons.school},
    {'id': 'activities', 'label': 'Activities', 'icon': Icons.hiking},
    {'id': 'social', 'label': 'Social', 'icon': Icons.people},
    {'id': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerCommunityLoad();
        // TODO: Fetch initial user's joined communities to populate _joinedStatusMap
        // _fetchInitialJoinedStatus(); // Call a new function here
      }
    });
  }

  // --- Data Loading & Filtering ---
  Future<void> _triggerCommunityLoad() async { // Make async for potential await inside
    if (!mounted) return;
    setState(() {
      _error = null; // Clear previous errors on new load attempt
      // Use the specific CommunityService
      final communityService = Provider.of<CommunityService>(context, listen: false);
      // AuthProvider isn't strictly needed here unless API requires token for listing
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (_showJoinedOnly) {
        _loadCommunitiesFuture = communityService.getJoinedCommunities(token: authProvider.token);
      } else if (_selectedCategory == 'trending') {
        _loadCommunitiesFuture = communityService.getTrendingCommunities(token: authProvider.token);
      } else {
        _loadCommunitiesFuture = communityService.getCommunities(token: authProvider.token);
      }
      // Force rebuild to show loading state from FutureBuilder
      setState(() {});
    });
  }

  // TODO: Implement if needed for accurate initial join buttons
  // Future<void> _fetchInitialJoinedStatus() async {
  //    final userService = Provider.of<UserService>(context, listen: false);
  //    final authProvider = Provider.of<AuthProvider>(context, listen: false);
  //    if (!authProvider.isAuthenticated || authProvider.token == null) return;
  //    try {
  //        final joined = await userService.getMyJoinedCommunities(authProvider.token!);
  //        if (mounted) {
  //           setState(() {
  //              _joinedStatusMap.clear();
  //              for (var comm in joined) {
  //                 _joinedStatusMap[comm['id'].toString()] = true;
  //              }
  //           });
  //        }
  //    } catch (e) { print("Error fetching initial joined status: $e"); }
  // }


  List<dynamic> _filterAndSortCommunities(List<dynamic> communities) {
    // 1. Filter by search query
    var filtered = communities.where((comm) { /* Keep existing search logic */
      final name = (comm['name'] ?? '').toString().toLowerCase();
      final description = (comm['description'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery) || description.contains(_searchQuery);
    }).toList();

    // 2. Filter by category
    if (_selectedCategory != 'all' && _selectedCategory != 'trending') {
      final categoryLower = _selectedCategory.toLowerCase();
      filtered = filtered.where((comm) {
        final interest = (comm['interest'] ?? '').toString().toLowerCase();
        return interest == categoryLower;
      }).toList();
    }

    // 3. Apply sorting
    try { // Add try-catch for sorting safety
      if (_selectedSortOption == 'popular') {
        filtered.sort((a, b) => (b['member_count'] as int? ?? 0).compareTo(a['member_count'] as int? ?? 0));
      } else if (_selectedSortOption == 'active') {
        filtered.sort((a, b) => (b['online_count'] as int? ?? 0).compareTo(a['online_count'] as int? ?? 0));
      }
      // 'latest' is assumed default order from API
    } catch (e) {
      print("Error during sorting: $e. Returning unsorted filtered list.");
      // Optionally show a message to the user about sorting failure
    }

    return filtered;
  }


  // --- UI Actions ---
  void _updateSearchQuery(String query) { if (mounted) setState(() => _searchQuery = query.toLowerCase());}
  void _selectCategory(String categoryId) { if (!mounted || _selectedCategory == categoryId) return; setState(() => _selectedCategory = categoryId); _triggerCommunityLoad();}
  void _selectSortOption(String sortOptionId) { if (!mounted || _selectedSortOption == sortOptionId) return; setState(() => _selectedSortOption = sortOptionId); /* Client-side sort triggers rebuild */ }


  // Navigate to detail screen
  void _navigateToCommunityDetail(Map<String, dynamic> communityData) {
    final String communityId = communityData['id'].toString();
    final bool isJoined = _joinedStatusMap[communityId] ?? false; // Use local map

    Navigator.of(context).push<bool>( // Expect bool result
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityData: communityData,
          initialIsJoined: isJoined,
          onToggleJoin: _toggleJoinCommunity, // Pass the callback
        ),
      ),
    ).then((didStatusChange) { // Check if status might have changed
      if (didStatusChange == true && mounted) {
        print("Returned from detail, potentially refreshing counts...");
        _triggerCommunityLoad(); // Refresh counts if needed
      }
    });
  }

  // Navigate to create screen
  void _navigateToCreateCommunity() async {
    // Navigate to the CreateCommunityScreen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );

    // Refresh communities list if community was created
    if (result == true && mounted) {
      _triggerCommunityLoad();
    }
  }

  // Handle join/leave logic using CommunityService
  Future<void> _toggleJoinCommunity(String communityId, bool currentlyJoined) async {
    if (!mounted) return;
    final communityService = Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) { /* Keep existing check */ }

    // Optimistic UI update
    setState(() => _joinedStatusMap[communityId] = !currentlyJoined);

    final action = currentlyJoined ? "leave" : "join";
    try {
      final int id = int.parse(communityId); // Parse ID for service call
      if (currentlyJoined) {
        await communityService.leaveCommunity(id, authProvider.token!);
      } else {
        await communityService.joinCommunity(id, authProvider.token!);
      }
      if (mounted) { print("Successfully ${action}ed community $communityId"); /* Refresh counts? _triggerCommunityLoad(); */ }
    } catch (e) {
      if (mounted) {
        // Revert UI on error
        setState(() => _joinedStatusMap[communityId] = currentlyJoined);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Error trying to $action: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar (Keep existing)
            Padding(
              padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
              child: TextField(
                onChanged: _updateSearchQuery,
                decoration: InputDecoration(
                  hintText: "Search communities...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  isDense: true,
                ),
              ),
            ),

            // Category Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding),
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categoryTabs.length,
                  itemBuilder: (context, index) {
                    final category = _categoryTabs[index];
                    final isSelected = _selectedCategory == category['id'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(category['label'] as String),
                        avatar: Icon(
                          category['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                        selected: isSelected,
                        onSelected: (_) => _selectCategory(category['id'] as String),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? ThemeConstants.backgroundDark
                            : Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade300
                                  : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Sort Options + Joined Toggle - NOW ALIGNED
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Joined Toggle without container background, just the switch
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Joined", style: theme.textTheme.bodySmall),
                      Switch.adaptive(
                        value: _showJoinedOnly,
                        onChanged: (value) {
                          setState(() {
                            _showJoinedOnly = value;
                          });
                          _triggerCommunityLoad();
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),

                  // Sort dropdown on the right
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Sort by:", style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedSortOption,
                        elevation: 4,
                        style: theme.textTheme.bodyMedium,
                        underline: Container(),
                        onChanged: (v) {
                          if (v != null) _selectSortOption(v);
                        },
                        items: _sortOptions
                            .map<DropdownMenuItem<String>>(
                              (o) => DropdownMenuItem<String>(
                                value: o['id'] as String,
                                child: Row(
                                  children: [
                                    Icon(o['icon'] as IconData, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(o['label'] as String),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        isDense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Community Grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _triggerCommunityLoad(),
                child: FutureBuilder<List<dynamic>>(
                  future: _loadCommunitiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !(snapshot.hasData || snapshot.hasError)) {
                      return _buildLoadingShimmer(context);
                    }
                    // Use local error state first
                    if (_error != null) {
                      return _buildErrorUI(_error, isDark);
                    }
                    if (snapshot.hasError) {
                      print("CommunitiesScreen FB Error: ${snapshot.error}");
                      return _buildErrorUI(snapshot.error, isDark);
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyUI(isDark, isSearchOrFilterActive: false);
                    }

                    final List<dynamic> filteredSortedCommunities = _filterAndSortCommunities(snapshot.data!);
                    if (filteredSortedCommunities.isEmpty) {
                      return _buildEmptyUI(isDark, isSearchOrFilterActive: _searchQuery.isNotEmpty || (_selectedCategory != 'all' && _selectedCategory != 'trending'));
                    }

                    // Improve grid responsiveness by using LayoutBuilder
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate grid parameters based on screen width
                        int crossAxisCount = 2; // Default for medium to large screens
                        double childAspectRatio = 0.9; // Slightly taller than before for better content fit

                        // Adjust for very small screens
                        if (constraints.maxWidth < 300) {
                          crossAxisCount = 1; // Single column for very small screens
                          childAspectRatio = 1.2; // Wider card on small screens
                        }

                        return GridView.builder(
                          key: ValueKey('$_selectedCategory-$_selectedSortOption'),
                          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: childAspectRatio,
                            crossAxisSpacing: ThemeConstants.mediumPadding,
                            mainAxisSpacing: ThemeConstants.mediumPadding,
                          ),
                          itemCount: filteredSortedCommunities.length,
                          itemBuilder: (context, index) {
                            final community = filteredSortedCommunities[index] as Map<String, dynamic>;
                            final communityId = community['id'].toString();
                            // --- Use _joinedStatusMap ---
                            final bool isJoined = _joinedStatusMap[communityId] ?? false;
                            // ---------------------------
                            final color = ThemeConstants.communityColors[community['id'].hashCode % ThemeConstants.communityColors.length];

                            return CommunityCard(
                              key: ValueKey(communityId),
                              name: community['name'] ?? 'No Name',
                              description: community['description'] as String?,
                              memberCount: community['member_count'] as int? ?? 0,
                              onlineCount: community['online_count'] as int? ?? 0,
                              logoUrl: community['logo_url'] as String?, // <-- Pass logoUrl
                              backgroundColor: color,
                              isJoined: isJoined,
                              onJoin: () => _toggleJoinCommunity(communityId, isJoined), // Pass callback
                              onTap: () => _navigateToCommunityDetail(community),
                            );
                          },
                        );
                      }
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateCommunity,
        tooltip: "Create Community",
        child: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.secondary, // Changed to secondary color
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }

  // --- Helper Build Methods ---
  Widget _buildLoadingShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    // --- Explicitly return the Shimmer widget ---
    return Shimmer.fromColors( baseColor: baseColor, highlightColor: highlightColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: ThemeConstants.mediumPadding, mainAxisSpacing: ThemeConstants.mediumPadding,),
        itemCount: 8, // Number of shimmer placeholders
        itemBuilder: (_, __) => Container( decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius), ),),
      ),
    );
    // --- End Explicit Return ---
  }

  Widget _buildEmptyUI(bool isDark, {required bool isSearchOrFilterActive}) {
    // --- Explicitly return the LayoutBuilder widget ---
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ThemeConstants.largePadding),
                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon( isSearchOrFilterActive ? Icons.search_off : Icons.forum_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text( isSearchOrFilterActive ? 'No communities match' : 'No communities found', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Text( isSearchOrFilterActive ? 'Try adjusting your search or filter.' : 'Be the first to create one!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700), textAlign: TextAlign.center,),
                    const SizedBox(height: 24),
                    // Ensure CustomButton and ButtonType are imported correctly
                    if (!isSearchOrFilterActive) CustomButton(text: 'Create Community', icon: Icons.add, onPressed: _navigateToCreateCommunity, type: ButtonType.primary),
                  ],),
                ),
              ),
            ),
          );
        }
    );
    // --- End Explicit Return ---
  }

  // Verify this one too, ensure the Center is returned
  Widget _buildErrorUI(Object? error, bool isDark) {
    // --- Explicitly return the Center widget ---
    return Center( child: Padding( padding: const EdgeInsets.all(ThemeConstants.largePadding), child: Column( mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: ThemeConstants.mediumPadding),
      Text('Failed to load communities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: ThemeConstants.smallPadding),
      Text( (error ?? _error ?? 'Unknown error').toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: ThemeConstants.largePadding),
      // Ensure CustomButton and ButtonType are imported correctly
      CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _triggerCommunityLoad, type: ButtonType.secondary),
    ],),),);
    // --- End Explicit Return ---
  }
}
