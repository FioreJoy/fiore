// frontend/lib/screens/communities/communities_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// --- Service Imports ---
import '../../services/api/community_service.dart';
import '../../services/auth_provider.dart';
// **** ADD THIS IMPORT ****
import '../../services/api/user_service.dart';
// *************************

// --- Widget Imports ---
import '../../widgets/community_card.dart';
// import '../../widgets/custom_card.dart'; // Not used in latest version? Remove if unused
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
// import '../../app_constants.dart'; // Not used directly here

// --- Navigation Imports ---
import 'create_community_screen.dart';
import 'community_detail_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // State Variables
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSortOption = 'latest';
  Future<List<dynamic>>? _loadCommunitiesFuture;
  String? _error;
  final Map<String, bool> _membershipStatusMap = {};
  bool _fetchedInitialMembership = false;

  // --- Static Data for UI ---
  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'latest', 'label': 'Latest', 'icon': Icons.access_time},
    {'id': 'popular', 'label': 'Members', 'icon': Icons.people_alt},
    {'id': 'active', 'label': 'Online', 'icon': Icons.online_prediction},
  ];
  final List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'All', 'icon': Icons.public},
    {'id': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
    {'id': 'joined', 'label': 'Joined', 'icon': Icons.group_work},
    {'id': 'gaming', 'label': 'Gaming', 'icon': Icons.sports_esports},
    {'id': 'tech', 'label': 'Tech', 'icon': Icons.code},
    {'id': 'science', 'label': 'Science', 'icon': Icons.science},
    {'id': 'music', 'label': 'Music', 'icon': Icons.music_note},
    {'id': 'sports', 'label': 'Sports', 'icon': Icons.sports},
    {'id': 'college', 'label': 'College', 'icon': Icons.school},
    {'id': 'activities', 'label': 'Activities', 'icon': Icons.hiking},
    {'id': 'social', 'label': 'Social', 'icon': Icons.people},
    {'id': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchInitialMembershipStatus().then((_) {
          if(mounted) _refreshCommunities();
        });
      }
    });
  }

  // --- Data Loading & Filtering ---
  Future<void> _fetchInitialMembershipStatus() async {
    if (!mounted || _fetchedInitialMembership) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      setState(() => _fetchedInitialMembership = true); return;
    }
    print("CommunitiesScreen: Fetching initial membership status...");
    // *** Uses UserService now ***
    final userService = Provider.of<UserService>(context, listen: false);
    try {
      final joinedCommunities = await userService.getMyJoinedCommunities(authProvider.token!);
      if (mounted) {
        final Map<String, bool> newStatusMap = {};
        for (var comm in joinedCommunities) {
          if (comm is Map<String, dynamic> && comm['id'] != null) newStatusMap[comm['id'].toString()] = true;
        }
        setState(() { _membershipStatusMap.clear(); _membershipStatusMap.addAll(newStatusMap); _fetchedInitialMembership = true; });
        print("CommunitiesScreen: Initial membership loaded for ${_membershipStatusMap.length} communities.");
      }
    } catch (e) { print("CommunitiesScreen: Error fetching initial membership: $e"); if (mounted) setState(() => _fetchedInitialMembership = true); }
  }

  Future<void> _refreshCommunities() async {
    if (!mounted) return;
    setState(() { _error = null; _loadCommunitiesFuture = _fetchCommunitiesData(); });
  }

  Future<List<dynamic>> _fetchCommunitiesData() async {
    if (!mounted) return [];
    if (!_fetchedInitialMembership) { await _fetchInitialMembershipStatus(); if (!mounted) return []; }
    final communityService = Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (_selectedCategory == 'trending') { return await communityService.getTrendingCommunities(token: authProvider.token); }
      else if (_selectedCategory == 'joined') {
        if (!authProvider.isAuthenticated) return [];
        // *** Uses UserService now ***
        final userService = Provider.of<UserService>(context, listen: false);
        return await userService.getMyJoinedCommunities(authProvider.token!);
      }
      else { return await communityService.getCommunities(token: authProvider.token); }
    } catch (e) { if (mounted) setState(() { _error = "Failed to load: ${e.toString().replaceFirst("Exception: ", "")}"; }); throw e; }
  }

  List<dynamic> _filterAndSortCommunities(List<dynamic> communities) {
    // ... (Keep existing filtering/sorting logic - no changes needed here) ...
    List<dynamic> filtered = communities;
    if (_selectedCategory != 'all' && _selectedCategory != 'trending' && _selectedCategory != 'joined') {
      final categoryLower = _selectedCategory.toLowerCase();
      final normalizedCategory = categoryLower.contains('college') ? 'college event' : categoryLower;
      filtered = filtered.where((comm) => (comm['interest'] ?? '').toString().toLowerCase() == normalizedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((comm) {
        final name = (comm['name'] ?? '').toString().toLowerCase();
        final desc = (comm['description'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }
    try {
      if (_selectedSortOption == 'popular') { filtered.sort((a, b) => (b['member_count'] ?? 0).compareTo(a['member_count'] ?? 0)); }
      else if (_selectedSortOption == 'active') { filtered.sort((a, b) => (b['online_count'] ?? 0).compareTo(a['online_count'] ?? 0)); }
    } catch (e) { print("Error sorting communities: $e."); }
    return filtered;
  }

  // --- UI Actions ---
  void _updateSearchQuery(String query) { if (mounted) setState(() => _searchQuery = query.toLowerCase()); }
  void _selectCategory(String categoryId) { if (!mounted || _selectedCategory == categoryId) return; setState(() => _selectedCategory = categoryId); _refreshCommunities(); }
  void _selectSortOption(String sortOptionId) { if (!mounted || _selectedSortOption == sortOptionId) return; setState(() => _selectedSortOption = sortOptionId); }

  void _navigateToCommunityDetail(Map<String, dynamic> communityData) {
    final String communityId = communityData['id'].toString();
    final bool isJoined = _membershipStatusMap[communityId] ?? false;
    Navigator.of(context).push<Map<String, dynamic>>( MaterialPageRoute( builder: (_) => CommunityDetailScreen( communityData: communityData, initialIsJoined: isJoined, onToggleJoin: _handleToggleJoin, ),),
    ).then((result) {
      if (result != null && result['statusChanged'] == true && mounted) {
        final String returnedId = result['id']?.toString() ?? '';
        final bool newJoinedStatus = result['isJoined'] ?? false;
        setState(() => _membershipStatusMap[returnedId] = newJoinedStatus);
        _refreshCommunities(); // Refresh to get updated counts from backend
      }
    });
  }

  void _navigateToCreateCommunity() async {
    final result = await Navigator.of(context).push<bool>( MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),);
    if (result == true && mounted) { _refreshCommunities(); }
  }

  Future<Map<String, dynamic>> _handleToggleJoin(String communityId, bool currentlyJoined) async {
    // Mark async return type
    if (!mounted) return {'statusChanged': false, 'id': communityId, 'isJoined': currentlyJoined}; // Return map on early exit
    final communityService = Provider.of<CommunityService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Please log in.')));
      return {'statusChanged': false, 'id': communityId, 'isJoined': currentlyJoined}; // Return map
    }
    setState(() => _membershipStatusMap[communityId] = !currentlyJoined); // Optimistic update
    final action = currentlyJoined ? "leave" : "join";
    try {
      final int idInt = int.parse(communityId);
      Map<String, dynamic> response;
      if (currentlyJoined) { response = await communityService.leaveCommunity(idInt, authProvider.token!); }
      else { response = await communityService.joinCommunity(idInt, authProvider.token!); }
      if (mounted) print("Successfully ${action}ed community $communityId.");
      // Return successful result map
      return {'statusChanged': true, 'id': communityId, 'isJoined': !currentlyJoined, 'response': response};
    } catch (e) {
      if (mounted) {
        setState(() => _membershipStatusMap[communityId] = currentlyJoined); // Revert
        ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Error trying to $action: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: ThemeConstants.errorColor));
      }
      // Return error result map
      return {'statusChanged': false, 'id': communityId, 'isJoined': currentlyJoined, 'error': e.toString()};
    }
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    // ... (super.build, theme setup) ...
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea( child: Column( children: [
        Padding( padding: const EdgeInsets.all(16), child: TextField( onChanged: _updateSearchQuery, decoration: InputDecoration( hintText: "Search communities...", prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100, border: OutlineInputBorder( borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none,), contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20), isDense: true,),),),
        Padding( padding: const EdgeInsets.symmetric(horizontal: 8), child: SizedBox( height: 50, child: ListView.builder( scrollDirection: Axis.horizontal, itemCount: _categoryTabs.length, itemBuilder: (context, index) { final category = _categoryTabs[index]; final isSelected = _selectedCategory == category['id']; return Padding( padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip( label: Text(category['label']), avatar: Icon(category['icon'], size: 16, color: isSelected?Colors.white:theme.colorScheme.primary), selected: isSelected, onSelected: (_) => _selectCategory(category['id']), selectedColor: theme.colorScheme.primary, backgroundColor: isDark?ThemeConstants.backgroundDark:Colors.white, labelStyle: TextStyle(fontSize: 13, color: isSelected?Colors.white:(isDark?Colors.grey.shade300:Colors.black87), fontWeight:isSelected?FontWeight.bold:FontWeight.normal), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: StadiumBorder(side: BorderSide(color: isDark?Colors.grey.shade700:Colors.grey.shade300)))); },),),),
        Padding( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row( mainAxisAlignment: MainAxisAlignment.end, // Align sort to right
            children: [ Text("Sort by:", style: theme.textTheme.bodySmall), const SizedBox(width: 8), DropdownButton<String>( value: _selectedSortOption, elevation: 4, style: theme.textTheme.bodyMedium, underline: Container(), onChanged: (v) { if (v != null) _selectSortOption(v); }, items: _sortOptions.map<DropdownMenuItem<String>>( (o) => DropdownMenuItem<String>( value: o['id'], child: Row( children: [ Icon(o['icon'], size: 16, color: Colors.grey.shade600), const SizedBox(width: 6), Text(o['label']) ]))).toList(), isDense: true)])),
        Expanded( child: RefreshIndicator( onRefresh: () async => _refreshCommunities(), child: FutureBuilder<List<dynamic>>( future: _loadCommunitiesFuture, builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_fetchedInitialMembership) { return const Center(child: CircularProgressIndicator()); }
          if (snapshot.connectionState == ConnectionState.waiting && (snapshot.data == null || snapshot.data!.isEmpty)) { return _buildLoadingShimmer(context); }
          if (_error != null) { return _buildErrorUI(_error, isDark); }
          if (snapshot.hasError) { return _buildErrorUI(snapshot.error, isDark); }
          if (!snapshot.hasData && !_fetchedInitialMembership) { return const Center(child: CircularProgressIndicator()); } // Still waiting for initial join status
          if (!snapshot.hasData || snapshot.data!.isEmpty) { return _buildEmptyUI(isDark, isSearchOrFilterActive: _searchQuery.isNotEmpty || (_selectedCategory != 'all' && _selectedCategory != 'joined')); }
          final List<dynamic> filteredSortedCommunities = _filterAndSortCommunities(snapshot.data!);
          if (filteredSortedCommunities.isEmpty) { return _buildEmptyUI(isDark, isSearchOrFilterActive: true); }
          return LayoutBuilder( builder: (context, constraints) { int crossAxisCount = (constraints.maxWidth / 200).floor().clamp(1, 4); double childAspectRatio = constraints.maxWidth < 350 ? 1.0 : 0.85; return GridView.builder( key: ValueKey('$_selectedCategory-$_selectedSortOption'), padding: const EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: crossAxisCount, childAspectRatio: childAspectRatio, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: filteredSortedCommunities.length, itemBuilder: (context, index) { final community = filteredSortedCommunities[index] as Map<String, dynamic>; final communityId = community['id'].toString(); final bool isJoined = _membershipStatusMap[communityId] ?? false; final color = ThemeConstants.communityColors[community['id'].hashCode % ThemeConstants.communityColors.length]; return CommunityCard( key: ValueKey(communityId), name: community['name'] ?? 'No Name', description: community['description'] as String?, memberCount: community['member_count'] ?? 0, onlineCount: community['online_count'] ?? 0, logoUrl: community['logo_url'] as String?, backgroundColor: color, isJoined: isJoined, onJoin: () async { await _handleToggleJoin(communityId, isJoined); }, onTap: () => _navigateToCommunityDetail(community)); }); }); },),),),
      ])),
      floatingActionButton: FloatingActionButton( onPressed: _navigateToCreateCommunity, tooltip: "Create Community", child: const Icon(Icons.add)),
    );
  }

  // --- Helper Build Methods ---
  Widget _buildLoadingShimmer(BuildContext context) { /* ... keep identical ... */ final isDark=Theme.of(context).brightness==Brightness.dark; final base=isDark?Colors.grey[800]!:Colors.grey[300]!; final high=isDark?Colors.grey[700]!:Colors.grey[100]!; return Shimmer.fromColors(baseColor:base, highlightColor:high, child: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: 8, itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))); }
  Widget _buildEmptyUI(bool isDark, {required bool isSearchOrFilterActive}) { /* ... keep identical, REMOVE padding arg from CustomButton ... */ return LayoutBuilder(builder: (ctx, cons) => SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: cons.maxHeight), child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(isSearchOrFilterActive ? Icons.search_off : Icons.forum_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400), const SizedBox(height: 16), Text(isSearchOrFilterActive ? 'No communities match' : 'No communities found', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)), const SizedBox(height: 8), Text(isSearchOrFilterActive ? 'Try adjusting your search or filter.' : 'Explore or create a new one!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700), textAlign: TextAlign.center), const SizedBox(height: 24), if (!isSearchOrFilterActive) CustomButton(text: 'Create Community', icon: Icons.add, onPressed: _navigateToCreateCommunity, type: ButtonType.primary)])))))); }
  Widget _buildErrorUI(Object? error, bool isDark) { /* ... keep identical, REMOVE padding arg from CustomButton ... */ return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.error_outline, color: ThemeConstants.errorColor, size: 48), const SizedBox(height: 16), Text('Failed to load communities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text((error ?? _error ?? 'Unknown error').toString().replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 24), CustomButton(text: 'Retry', icon: Icons.refresh, onPressed: _refreshCommunities, type: ButtonType.secondary)]))); }

}