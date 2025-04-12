// lib/screens/community_detail_screen.dart
import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';
import '../widgets/custom_button.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> community;
  final bool initialIsJoined;
  final Function(String communityId, bool currentlyJoined) onToggleJoin; // Callback

  const CommunityDetailScreen({
    Key? key,
    required this.community,
    required this.initialIsJoined,
    required this.onToggleJoin,
  }) : super(key: key);

  @override
  _CommunityDetailScreenState createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> with SingleTickerProviderStateMixin {
  late bool _isJoined; // Local state for immediate UI feedback
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _isJoined = widget.initialIsJoined;
    
    // Animation setup for a nice pop-in effect
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    
    _animController.forward();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleJoinToggle() {
    // Update local state immediately
    setState(() {
      _isJoined = !_isJoined;
    });
    // Call the actual logic passed from the parent screen
    widget.onToggleJoin(widget.community['id'].toString(), !_isJoined); // Pass the *previous* state
  }

  void _navigateToChat() {
    // Navigate to ChatroomScreen with this community pre-selected
    final int communityId = widget.community['id'] as int;
    
    // First close the detail modal
    Navigator.of(context).pop();
    
    // Navigate to the chat tab on the main screen
    // Find the MainNavigationScreen and call its _onNavItemTapped method to switch to chat tab
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Using a callback to execute after returning to the main navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Find the main navigation screen
      final ctx = Navigator.of(context);
      
      // Try to access main navigation state and switch to chat tab (index 2)
      if (ctx.canPop()) {
        // This assumes we're on the main tab navigation screen
        (ctx.widget as dynamic)._onNavItemTapped?.call(2);
        
        // Also need to set the selected community in the ChatroomScreen
        // For this, we could use a global event bus or a provider pattern
        
        // For now, we'll use a simpler approach: add a callback to load this community's chat
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Find the ChatroomScreen and set the community
          final apiService = Provider.of<ApiService>(context, listen: false);
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          
          // This is a simplified approach - in a real app, you would use a more robust
          // state management solution to communicate between screens
          // Here we're simulating transitioning to the chat tab and loading this community
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening chat for ${widget.community['name']}'),
              duration: Duration(seconds: 2),
            ),
          );
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityColors = ThemeConstants.communityColors;
    final color = communityColors[widget.community['id'].hashCode % communityColors.length];

    // Safely extract data with defaults
    final String name = widget.community['name'] ?? 'Unnamed Community';
    final String description = widget.community['description'] ?? 'No description available.';
    final int memberCount = widget.community['member_count'] as int? ?? 0;
    final int onlineCount = widget.community['online_count'] as int? ?? 0;
    final String? location = widget.community['primary_location']?.toString();
    final String communityId = widget.community['id'].toString(); // Ensure ID is string
    final String interest = widget.community['interest'] ?? 'General';

    return Scaffold(
      backgroundColor: Colors.transparent, // Needed for the overlay effect
      body: GestureDetector(
        // Allows tapping the background overlay to dismiss
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.7), // Darker overlay for better contrast
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                // Prevents taps inside the card from dismissing
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: ThemeConstants.mediumPadding, vertical: 50),
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(
                    color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
                    borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius * 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with gradient background and community initial
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withOpacity(0.8),
                              color,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decorative elements
                            Positioned(
                              right: -30,
                              top: -30,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -20,
                              bottom: -20,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            
                            // Community name and initial
                            Padding(
                              padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                              child: Row(
                                children: [
                                  // Community initial circle
                                  Hero(
                                    tag: 'community_${widget.community['id']}',
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.2),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 3.0,
                                            color: Color.fromARGB(255, 0, 0, 0),
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Row (Members, Online, Category)
                              Container(
                                padding: const EdgeInsets.all(ThemeConstants.smallPadding),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? Colors.black.withOpacity(0.2) 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      context,
                                      icon: Icons.people_outline,
                                      label: 'Members',
                                      value: memberCount.toString(),
                                      color: color,
                                      isDark: isDark,
                                    ),
                                    _buildDivider(isDark),
                                    _buildStatItem(
                                      context,
                                      icon: Icons.online_prediction,
                                      label: 'Online',
                                      value: onlineCount.toString(),
                                      color: Colors.green,
                                      isDark: isDark,
                                    ),
                                    _buildDivider(isDark),
                                    _buildStatItem(
                                      context,
                                      icon: Icons.category_outlined,
                                      label: 'Category',
                                      value: interest,
                                      color: color,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: ThemeConstants.mediumPadding),
                              
                              // Location if available
                              if (location != null && location.isNotEmpty) 
                                Padding(
                                  padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined, 
                                        color: color,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Location: $location',
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Description
                              Text(
                                'About this community',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: ThemeConstants.smallPadding),
                              Text(
                                description,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                  fontSize: 15,
                                  height: 1.4,
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
                        decoration: BoxDecoration(
                          color: isDark 
                              ? ThemeConstants.backgroundDark.withOpacity(0.5)
                              : Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(
                              color: isDark 
                                  ? Colors.grey.shade800 
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Join/Leave Button
                            Expanded(
                              child: CustomButton(
                                text: _isJoined ? 'Leave' : 'Join',
                                onPressed: _handleJoinToggle,
                                type: _isJoined ? ButtonType.secondary : ButtonType.primary,
                                icon: _isJoined ? Icons.logout : Icons.person_add_alt_1,
                              ),
                            ),
                            const SizedBox(width: ThemeConstants.mediumPadding),
                            // Go to Chat Button
                            Expanded(
                              child: CustomButton(
                                text: 'Go to Chat',
                                onPressed: _navigateToChat,
                                //type: ButtonType.accent,
                                icon: Icons.chat_bubble_outline,
                              ),
                            ),
                          ],
                        ),
                      ),
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
  
  // Helper widget for statistics items
  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  // Vertical divider between stats
  Widget _buildDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
    );
  }

  // Helper widget for info chips (Members, Online, Location) - keeping for reference but not using
  Widget _buildInfoChip(BuildContext context, {required IconData icon, required String text, Color? iconColor, required bool isDark}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800.withOpacity(0.7) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20), // Make them pill-shaped
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              fontWeight: FontWeight.w500
            ),
          ),
        ],
      ),
    );
  }
}