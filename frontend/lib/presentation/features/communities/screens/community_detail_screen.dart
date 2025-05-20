import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Data Layer (API) ---
// No direct API calls usually made from detail screen after data is passed, but could be needed for refresh
// import '../../../../data/datasources/remote/community_api.dart';

// --- Presentation Layer ---
import '../../../providers/auth_provider.dart';
import '../../../global_widgets/custom_button.dart';

// --- Core ---
import '../../../../core/theme/theme_constants.dart';
import '../../../../../app_constants.dart'; // For AppConstants.appName if used

// --- Screen Imports ---
import 'community_members_screen.dart'; // Sibling screen
import '../../chat/screens/chat_screen.dart'; // Navigation to chat screen

// --- Models (if needed, e.g. for specific LocationPoint display) ---
// import '../../../../data/models/event_model.dart'; // Example, if showing events

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> communityData;
  final bool initialIsJoined;
  final Future<Map<String, dynamic>> Function(
      String communityId, bool currentlyJoined) onToggleJoin;

  const CommunityDetailScreen({
    Key? key,
    required this.communityData,
    required this.initialIsJoined,
    required this.onToggleJoin,
  }) : super(key: key);

  @override
  _CommunityDetailScreenState createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late bool _isJoined;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _isJoined = widget.initialIsJoined;
    _animController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinToggle() async {
    /* ... same as before, ensure any service calls use correct Provider path ... */
    if (_isActionLoading || !mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please log in to join or leave communities.')));
      return;
    }
    setState(() => _isActionLoading = true);
    final bool intendedToJoin = !_isJoined;
    try {
      final result = await widget.onToggleJoin(
          widget.communityData['id'].toString(), _isJoined);
      if (mounted && result['statusChanged'] == true) {
        setState(() {
          _isJoined = result['isJoined'] ?? intendedToJoin;
        });
      } else if (mounted && result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Action failed: ${result['error']}'),
            backgroundColor: ThemeConstants.errorColor));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: ThemeConstants.errorColor));
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _navigateToChat() {
    final int communityId = widget.communityData['id'] as int;
    final String communityName = widget.communityData['name'] ?? 'Community';
    // If ChatScreen is not directly managed by tabs, it might take context
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatScreen(
              communityId: communityId,
              communityName: communityName,
            )));
  }

  void _navigateToMembersScreen() {
    final String communityId = widget.communityData['id'].toString();
    final String communityName = widget.communityData['name'] ?? 'Community';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityMembersScreen(
          communityId: communityId,
          communityName: communityName,
        ),
      ),
    );
  }

  void _navigateToCreateEvent() {
    /* ... same as before, no new imports needed here yet ... */
    final String communityId = widget.communityData['id'].toString();
    final String communityName = widget.communityData['name'] ?? 'Community';
    // This should navigate to presentation/features/events/screens/create_event_screen.dart eventually
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Placeholder: Navigate to Create Event for "$communityName" (ID: $communityId)'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI, largely unchanged, uses theme and local state ... */
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    final color = communityColors[
        widget.communityData['id'].hashCode % communityColors.length];
    final String name = widget.communityData['name'] ?? 'Unnamed Community';
    final String description =
        widget.communityData['description'] ?? 'No description available.';
    final int memberCount = widget.communityData['member_count'] as int? ?? 0;
    final int onlineCount = widget.communityData['online_count'] as int? ?? 0;
    final String? locationAddress =
        widget.communityData['location_address'] as String?;
    final Map<String, dynamic>? locationPoint =
        widget.communityData['location'] is Map
            ? widget.communityData['location']
            : null;
    String displayLocation = 'Location not set';
    if (locationAddress != null && locationAddress.isNotEmpty)
      displayLocation = locationAddress;
    else if (locationPoint != null &&
        locationPoint['longitude'] != null &&
        locationPoint['latitude'] != null) {
      final lon = (locationPoint['longitude'] as num).toStringAsFixed(3);
      final lat = (locationPoint['latitude'] as num).toStringAsFixed(3);
      if (lon != '0.000' || lat != '0.000')
        displayLocation = 'Coordinates: ($lon, $lat)';
    }
    final String interest = widget.communityData['interest'] ?? 'General';
    final String? logoUrl = widget.communityData['logo_url'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: ThemeConstants.mediumPadding, vertical: 40),
              constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
              decoration: BoxDecoration(
                color: isDark ? ThemeConstants.backgroundDark : Colors.white,
                borderRadius: BorderRadius.circular(
                    ThemeConstants.cardBorderRadius * 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 3)
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 140,
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      color.withOpacity(0.7),
                      color.withOpacity(0.95)
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Stack(children: [
                      Row(children: [
                        Hero(
                          tag: 'community_logo_${widget.communityData['id']}',
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: logoUrl != null &&
                                    logoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(logoUrl)
                                : const NetworkImage(AppConstants.defaultAvatar)
                                    as ImageProvider,
                            child: logoUrl == null || logoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 38,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Text(name,
                                style: theme.primaryTextTheme.headlineSmall
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                      Shadow(
                                          blurRadius: 2,
                                          color: Colors.black.withOpacity(0.5))
                                    ]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 28),
                            tooltip: "Close Details",
                            onPressed: () => Navigator.of(context)
                                .pop({'statusChanged': false}),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(ThemeConstants.mediumPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(
                                  ThemeConstants.smallPadding + 2),
                              decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(
                                      ThemeConstants.cardBorderRadius - 4)),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(context,
                                        icon: Icons.people_alt_outlined,
                                        label: 'Members',
                                        value: memberCount.toString(),
                                        color: color,
                                        isDark: isDark,
                                        onTap: _navigateToMembersScreen),
                                    _buildDivider(isDark),
                                    _buildStatItem(context,
                                        icon: Icons.online_prediction_rounded,
                                        label: 'Online',
                                        value: onlineCount.toString(),
                                        color: Colors.greenAccent.shade400,
                                        isDark: isDark),
                                    _buildDivider(isDark),
                                    _buildStatItem(context,
                                        icon: Icons.category_rounded,
                                        label: 'Category',
                                        value: interest,
                                        color: color,
                                        isDark: isDark),
                                  ])),
                          const SizedBox(
                              height: ThemeConstants.mediumPadding + 4),
                          if (displayLocation != 'Location not set')
                            Padding(
                                padding: const EdgeInsets.only(
                                    bottom: ThemeConstants.smallPadding),
                                child: Row(children: [
                                  Icon(Icons.location_on_outlined,
                                      color: color.withOpacity(0.8), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(displayLocation,
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade700,
                                              fontSize: 13))),
                                ])),
                          Text('About this community',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: ThemeConstants.smallPadding),
                          Text(description,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800,
                                  fontSize: 14.5,
                                  height: 1.45)),
                          const SizedBox(height: ThemeConstants.largePadding),
                          if (_isJoined && authProvider.isAuthenticated)
                            Center(
                              child: CustomButton(
                                text: 'Create Event Here',
                                icon: Icons.add_location_alt_outlined,
                                onPressed: _navigateToCreateEvent,
                                type: ButtonType.outline,
                              ),
                            ),
                          const SizedBox(height: ThemeConstants.largePadding),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    decoration: BoxDecoration(
                        color: isDark
                            ? ThemeConstants.backgroundDark.withOpacity(0.7)
                            : Colors.grey.shade50.withOpacity(0.9),
                        border: Border(
                            top: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                width: 0.8))),
                    child: Row(children: [
                      Expanded(
                          child: CustomButton(
                        text: _isJoined ? 'Leave Community' : 'Join Community',
                        onPressed: _handleJoinToggle,
                        isLoading: _isActionLoading,
                        type: _isJoined
                            ? ButtonType.secondary
                            : ButtonType.primary,
                        backgroundColor: _isJoined
                            ? (isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300)
                            : color,
                        foregroundColor: _isJoined
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.white,
                        icon: _isJoined
                            ? Icons.exit_to_app_rounded
                            : Icons.group_add_rounded,
                      )),
                      const SizedBox(width: ThemeConstants.mediumPadding),
                      Expanded(
                          child: CustomButton(
                        text: 'Go to Chat',
                        onPressed: _navigateToChat,
                        icon: Icons.chat_bubble_outline_rounded,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        foregroundColor:
                            isDark ? Colors.white70 : Colors.black87,
                        type: ButtonType.outline,
                      )),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required Color color,
      required bool isDark,
      VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withOpacity(0.9), size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
        height: 45,
        width: 1,
        color: isDark
            ? Colors.grey.shade700.withOpacity(0.5)
            : Colors.grey.shade300.withOpacity(0.7));
  }
}
