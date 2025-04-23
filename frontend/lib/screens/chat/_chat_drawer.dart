// frontend/lib/screens/chat/_chat_drawer.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For logos

import '../../theme/theme_constants.dart';
import '../../app_constants.dart'; // For default avatar if needed for community

class ChatDrawer extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> communities;
  final int? selectedCommunityId;
  final int? selectedEventId; // To know if community or event is selected
  final Function(int) onCommunitySelected; // Callback when a community is tapped
  final String? error;

  const ChatDrawer({
    Key? key,
    required this.isLoading,
    required this.communities,
    required this.selectedCommunityId,
    required this.selectedEventId,
    required this.onCommunitySelected,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.8),
              // You can add a background image or gradient here
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Select Community',
                style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? _buildErrorView(context, error!) // Show error if loading failed
                    : communities.isEmpty
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No communities joined yet. Find or create one!', textAlign: TextAlign.center),
                          ))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: communities.length,
                            itemBuilder: (context, index) {
                              final community = communities[index];
                              final communityIdInt = community['id'] as int;
                              // Community is selected if its ID matches AND no event is selected
                              final isSelected = (selectedCommunityId == communityIdInt && selectedEventId == null);
                              final String? logoUrl = community['logo_url'] as String?; // Cast safely

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20, // Slightly smaller avatar in drawer
                                  backgroundColor: isSelected
                                      ? ThemeConstants.accentColor.withOpacity(0.2)
                                      : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200),
                                  backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(logoUrl)
                                      : null,
                                  child: (logoUrl == null || logoUrl.isEmpty)
                                      ? Text(
                                          (community['name'] as String?)?.isNotEmpty == true ? (community['name'] as String)[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            color: isSelected ? ThemeConstants.accentColor : null,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  community['name'] as String? ?? 'Unnamed Community',
                                  style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                selected: isSelected,
                                selectedTileColor: ThemeConstants.accentColor.withOpacity(0.1),
                                onTap: () => onCommunitySelected(communityIdInt), // Call callback
                                // Optionally add online count or other info as subtitle
                                // subtitle: Text("${community['online_count'] ?? 0} online"),
                              );
                            },
                          ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: ThemeConstants.accentColor),
            title: const Text('Manage Communities'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // TODO: Implement navigation to the main Communities screen
              // Example: Use Navigator.pushNamed or find the MainNavigationScreen's state
              // to switch tabs if appropriate.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to Manage Communities Screen...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String errorMsg) {
     return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
           const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48), const SizedBox(height: 16),
           Text('Error Loading Communities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
           Text( errorMsg.replaceFirst("Exception: ",""), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 16),
           // Optional: Add a retry button? Requires passing a retry callback.
           // TextButton(onPressed: onRetry, child: Text("Retry"))
       ],),),);
   }
}
