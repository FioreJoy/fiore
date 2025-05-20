import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Data Layer Imports ---
import '../../../../data/datasources/remote/community_api.dart'; // For CommunityApiService
import '../../../../data/datasources/remote/user_api.dart'; // For UserApiService

// --- Presentation Layer Imports ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/community_card.dart';
import '../../../global_widgets/custom_button.dart';

// --- Core Imports ---
import '../../../../core/theme/theme_constants.dart';

// --- Screen Imports ---
import 'create_community_screen.dart'; // Sibling screen
import 'community_detail_screen.dart'; // Sibling screen

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSortOption = 'latest';
  Future<List<dynamic>>? _loadCommunitiesFuture;
  String? _error;

  List<dynamic> _communities = [];
  bool _isLoadingMore = false;
  bool _canLoadMore = true;
  int _currentPage = 0;
  final int _limit = 18;

  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'Discover', 'icon': Icons.explore_outlined},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up_rounded},
    {'id': 'joined', 'label': 'Joined', 'icon': Icons.group_work_outlined},
    {
      'id': 'my_hubs',
      'label': 'My Hubs',
      'icon': Icons.dashboard_customize_outlined
    },
  ];
  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.new_releases_outlined},
    {'id': 'popular', 'label': 'Members', 'icon': Icons.people_alt_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCommunities(isInitialLoad: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _canLoadMore) _fetchCommunitiesData(isPaginating: true);
  }

  Future<void> _refreshCommunities({bool isInitialLoad = false}) async {
    if (!mounted) return;
    _currentPage = 0;
    if (isInitialLoad || _communities.isEmpty) _communities.clear();
    _canLoadMore = true;
    setState(() {
      _error = null;
      _loadCommunitiesFuture = _fetchCommunitiesData(isInitialLoad: true);
    });
  }

  Future<List<dynamic>> _fetchCommunitiesData(
      {bool isInitialLoad = false, bool isPaginating = false}) async {
    if (!mounted ||
        (isPaginating && _isLoadingMore) ||
        (!isPaginating && !isInitialLoad && _isLoadingMore))
      return _communities;
    final communityService =
        Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    if (isPaginating)
      setState(() => _isLoadingMore = true);
    else if (isInitialLoad) _isLoadingMore = false;
    List<dynamic> fetched = [];
    try {
      final currentOffset = isInitialLoad ? 0 : _currentPage * _limit;
      if (isInitialLoad) _currentPage = 0;
      switch (_selectedCategory) {
        case 'trending':
          fetched = await communityService.getTrendingCommunities(
              token: authProvider.token);
          if (currentOffset == 0) _communities.clear();
          _canLoadMore = false;
          break;
        case 'joined':
          if (!authProvider.isAuthenticated || authProvider.token == null) {
            if (mounted)
              setState(() {
                _error = "Log in to see joined communities.";
                _isLoadingMore = false;
                _canLoadMore = false;
              });
            break;
          }
          fetched =
              await userService.getMyJoinedCommunities(authProvider.token!);
          if (currentOffset == 0) _communities.clear();
          _canLoadMore = false;
          break;
        case 'my_hubs':
          if (!authProvider.isAuthenticated ||
              authProvider.token == null ||
              authProvider.userId == null) {
            if (mounted)
              setState(() {
                _error = "Log in to see your hubs.";
                _isLoadingMore = false;
                _canLoadMore = false;
              });
            break;
          }
          final allCommunities =
              await communityService.getCommunities(token: authProvider.token);
          fetched = allCommunities
              .where((c) => c['created_by']?.toString() == authProvider.userId)
              .toList();
          if (currentOffset == 0) _communities.clear();
          _canLoadMore = false;
          break;
        default:
          if (currentOffset == 0) {
            fetched = await communityService.getCommunities(
                token: authProvider.token);
            _canLoadMore = fetched.length >= _limit;
          } else {
            fetched = [];
            _canLoadMore = false;
          }
          break;
      }
      if (!mounted) return [];
      if (fetched.length < _limit && (_selectedCategory == 'all'))
        _canLoadMore = false;
      if (isInitialLoad || currentOffset == 0)
        _communities = List<dynamic>.from(fetched);
      else {
        final existingIds = _communities.map((c) => c['id']).toSet();
        _communities
            .addAll(fetched.where((c) => !existingIds.contains(c['id'])));
      }
      if (_selectedCategory == 'all' && fetched.isNotEmpty) _currentPage++;
      _error = null;
    } catch (e) {
      if (mounted) {
        _error =
            "Failed to load: ${e.toString().replaceFirst("Exception: ", "")}";
        _canLoadMore = false;
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
    return _communities;
  }

  List<dynamic> _filterAndSortInMemory(List<dynamic> communities) {
    /* ... unchanged ... */ final displayList = List.from(communities);
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      displayList.retainWhere((comm) {
        final name = (comm['name'] ?? '').toString().toLowerCase();
        final desc = (comm['description'] ?? '').toString().toLowerCase();
        return name.contains(queryLower) || desc.contains(queryLower);
      });
    }
    try {
      if (_selectedSortOption == 'popular')
        displayList.sort((a, b) =>
            (b['member_count'] ?? 0).compareTo(a['member_count'] ?? 0));
      else
        displayList.sort((a, b) {
          DateTime timeA =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
          DateTime timeB =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
          return timeB.compareTo(timeA);
        });
    } catch (e) {/* Log e */}
    return displayList;
  }

  void _updateSearchQuery(String query) {
    if (mounted) setState(() => _searchQuery = query);
  }

  void _selectCategory(String categoryId) {
    if (!mounted || _selectedCategory == categoryId) return;
    setState(() => _selectedCategory = categoryId);
    _refreshCommunities(isInitialLoad: true);
  }

  void _selectSortOption(String sortOptionId) {
    if (!mounted || _selectedSortOption == sortOptionId) return;
    setState(() => _selectedSortOption = sortOptionId);
  }

  void _navigateToCommunityDetail(Map<String, dynamic> communityData) {
    final String communityId = communityData['id'].toString();
    final currentCommunityData = _communities.firstWhere(
        (c) => c['id'].toString() == communityId,
        orElse: () => communityData);
    final bool isJoined = currentCommunityData['is_member_by_viewer'] ?? false;
    Navigator.of(context)
        .push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          communityData: communityData,
          initialIsJoined: isJoined,
          onToggleJoin: _handleToggleJoin,
        ),
      ),
    )
        .then((result) {
      if (result != null && result['statusChanged'] == true && mounted)
        _refreshCommunities(isInitialLoad: true);
    });
  }

  Future<Map<String, dynamic>> _handleToggleJoin(
      String communityId, bool currentlyJoined) async {
    if (!mounted)
      return {
        'statusChanged': false,
        'id': communityId,
        'isJoined': currentlyJoined
      };
    final communityService =
        Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in.')));
      return {
        'statusChanged': false,
        'id': communityId,
        'isJoined': currentlyJoined
      };
    }
    final action = currentlyJoined ? "leave" : "join";
    try {
      final int idInt = int.parse(communityId);
      Map<String, dynamic> response;
      if (currentlyJoined) {
        response =
            await communityService.leaveCommunity(idInt, authProvider.token!);
      } else {
        response =
            await communityService.joinCommunity(idInt, authProvider.token!);
      }
      if (mounted) {
        final index =
            _communities.indexWhere((c) => c['id'].toString() == communityId);
        if (index != -1) {
          Map<String, dynamic> updatedCommunity = Map.from(_communities[index]);
          updatedCommunity['is_member_by_viewer'] = !currentlyJoined;
          if (response['new_counts'] != null &&
              response['new_counts']['member_count'] != null)
            updatedCommunity['member_count'] =
                response['new_counts']['member_count'];
          setState(() => _communities[index] = updatedCommunity);
        } else
          _refreshCommunities(isInitialLoad: true);
      }
      return {
        'statusChanged': true,
        'id': communityId,
        'isJoined': !currentlyJoined,
        'response': response
      };
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error trying to $action: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: ThemeConstants.errorColor));
      return {
        'statusChanged': false,
        'id': communityId,
        'isJoined': currentlyJoined,
        'error': e.toString()
      };
    }
  }

  void _navigateToCreateCommunity() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (result == true && mounted) _refreshCommunities(isInitialLoad: true);
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI building, largely unchanged, use local _build* methods for brevity ... */
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _loadCommunitiesFuture ??= _fetchCommunitiesData(isInitialLoad: true);
    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _updateSearchQuery,
            decoration: InputDecoration(
              hintText: "Search communities...",
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark
                  ? ThemeConstants.backgroundDarker
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryTabs.length,
              itemBuilder: (context, index) {
                final category = _categoryTabs[index];
                final isSelected = _selectedCategory == category['id'];
                final bool isEnabled = !((category['id'] == 'joined' ||
                        category['id'] == 'my_hubs') &&
                    !authProvider.isAuthenticated);
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                        label: Text(category['label']),
                        avatar: Icon(category['icon'],
                            size: 16,
                            color: isEnabled
                                ? (isSelected
                                    ? Colors.white
                                    : theme.colorScheme.primary)
                                : Colors.grey.shade500),
                        selected: isSelected,
                        onSelected: isEnabled
                            ? (_) => _selectCategory(category['id'])
                            : null,
                        selectedColor: isEnabled
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        backgroundColor: isEnabled
                            ? (isDark
                                ? ThemeConstants.backgroundDark
                                : Colors.white)
                            : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                        labelStyle: TextStyle(
                            fontSize: 13,
                            color: isEnabled
                                ? (isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.grey.shade300
                                        : Colors.black87))
                                : Colors.grey.shade600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: StadiumBorder(
                            side: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300))));
              },
            ),
          ),
        ),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text("Sort by:", style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                      value: _selectedSortOption,
                      elevation: 4,
                      style: theme.textTheme.bodyMedium,
                      icon: Icon(Icons.sort_rounded,
                          size: 20,
                          color: theme.iconTheme.color?.withOpacity(0.7)),
                      onChanged: (v) {
                        if (v != null) _selectSortOption(v);
                      },
                      items: _sortOptions
                          .map<DropdownMenuItem<String>>(
                              (o) => DropdownMenuItem<String>(
                                  value: o['id'],
                                  child: Row(children: [
                                    Icon(o['icon'],
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(o['label'])
                                  ])))
                          .toList(),
                      isDense: true))
            ])),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshCommunities(isInitialLoad: true),
            child: FutureBuilder<List<dynamic>>(
              future: _loadCommunitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _communities.isEmpty) return _buildLoadingShimmer(context);
                if (_error != null && _communities.isEmpty)
                  return _buildErrorUI(_error, isDark);
                if (snapshot.hasError && _communities.isEmpty && _error == null)
                  return _buildErrorUI(snapshot.error, isDark);
                final List<dynamic> communitiesToDisplay =
                    _filterAndSortInMemory(_communities);
                if (communitiesToDisplay.isEmpty)
                  return _buildEmptyUI(isDark,
                      isSearchOrFilterActive: _searchQuery.isNotEmpty ||
                          (_selectedCategory != 'all'));
                return LayoutBuilder(builder: (context, constraints) {
                  int crossAxisCount =
                      (constraints.maxWidth / 200).floor().clamp(1, 4);
                  double childAspectRatio =
                      constraints.maxWidth < 350 ? 1.0 : 0.85;
                  return GridView.builder(
                      key: ValueKey(
                          '$_selectedCategory-$_selectedSortOption-$_searchQuery'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16),
                      itemCount: communitiesToDisplay.length +
                          (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == communitiesToDisplay.length &&
                            _isLoadingMore)
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)));
                        if (index >= communitiesToDisplay.length)
                          return const SizedBox.shrink();
                        final community =
                            communitiesToDisplay[index] as Map<String, dynamic>;
                        final communityId = community['id'].toString();
                        final bool isJoined =
                            community['is_member_by_viewer'] ?? false;
                        final color = ThemeConstants.communityColors[
                            community['id'].hashCode %
                                ThemeConstants.communityColors.length];
                        return CommunityCard(
                            key: ValueKey(communityId),
                            name: community['name'] ?? 'No Name',
                            description: community['description'] as String?,
                            memberCount: community['member_count'] ?? 0,
                            onlineCount: community['online_count'] ?? 0,
                            logoUrl: community['logo_url'] as String?,
                            backgroundColor: color,
                            isJoined: isJoined,
                            onJoin: () async =>
                                _handleToggleJoin(communityId, isJoined),
                            onTap: () => _navigateToCommunityDetail(community));
                      });
                });
              },
            ),
          ),
        ),
      ])),
      floatingActionButton: FloatingActionButton(
          onPressed: _navigateToCreateCommunity,
          tooltip: "Create Community",
          child: const Icon(Icons.add_circle_outline_rounded)),
    );
  }

  Widget _buildLoadingShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final high = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return Shimmer.fromColors(
        baseColor: base,
        highlightColor: high,
        child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16),
            itemCount: 8,
            itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)))));
  }

  Widget _buildEmptyUI(bool isDark, {required bool isSearchOrFilterActive}) {
    /* ... (no path changes) ... */ return LayoutBuilder(
        builder: (ctx, cons) => SingleChildScrollView(
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: cons.maxHeight),
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  isSearchOrFilterActive
                                      ? Icons.search_off_rounded
                                      : Icons.forum_outlined,
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                  isSearchOrFilterActive
                                      ? 'No communities match'
                                      : 'No communities yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text(
                                  isSearchOrFilterActive
                                      ? 'Try adjusting your search or filter.'
                                      : 'Explore or create a new one!',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade700),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              CustomButton(
                                  text: 'Create Community',
                                  icon: Icons.add,
                                  onPressed: _navigateToCreateCommunity,
                                  type: ButtonType.outline)
                            ]))))));
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    /* ... (no path changes) ... */ return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  color: ThemeConstants.errorColor, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load communities',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  (error ?? _error ?? 'Unknown error')
                      .toString()
                      .replaceFirst("Exception: ", ""),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              CustomButton(
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _refreshCommunities(isInitialLoad: true),
                  type: ButtonType.secondary)
            ])));
  }
}
