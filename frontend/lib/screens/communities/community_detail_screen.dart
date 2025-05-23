// frontend/lib/screens/communities/community_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Service Imports ---
import '../../services/auth_provider.dart';
// import '../../services/api/community_service.dart'; // Not strictly needed if all data passed

// --- Widget Imports ---
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';

// --- Navigation Import ---
import 'community_members_screen.dart'; // To navigate to the members list

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> communityData;
  final bool initialIsJoined;
  final Function(String communityId, bool currentlyJoined) onToggleJoin;

  const CommunityDetailScreen({
    Key? key,
    required this.communityData,
    required this.initialIsJoined,
    required this.onToggleJoin,
  }) : super(key: key);

  @override
  _CommunityDetailScreenState createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> with SingleTickerProviderStateMixin {
  late bool _isJoined;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isActionLoading = false; // For join/leave button loading state

  @override
  void initState() {
    super.initState();
    _isJoined = widget.initialIsJoined;
    _animController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this); // Slightly faster
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinToggle() async {
    if (_isActionLoading || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to join or leave communities.')));
      return;
    }

    setState(() => _isActionLoading = true);
    final bool intendedToJoin = !_isJoined; // The action user wants to perform

    try {
      // Call the parent's onToggleJoin which handles API and state update
      final result = await widget.onToggleJoin(widget.communityData['id'].toString(), _isJoined);

      if (mounted && result['statusChanged'] == true) {
        setState(() {
          _isJoined = result['isJoined'] ?? intendedToJoin; // Update local state from callback result
        });
        // Success message handled by the parent screen's onToggleJoin if needed
      } else if (mounted && result['error'] != null) {
        // If onToggleJoin reported an error, show it
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Action failed: ${result['error']}'),
            backgroundColor: ThemeConstants.errorColor));
      }
    } catch (e) { // Catch any unexpected errors during the call
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: ThemeConstants.errorColor));
      }
    }
    finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }


  void _navigateToChat() {
    final int communityId = widget.communityData['id'] as int;
    final String communityName = widget.communityData['name'] ?? 'Community';

    // Pop this detail screen, then instruct parent to navigate or update tab
    // This result can be caught by the .then() in CommunitiesScreen
    Navigator.of(context).pop({'navigateToChatFor': communityId, 'communityName': communityName});
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

  // --- NEW: Navigate to Create Event Screen (Placeholder for now) ---
  void _navigateToCreateEvent() {
    final String communityId = widget.communityData['id'].toString();
    final String communityName = widget.communityData['name'] ?? 'Community';
    // TODO: Implement navigation to an actual CreateEventScreen
    // For now, just a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Placeholder: Navigate to Create Event for "$communityName" (ID: $communityId)'),
    ));
    print("Navigate to create event for community ID: $communityId");
  }
  // --- END NEW ---


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    final color = communityColors[widget.communityData['id'].hashCode % communityColors.length];

    final String name = widget.communityData['name'] ?? 'Unnamed Community';
    final String description = widget.communityData['description'] ?? 'No description available.';
    final int memberCount = widget.communityData['member_count'] as int? ?? 0;
    final int onlineCount = widget.communityData['online_count'] as int? ?? 0;
    // Location processing:
    // Backend schema returns location_address (text) and location (Point with lon/lat)
    final String? locationAddress = widget.communityData['location_address'] as String?;
    final Map<String, dynamic>? locationPoint = widget.communityData['location'] is Map ? widget.communityData['location'] : null;
    String displayLocation = 'Location not set';
    if (locationAddress != null && locationAddress.isNotEmpty) {
      displayLocation = locationAddress;
    } else if (locationPoint != null && locationPoint['longitude'] != null && locationPoint['latitude'] != null) {
      final lon = (locationPoint['longitude'] as num).toStringAsFixed(3);
      final lat = (locationPoint['latitude'] as num).toStringAsFixed(3);
      if (lon != '0.000' || lat != '0.000') { // Avoid showing (0,0) if it's default
        displayLocation = 'Coordinates: ($lon, $lat)';
      }
    }

    final String interest = widget.communityData['interest'] ?? 'General';
    final String? logoUrl = widget.communityData['logo_url'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75), // Dimmed background
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: () {}, // Prevent taps on the card from closing the modal immediately
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 40), // Adjusted vertical margin
              constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650), // Max height
              decoration: BoxDecoration(
                color: isDark ? ThemeConstants.backgroundDark : Colors.white,
                borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius * 1.5),
                boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.4), blurRadius: 25, spreadRadius: 3)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min, // Make column take minimum space needed
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section (Logo, Name, Close Button)
                  Container(
                    height: 140, // Increased height for better visual
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color.withOpacity(0.7), color.withOpacity(0.95)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Stack(
                      children: [
                        Row(children: [
                          Hero(tag: 'community_logo_${widget.communityData['id']}',
                            child: CircleAvatar(radius: 42, backgroundColor: Colors.white.withOpacity(0.3),
                              backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? CachedNetworkImageProvider(logoUrl) : null,
                              child: logoUrl == null || logoUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold)) : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(name, style: theme.primaryTextTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.5))]), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                        // Close button
                        Positioned(
                          top: -4, right: -4,
                          child: Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                              tooltip: "Close Details",
                              onPressed: () => Navigator.of(context).pop({'statusChanged': false}), // Pass a result indicating no join status change
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Section (Scrollable)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(ThemeConstants.smallPadding + 2),
                            decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade100, borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius - 4)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _buildStatItem(context, icon: Icons.people_alt_outlined, label: 'Members', value: memberCount.toString(), color: color, isDark: isDark, onTap: _navigateToMembersScreen), // <-- ADDED onTap
                              _buildDivider(isDark),
                              _buildStatItem(context, icon: Icons.online_prediction_rounded, label: 'Online', value: onlineCount.toString(), color: Colors.greenAccent.shade400, isDark: isDark),
                              _buildDivider(isDark),
                              _buildStatItem(context, icon: Icons.category_rounded, label: 'Category', value: interest, color: color, isDark: isDark),
                            ]),
                          ),
                          const SizedBox(height: ThemeConstants.mediumPadding + 4),
                          if (displayLocation != 'Location not set')
                            Padding(padding: const EdgeInsets.only(bottom: ThemeConstants.smallPadding), child: Row(children: [
                              Icon(Icons.location_on_outlined, color: color.withOpacity(0.8), size: 18), const SizedBox(width: 8),
                              Expanded(child: Text(displayLocation, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13))),
                            ])),
                          Text('About this community', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: ThemeConstants.smallPadding),
                          Text(description, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade800, fontSize: 14.5, height: 1.45)),
                          const SizedBox(height: ThemeConstants.largePadding),
                          // Placeholder for "Create Event" button if user is a member/admin
                          if (_isJoined && authProvider.isAuthenticated) // Only show if joined
                            Center(
                              child: CustomButton(
                                text: 'Create Event Here',
                                icon: Icons.add_location_alt_outlined,
                                onPressed: _navigateToCreateEvent,
                                type: ButtonType.outline,
                                // backgroundColor: color.withOpacity(0.15),
                                // foregroundColor: color,
                              ),
                            ),
                          const SizedBox(height: ThemeConstants.largePadding),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    decoration: BoxDecoration(color: isDark ? ThemeConstants.backgroundDark.withOpacity(0.7) : Colors.grey.shade50.withOpacity(0.9), border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.8))),
                    child: Row(children: [
                      Expanded(child: CustomButton(
                        text: _isJoined ? 'Leave Community' : 'Join Community',
                        onPressed: _handleJoinToggle,
                        isLoading: _isActionLoading,
                        type: _isJoined ? ButtonType.secondary : ButtonType.primary,
                        backgroundColor: _isJoined ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300) : color,
                        foregroundColor: _isJoined ? (isDark ? Colors.white : Colors.black87) : Colors.white,
                        icon: _isJoined ? Icons.exit_to_app_rounded : Icons.group_add_rounded,
                      )),
                      const SizedBox(width: ThemeConstants.mediumPadding),
                      Expanded(child: CustomButton(
                        text: 'Go to Chat',
                        onPressed: _navigateToChat,
                        icon: Icons.chat_bubble_outline_rounded,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        type: ButtonType.outline, // Make it look less prominent
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

  Widget _buildStatItem(BuildContext context, {required IconData icon, required String label, required String value, required Color color, required bool isDark, VoidCallback? onTap}) {
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
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(height: 45, width: 1, color: isDark ? Colors.grey.shade700.withOpacity(0.5) : Colors.grey.shade300.withOpacity(0.7));
  }
}