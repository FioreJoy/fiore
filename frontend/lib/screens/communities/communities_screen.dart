// frontend/lib/screens/communities/communities_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Corrected Service Imports ---
import '../../services/api/community_service.dart';
import '../../services/auth_provider.dart';

// --- Corrected Widget Imports ---
import '../../widgets/community_card.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

// --- Corrected Theme and Constants ---
import '../../theme/theme_constants.dart';

// --- Corrected Navigation Imports ---
import 'create_community_screen.dart';
import 'community_detail_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // State Variables
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSortOption = 'latest';
  Future<List<dynamic>>? _loadCommunitiesFuture;
  String? _error;

  final Map<String, bool> _joinedStatusMap = {};

  // Static Data
  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.new_releases},
    {'id': 'popular', 'label': 'Popular', 'icon': Icons.trending_up},
    {'id': 'active', 'label': 'Active', 'icon': Icons.bolt},
  ];

  final List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.grid_view},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    {'id': 'tech', 'label': 'Tech', 'icon': Icons.devices},
    {'id': 'sports', 'label': 'Sports', 'icon': Icons.sports_soccer},
    {'id': 'music', 'label': 'Music', 'icon': Icons.music_note},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerCommunityLoad();
      }
    });
  }

  Future<void> _triggerCommunityLoad() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      final communityService = Provider.of<CommunityService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (_selectedCategory == 'trending') {
        _loadCommunitiesFuture = communityService.getTrendingCommunities();

      } else {
        _loadCommunitiesFuture = communityService.getCommunities();

      }
    });
  }

  List<dynamic> _filterAndSortCommunities(List<dynamic> communities) {
    var filtered = communities.where((comm) {
      final name = (comm['name'] ?? '').toString().toLowerCase();
      final description = (comm['description'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery) || description.contains(_searchQuery);
    }).toList();

    if (_selectedCategory != 'all' && _selectedCategory != 'trending') {
      final categoryLower = _selectedCategory.toLowerCase();
      filtered = filtered.where((comm) {
        final interest = (comm['interest'] ?? '').toString().toLowerCase();
        return interest == categoryLower;
      }).toList();
    }

    try {
      if (_selectedSortOption == 'popular') {
        filtered.sort((a, b) => (b['member_count'] ?? 0).compareTo(a['member_count'] ?? 0));
      } else if (_selectedSortOption == 'active') {
        filtered.sort((a, b) => (b['online_count'] ?? 0).compareTo(a['online_count'] ?? 0));
      }
    } catch (e) {
      print("Error during sorting: $e");
    }

    return filtered;
  }

  void _updateSearchQuery(String query) {
    if (mounted) setState(() => _searchQuery = query.toLowerCase());
  }

  void _selectCategory(String categoryId) {
    if (!mounted || _selectedCategory == categoryId) return;
    setState(() => _selectedCategory = categoryId);
    _triggerCommunityLoad();
  }

  void _selectSortOption(String sortOptionId) {
    if (!mounted || _selectedSortOption == sortOptionId) return;
    setState(() => _selectedSortOption = sortOptionId);
  }

  void _navigateToCommunityDetail(Map<String, dynamic> communityData) {
    final String communityId = communityData['id'].toString();
    final bool isJoined = _joinedStatusMap[communityId] ?? false;

    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityData: communityData,
          initialIsJoined: isJoined,
          onToggleJoin: _toggleJoinCommunity,
        ),
      ),
    ).then((didStatusChange) {
      if (didStatusChange == true && mounted) {
        _triggerCommunityLoad();
      }
    });
  }

  void _navigateToCreateCommunity() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created == true && mounted) {
      _triggerCommunityLoad();
    }
  }

  Future<void> _toggleJoinCommunity(String communityId, bool currentlyJoined) async {
    if (!mounted) return;
    final communityService = Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in!')),
      );
      return;
    }

    setState(() => _joinedStatusMap[communityId] = !currentlyJoined);

    final action = currentlyJoined ? "leave" : "join";
    try {
      final int id = int.parse(communityId);
      if (currentlyJoined) {
        await communityService.leaveCommunity(id);
      } else {
        await communityService.joinCommunity(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joinedStatusMap[communityId] = currentlyJoined);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error trying to $action: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
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
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryTabs.length,
              padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding),
              itemBuilder: (context, index) {
                final category = _categoryTabs[index];
                final isSelected = _selectedCategory == category['id'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(category['label']),
                    avatar: Icon(
                      category['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : theme.colorScheme.primary,
                    ),
                    selected: isSelected,
                    onSelected: (_) => _selectCategory(category['id']),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: StadiumBorder(
                      side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("Sort by:", style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedSortOption,
                  icon: const Icon(Icons.sort, size: 18),
                  elevation: 4,
                  style: theme.textTheme.bodyMedium,
                  underline: Container(),
                  onChanged: (v) {
                    if (v != null) _selectSortOption(v);
                  },
                  items: _sortOptions.map((o) {
                    return DropdownMenuItem<String>(
                      value: o['id'],
                      child: Row(
                        children: [
                          Icon(o['icon'], size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(o['label']),
                        ],
                      ),
                    );
                  }).toList(),
                  isDense: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _triggerCommunityLoad,
              child: FutureBuilder<List<dynamic>>(
                future: _loadCommunitiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !(snapshot.hasData || snapshot.hasError)) {
                    return _buildLoadingShimmer(context);
                  }
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

                  return GridView.builder(
                    key: ValueKey('$_selectedCategory-$_selectedSortOption'),
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: ThemeConstants.mediumPadding,
                      mainAxisSpacing: ThemeConstants.mediumPadding,
                    ),
                    itemCount: filteredSortedCommunities.length,
                    itemBuilder: (context, index) {
                      final community = filteredSortedCommunities[index];
                      final communityId = community['id'].toString();
                      final bool isJoined = _joinedStatusMap[communityId] ?? false;
                      final color = ThemeConstants.communityColors[community['id'].hashCode % ThemeConstants.communityColors.length];

                      return CommunityCard(
                        key: ValueKey(communityId),
                        name: community['name'] ?? 'No Name',
                        description: community['description'],
                        memberCount: community['member_count'] ?? 0,
                        onlineCount: community['online_count'] ?? 0,
                        logoUrl: community['logo_url'],
                        backgroundColor: color,
                        isJoined: isJoined,
                        onJoin: () => _toggleJoinCommunity(communityId, isJoined),
                        onTap: () => _navigateToCommunityDetail(community),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateCommunity,
        tooltip: "Create Community",
        child: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

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
          childAspectRatio: 0.85,
          crossAxisSpacing: ThemeConstants.mediumPadding,
          mainAxisSpacing: ThemeConstants.mediumPadding,
        ),
        itemCount: 8,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUI(bool isDark, {required bool isSearchOrFilterActive}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConstants.largePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSearchOrFilterActive ? Icons.search_off : Icons.forum_outlined,
                      size: 64,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSearchOrFilterActive ? 'No communities match' : 'No communities found',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSearchOrFilterActive ? 'Try adjusting your search or filter.' : 'Be the first to create one!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (!isSearchOrFilterActive)
                      CustomButton(
                        text: 'Create Community',
                        icon: Icons.add,
                        onPressed: _navigateToCreateCommunity,
                        type: ButtonType.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text(
              'Failed to load communities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(
              (error ?? _error)?.toString() ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
