import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/community_card.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../theme/theme_constants.dart';
import 'create_community_screen.dart';

  Widget _buildLoadingShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: ThemeConstants.mediumPadding,
          mainAxisSpacing: ThemeConstants.mediumPadding,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
          ),
        ),
      ),
    );
  }

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  final Map<String, bool> _joinedCommunities = {};
  String? _selectedCategory;
  Future<List<dynamic>>? _loadCommunitiesFuture;

  final List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.public},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    {'id': 'gaming', 'label': 'Gaming', 'icon': Icons.sports_esports},
    {'id': 'tech', 'label': 'Tech', 'icon': Icons.code},
    {'id': 'music', 'label': 'Music', 'icon': Icons.music_note},
    {'id': 'art', 'label': 'Art', 'icon': Icons.palette},
  ];

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure Provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
         _triggerCommunityLoad();
       }
    });
  }
  // --- Helper Build Methods ---
   Widget _buildEmptyUI(bool isDark, {bool isSearchOrFilterActive = false}) {
      return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.people_outline, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
             const SizedBox(height: 16),
             Text('No communities found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
             const SizedBox(height: 8),
             Text(
               isSearchOrFilterActive
                   ? 'Try adjusting your search or filter.'
                   : 'Start by creating a new community!',
               style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 24),
             if (!isSearchOrFilterActive)
               CustomButton(text: 'Create Community', icon: Icons.add, onPressed: () => _navigateToCreateCommunity(), type: ButtonType.primary),
           ],
         ),
      );
   }
  Widget _buildErrorUI(Object? error) {
     return Center(
        child: CustomCard(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48),
                const SizedBox(height: ThemeConstants.smallPadding),
                Text('Error: ${error.toString()}'), // Display error
                const SizedBox(height: ThemeConstants.mediumPadding),
                CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _triggerCommunityLoad, type: ButtonType.primary),
              ],
            ),
          ),
        ),
     );
   }
  void _triggerCommunityLoad() {
    if (!mounted) return;
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Use setState to update the future, triggering FutureBuilder rebuild
    setState(() {
       if (_selectedCategory == 'trending') {
          _loadCommunitiesFuture = apiService.fetchTrendingCommunities(authProvider.token);
       } else {
          _loadCommunitiesFuture = apiService.fetchCommunities(authProvider.token);
       }
    });
  }

  void _updateSearchQuery(String query) {
    if (mounted) {
      setState(() { _searchQuery = query.toLowerCase(); });
    }
  }

  void _navigateToCreateCommunity() async {
     if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a community.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateCommunityScreen()),
    );
    if (mounted) _triggerCommunityLoad(); // Refresh list after returning
  }

 Future<void> _toggleJoinCommunity(String communityId, bool isJoined, ApiService apiService, AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated || !mounted) return;

    setState(() { _joinedCommunities[communityId] = !isJoined; });

    try {
      if (isJoined) {
        await apiService.leaveCommunity(communityId, authProvider.token!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You left the community'), duration: Duration(seconds: 1)));
      } else {
        await apiService.joinCommunity(communityId, authProvider.token!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You joined the community'), duration: Duration(seconds: 1)));
      }
      if (mounted) _triggerCommunityLoad(); // Refresh counts
    } catch (e) {
      if (!mounted) return;
      setState(() { _joinedCommunities[communityId] = isJoined; }); // Revert
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: ThemeConstants.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;

    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
           child: TextField(
              onChanged: _updateSearchQuery,
              decoration: InputDecoration(
                hintText: "Search communities...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? ThemeConstants.backgroundDarker
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),

          // Category tabs
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryTabs.length,
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding),
              itemBuilder: (context, index) {
                final category = _categoryTabs[index];
                final isSelected = _selectedCategory == category['id'];
                return GestureDetector( // Correct nesting
                  onTap: () {
                    if (!mounted) return;
                    final newCategory = isSelected ? null : category['id'] as String?;
                    if (_selectedCategory != newCategory) {
                       setState(() { _selectedCategory = newCategory; });
                       _triggerCommunityLoad();
                    }
                  },
                  child: Padding( // Padding is the child of GestureDetector
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        // Circle Avatar
                        AnimatedContainer(
                          duration: ThemeConstants.shortAnimation,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThemeConstants.primaryColor
                                : (isDark ? ThemeConstants.backgroundDark : Colors.grey.shade200),
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: ThemeConstants.primaryColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                                : null,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            category['icon'] as IconData,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        Text(
                          category['label'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? ThemeConstants.primaryColor
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Community grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _triggerCommunityLoad(),
              child: FutureBuilder<List<dynamic>>(
                future: _loadCommunitiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingShimmer(context);
                  }
                  if (snapshot.hasError) {
                    return _buildErrorUI(snapshot.error); // Use helper for error UI
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyUI(isDark); // Use helper for empty UI
                  }

                  // Client-side filtering
                  var communities = snapshot.data!.where((comm) {
                    // ... filtering logic ...
                     final name = (comm['name'] ?? '').toString().toLowerCase();
                     final description = (comm['description'] ?? '').toString().toLowerCase();
                     final interest = (comm['interest'] ?? '').toString().toLowerCase();
                     final matchesSearch = name.contains(_searchQuery) || description.contains(_searchQuery);

                     if (_selectedCategory != null && _selectedCategory != 'all' && _selectedCategory != 'trending') {
                       final categoryName = _selectedCategory!.toLowerCase();
                       final matchesCategory = interest == categoryName || name.contains(categoryName);
                       return matchesSearch && matchesCategory;
                     }
                     return matchesSearch;
                  }).toList();

                  if (communities.isEmpty) {
                     return _buildEmptyUI(isDark, isSearchOrFilterActive: _searchQuery.isNotEmpty || (_selectedCategory != null && _selectedCategory != 'all'));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( // Correct parameters
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: ThemeConstants.mediumPadding,
                      mainAxisSpacing: ThemeConstants.mediumPadding,
                    ),
                    itemCount: communities.length,
                    itemBuilder: (context, index) {
                      final community = communities[index];
                      final communityId = community['id'].toString();
                      final isJoined = _joinedCommunities[communityId] ?? false;
                      final color = communityColors[index % communityColors.length];
                      final onlineCount = community['online_count'] ?? 0;
                      final memberCount = community['member_count'] ?? 0;

                      return CommunityCard(
                        name: community['name'] ?? 'No Name',
                        description: community['description'],
                        memberCount: memberCount,
                        onlineCount: onlineCount,
                        backgroundColor: color,
                        location: community['primary_location']?.toString(),
                        isJoined: isJoined,
                        onJoin: () => _toggleJoinCommunity(communityId, isJoined, apiService, authProvider),
                        onTap: () { /* Navigate */ },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // Correct FloatingActionButton assignment
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateCommunity(),
        tooltip: "Create Community",
        child: const Icon(Icons.add),
      ),
    );





}
}