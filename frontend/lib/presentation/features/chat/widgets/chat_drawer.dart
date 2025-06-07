// frontend/lib/presentation/features/chat/widgets/chat_drawer.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/theme_constants.dart';
import '../../../../app_constants.dart'; // For default avatar

class ChatDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> userCommunities;
  final List<Map<String, dynamic>> directMessageContacts; // New parameter
  final String currentRoomType;
  final int currentRoomId;
  final Function(
      String newRoomType,
      int newRoomId, // communityId, eventId, or dmRecipientId if newRoomType is 'dm'
      String newRoomName, {
      int? dmRecipientId, // Specifically for DM type
      String? dmRecipientName, // Specifically for DM type
      String? dmRecipientAvatar, // Specifically for DM type
      }) switchToRoom;
  final bool isDark;

  const ChatDrawer({
    Key? key,
    required this.userCommunities,
    required this.directMessageContacts, // New
    required this.currentRoomType,
    required this.currentRoomId,
    required this.switchToRoom,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.9),
              // Possible gradient like in the chat list item, for consistency
              // gradient: LinearGradient(
              //   colors: [theme.primaryColor.withOpacity(0.8), theme.primaryColor.withOpacity(0.95)],
              //   begin: Alignment.topLeft,
              //   end: Alignment.bottomRight,
              // ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Switch Chat',
                  style: theme.primaryTextTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Communities & Direct Messages',
                  style: theme.primaryTextTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading:
            Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
            title: Text("Community Channels", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withOpacity(0.5)),
          Expanded(
            flex: 2, // Give communities more space initially
            child: userCommunities.isEmpty
                ? const _EmptyRoomPlaceholder(
                message: 'Join some communities to start chatting.')
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: userCommunities.length,
              itemBuilder: (context, index) {
                final community = userCommunities[index];
                final communityIdInt = community['id'] as int? ?? 0;
                final communityNameStr = community['name'] as String? ?? 'Community';
                final bool isSelected = (currentRoomType == 'community' && currentRoomId == communityIdInt);
                final String? logoUrl = community['logo_url'] as String?;

                return _buildRoomItem(
                  context,
                  isSelected: isSelected,
                  iconData: Icons.group_work_outlined,
                  avatarUrl: logoUrl,
                  title: communityNameStr,
                  fallbackAvatarLetter: communityNameStr.isNotEmpty ? communityNameStr[0] : 'C',
                  onTap: () => switchToRoom(
                      'community', communityIdInt, communityNameStr),
                );
              },
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withOpacity(0.5)),
          ListTile(
            leading:
            Icon(Icons.person_outline, color: theme.colorScheme.secondary),
            title: Text("Direct Messages", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withOpacity(0.5)),
          Expanded(
            flex: 3, // Give DMs potentially more space, or adjust as needed
            child: directMessageContacts.isEmpty
                ? const _EmptyRoomPlaceholder(message: 'Follow users to start a direct message.')
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: directMessageContacts.length,
              itemBuilder: (context, index) {
                final contact = directMessageContacts[index];
                final contactId = contact['id'] as int? ?? 0;
                final contactName = contact['name'] as String? ?? 'User';
                final contactUsername = contact['username'] as String?;
                final avatarUrl = contact['avatar_url'] as String?;
                // For DMs, currentRoomId is the recipient's ID.
                final bool isSelected = (currentRoomType == 'dm' && currentRoomId == contactId);

                return _buildRoomItem(
                  context,
                  isSelected: isSelected,
                  iconData: Icons.person_outline,
                  avatarUrl: avatarUrl,
                  title: contactName,
                  subtitle: contactUsername != null ? "@$contactUsername" : null,
                  fallbackAvatarLetter: contactName.isNotEmpty ? contactName[0] : 'U',
                  onTap: () => switchToRoom(
                    'dm',
                    contactId, // This will be used as _currentRoomId if DM is chosen
                    contactName,
                    dmRecipientId: contactId,
                    dmRecipientName: contactName,
                    dmRecipientAvatar: avatarUrl,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomItem(
      BuildContext context, {
        required bool isSelected,
        required IconData iconData,
        required String title,
        String? subtitle,
        String? avatarUrl,
        required String fallbackAvatarLetter,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final Color selectedColor = theme.colorScheme.primary;
    final Color unselectedColor = isDark
        ? Colors.grey.shade400
        : theme.textTheme.bodyLarge?.color ?? Colors.black87;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
        isSelected ? selectedColor.withOpacity(0.15) : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty) && fallbackAvatarLetter.isNotEmpty
            ? Text(
          fallbackAvatarLetter.toUpperCase(),
          style: TextStyle(
              color: isSelected ? selectedColor : unselectedColor.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16
          ),
        )
            : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? selectedColor : unselectedColor,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? selectedColor.withOpacity(0.7)
                : unselectedColor.withOpacity(0.6)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      )
          : null,
      selected: isSelected,
      selectedTileColor: selectedColor.withOpacity(0.08),
      hoverColor: theme.hoverColor.withOpacity(0.5),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      dense: true,
    );
  }
}

class _EmptyRoomPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyRoomPlaceholder({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}