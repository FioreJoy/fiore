import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../../../../core/theme/theme_constants.dart';
import '../../../../data/models/event_model.dart'; // Model for event data
import '../../../global_widgets/chat_event_card.dart'; // The UI card widget
// Import UserCommunities if available, otherwise you might pass the name directly
// This assumes _userCommunities is available or community name is passed.

class ChatSelectedEventCard extends StatelessWidget {
  final EventModel? currentEventDetails;
  final bool isLoadingRoomDetails;
  final Function(String newRoomType, int newRoomId, String newRoomName)
      switchToRoom;
  final List<Map<String, dynamic>>
      userCommunities; // Needed to find parent community name

  const ChatSelectedEventCard({
    Key? key,
    required this.currentEventDetails,
    required this.isLoadingRoomDetails,
    required this.switchToRoom,
    required this.userCommunities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentEventDetails == null) {
      return isLoadingRoomDetails
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Center(child: LinearProgressIndicator(minHeight: 2)))
          : const SizedBox
              .shrink(); // Or some placeholder if details couldn't load
    }

    final event = currentEventDetails!;
    // Determine if current user is participating, from the event model itself
    final bool isJoined = event.isParticipatingByViewer ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ChatEventCard(
        event: event,
        isJoined: isJoined, // Pass the status
        isSelected: true, // Always selected when displayed in chat header
        showJoinButton: false, // No join/leave button here, handled elsewhere
        trailingWidget: TextButton(
          onPressed: () {
            // Attempt to find the parent community's name
            int? parentCommunityId = int.tryParse(event.communityId.toString());
            String parentCommunityName = "Community Chat"; // Default

            if (parentCommunityId != null) {
              final communityContext = userCommunities
                  .firstWhereOrNull((c) => c['id'] == parentCommunityId);
              if (communityContext != null &&
                  communityContext['name'] != null) {
                parentCommunityName = communityContext['name'] as String;
              }
            } else {
              // This case should ideally not happen if event.communityId is always valid
              print(
                  "Warning: Could not parse parent community ID for event ${event.id}");
            }

            // Even if community name isn't found, we can still switch with the ID
            if (parentCommunityId != null) {
              switchToRoom('community', parentCommunityId, parentCommunityName);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Could not determine parent community for this event.')));
            }
          },
          child:
              const Text('Back to Community', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
