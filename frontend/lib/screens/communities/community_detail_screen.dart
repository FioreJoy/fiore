// frontend/lib/screens/communities/community_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Needed for accessing services
import 'package:cached_network_image/cached_network_image.dart'; // For logo

// --- Updated Service Imports ---
// No direct service calls might be needed here if onToggleJoin is handled by parent,
// BUT if you add features like "Fetch Posts for this Community", you'll need services.
// import '../../services/api/post_service.dart';
// import '../../services/api/event_service.dart';
import '../../services/auth_provider.dart'; // To check if user is logged in

// --- Widget Imports ---
import '../../widgets/custom_button.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
// For default images if needed

// --- Navigation Imports ---
// Import ChatScreen if navigating directly to it
// import '../chat/chat_screen.dart';


class CommunityDetailScreen extends StatefulWidget {
  // Expect the full community data map and initial join status
  final Map<String, dynamic> communityData;
  final bool initialIsJoined;
  // Callback provided by the parent screen (CommunitiesScreen) to handle the actual API call
  final Function(String communityId, bool currentlyJoined) onToggleJoin;

  const CommunityDetailScreen({
    super.key,
    required this.communityData,
    required this.initialIsJoined,
    required this.onToggleJoin,
  });

  @override
  _CommunityDetailScreenState createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> with SingleTickerProviderStateMixin {
  late bool _isJoined; // Local state for immediate UI feedback on the button
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isJoined = widget.initialIsJoined; // Initialize local state

    // Animation setup
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400), // Slightly longer animation
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut, // Bouncier effect
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Handles button tap, updates local state, calls parent callback
  void _handleJoinToggle() {
    // Check if user is logged in before allowing action
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join or leave communities.')),
      );
      return;
    }

    // Update local state first for optimistic UI
    setState(() {
      _isJoined = !_isJoined;
    });
    // Trigger the actual API call via the callback passed from CommunitiesScreen
    widget.onToggleJoin(widget.communityData['id'].toString(), !_isJoined); // Pass previous state
  }

  // Navigate to the chat screen for this specific community
  void _navigateToChat() {
    final int communityId = widget.communityData['id'] as int;
    final String communityName = widget.communityData['name'] ?? 'Community';

    // 1. Close this detail modal/dialog first, potentially passing back info
    Navigator.of(context).pop();

    // 2. Navigate or switch to the Chat tab/screen and tell it which community to load.
    // This is the tricky part without a global state manager or direct reference.
    // Option A: Using a callback/Provider (Complex to set up here)
    // Option B: Assume ChatScreen is reachable via root navigator and can handle arguments (less ideal)
    // Option C: Use a dedicated state management solution (Riverpod, Bloc)

    // For now, let's just print and show a snackbar, assuming the user manually switches
    // to the Chat tab and selects the community from the drawer.
    // A better implementation would use a state management solution.
    print("Requesting navigation to chat for Community ID: $communityId");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening chat... Please select "$communityName" from the community list in the Chat tab.'),
        duration: const Duration(seconds: 4),
      ),
    );
    // Example using named routes IF ChatScreen can handle arguments:
    // Navigator.pushNamed(context, '/chat', arguments: {'communityId': communityId});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const communityColors = ThemeConstants.communityColors;
    final color = communityColors[widget.communityData['id'].hashCode % communityColors.length];

    // Safely extract data with defaults
    final String name = widget.communityData['name'] ?? 'Unnamed Community';
    final String description = widget.communityData['description'] ?? 'No description available.';
    final int memberCount = widget.communityData['member_count'] as int? ?? 0;
    final int onlineCount = widget.communityData['online_count'] as int? ?? 0;
    final String? location = widget.communityData['primary_location']?.toString(); // Assuming it's a string '(lon,lat)'
    // final String communityId = widget.communityData['id'].toString(); // Already available in widget.communityData['id']
    final String interest = widget.communityData['interest'] ?? 'General';
    final String? logoUrl = widget.communityData['logo_url']; // Use the URL field

    return Scaffold(
      backgroundColor: Colors.transparent, // For overlay effect
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(true), // Pop and indicate interaction happened
        child: Container(
          color: Colors.black.withOpacity(0.65), // Overlay dimming
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector( // Prevent taps inside card from dismissing
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 60), // Adjust margins
                  constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650), // Max size
                  decoration: BoxDecoration(
                    color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                    borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius * 1.5),
                    boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2, ), ],
                  ),
                  clipBehavior: Clip.antiAlias, // Clip content to rounded corners
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Fit content height
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Header Section ---
                      Container(
                        height: 130, // Increased height
                        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient( colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight,),
                          // Optional: Add subtle pattern or image if logoUrl is missing?
                        ),
                        child: Row( children: [
                          Hero( // Animate avatar from community list
                            tag: 'community_logo_${widget.communityData['id']}', // Use unique tag
                            child: CircleAvatar(
                              radius: 40, // Adjusted size
                              backgroundColor: Colors.white.withOpacity(0.3),
                              backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(logoUrl)
                                  : null, // Use CachedNetworkImageProvider
                              child: logoUrl == null || logoUrl.isEmpty
                                  ? Text( name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded( child: Text( name, style: theme.primaryTextTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.5))]), maxLines: 2, overflow: TextOverflow.ellipsis,),),
                        ],),
                      ),
                      // --- End Header ---

                      // --- Content Section ---
                      Flexible( // Allow content to scroll if it exceeds space
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Row
                              Container( padding: const EdgeInsets.all(ThemeConstants.smallPadding),
                                decoration: BoxDecoration( color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade100, borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),),
                                child: Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                  _buildStatItem( context, icon: Icons.people_outline, label: 'Members', value: memberCount.toString(), color: color, isDark: isDark,),
                                  _buildDivider(isDark),
                                  _buildStatItem( context, icon: Icons.online_prediction, label: 'Online', value: onlineCount.toString(), color: Colors.green, isDark: isDark,),
                                  _buildDivider(isDark),
                                  _buildStatItem( context, icon: Icons.category_outlined, label: 'Category', value: interest, color: color, isDark: isDark,),
                                ],),),
                              const SizedBox(height: ThemeConstants.mediumPadding),
                              // Location
                              if (location != null && location.isNotEmpty && location != '(0,0)') // Show only if valid location
                                Padding( padding: const EdgeInsets.only(bottom: ThemeConstants.smallPadding), child: Row( children: [ Icon( Icons.location_on_outlined, color: color, size: 18,), const SizedBox(width: 8), Expanded( child: Text( 'Location: $location', style: TextStyle( color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13,),),),],),),
                              // Description
                              Text( 'About this community', style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: color, ),),
                              const SizedBox(height: ThemeConstants.smallPadding),
                              Text( description, style: TextStyle( color: isDark ? Colors.grey.shade300 : Colors.grey.shade800, fontSize: 15, height: 1.4,),),
                              const SizedBox(height: ThemeConstants.largePadding),
                              // TODO: Add placeholder for Community Posts / Events List here?
                              // This would require fetching data using PostService/EventService
                            ],
                          ),
                        ),
                      ),
                      // --- End Content ---

                      // --- Action Buttons ---
                      Container( padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                        decoration: BoxDecoration( color: isDark ? ThemeConstants.backgroundDark.withOpacity(0.5) : Colors.grey.shade50, border: Border( top: BorderSide( color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,),),),
                        child: Row( children: [
                          // Join/Leave Button
                          Expanded( child: CustomButton(
                            text: _isJoined ? 'Leave Community' : 'Join Community',
                            onPressed: _handleJoinToggle, // Uses local state + callback
                            type: _isJoined ? ButtonType.secondary : ButtonType.primary, // Style depends on state
                            icon: _isJoined ? Icons.logout : Icons.person_add_alt_1,
                          ),),
                          const SizedBox(width: ThemeConstants.mediumPadding),
                          // Go to Chat Button
                          Expanded( child: CustomButton( text: 'Go to Chat', onPressed: _navigateToChat, icon: Icons.chat_bubble_outline, ),),
                        ],),),
                      // --- End Actions ---
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for statistics items (Keep as is)
  Widget _buildStatItem(BuildContext context, { required IconData icon, required String label, required String value, required Color color, required bool isDark, }) { /* ... Keep original ... */ return Column( children: [ Icon(icon, color: color, size: 22), const SizedBox(height: 4), Text( value, style: TextStyle( fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87,),), Text( label, style: TextStyle( fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,),),],); }
  // Vertical divider between stats (Keep as is)
  Widget _buildDivider(bool isDark) { /* ... Keep original ... */ return Container( height: 40, width: 1, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,);}

} // End of _CommunityDetailScreenState