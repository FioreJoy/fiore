import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For community logos

import '../../../../core/theme/theme_constants.dart';
import '../../../../app_constants.dart'; // For default avatar/icon for communities without logo

class ChatDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> userCommunities;
  final String currentRoomType;
  final int currentRoomId;
  final Function(String newRoomType, int newRoomId, String newRoomName)
      switchToRoom;
  final bool isDark;

  const ChatDrawer({
    Key? key,
    required this.userCommunities,
    required this.currentRoomType,
    required this.currentRoomId,
    required this.switchToRoom,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.8)),
            child: Text(
              'Switch Chat Room',
              style: Theme.of(context)
                  .primaryTextTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
          ),
          Expanded(
            child: userCommunities.isEmpty
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Join communities to chat.')))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: userCommunities.length,
                    itemBuilder: (context, index) {
                      final community = userCommunities[index];
                      final communityIdInt =
                          community['id'] as int? ?? 0; // Ensure ID is int
                      final communityNameStr =
                          community['name'] as String? ?? 'Community';
                      final bool isSelected = (currentRoomType == 'community' &&
                          currentRoomId == communityIdInt);
                      final String? logoUrl = community['logo_url'] as String?;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isSelected
                              ? ThemeConstants.accentColor.withOpacity(0.2)
                              : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200),
                          backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                              ? CachedNetworkImageProvider(logoUrl)
                              : null,
                          child: (logoUrl == null || logoUrl.isEmpty) &&
                                  communityNameStr.isNotEmpty
                              ? Text(
                                  communityNameStr[0].toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? ThemeConstants.accentColor
                                        : null,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          communityNameStr,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                                isSelected ? ThemeConstants.accentColor : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor:
                            ThemeConstants.accentColor.withOpacity(0.05),
                        onTap: () => switchToRoom(
                            'community', communityIdInt, communityNameStr),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
