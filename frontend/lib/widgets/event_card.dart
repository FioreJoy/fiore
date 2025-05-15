// frontend/lib/widgets/event_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';
import '../theme/theme_constants.dart';
import '../app_constants.dart'; 
import 'custom_button.dart'; 
import '../services/auth_provider.dart'; 

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap; 
  final Future<void> Function()? onJoinLeave; 
  final VoidCallback? onChat; 

  const EventCard({
    Key? key,
    required this.event,
    this.onTap,
    this.onJoinLeave,
    this.onChat, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isParticipating = event.isParticipatingByViewer ?? false;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
      ),
      color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Hero(
                tag: 'event_image_${event.id}',
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 160,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 160,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Icon(Icons.event_busy_outlined, size: 50, color: Colors.grey.shade500),
                  ),
                ),
              )
            else 
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                child: Icon(Icons.event_note_outlined, size: 60, color: Colors.grey.shade500),
              ),

            Padding(
              padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: ThemeConstants.smallPadding / 2),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 15, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('${event.formattedDate} at ${event.formattedTime}', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 15, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(event.locationAddress, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: ThemeConstants.smallPadding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      Row(children: [
                        Icon(Icons.people_outline_rounded, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${event.participantCount} / ${event.maxParticipants} spots', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
                        if (event.isFull && !isParticipating)
                          Text(' (Full)', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                      ]),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isParticipating && onChat != null && authProvider.isAuthenticated)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: CustomButton(
                                text: 'Chat',
                                onPressed: onChat, // Directly assign nullable callback
                                type: ButtonType.outline,
                                icon: Icons.chat_bubble_outline_rounded,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                fontSize: 12,
                                foregroundColor: theme.colorScheme.primary,
                                borderColor: theme.colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          if (onJoinLeave != null && authProvider.isAuthenticated)
                            CustomButton(
                              text: isParticipating ? 'Leave' : (event.isFull ? 'Full' : 'Join'),
                              // Directly assign nullable callback. If event.isFull, onJoinLeave will be null.
                              onPressed: (event.isFull && !isParticipating) ? null : onJoinLeave,
                              type: isParticipating ? ButtonType.outline : ButtonType.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              fontSize: 13,
                              backgroundColor: (event.isFull && !isParticipating) ? Colors.grey.shade400 : null,
                            )
                           else if (!authProvider.isAuthenticated && onJoinLeave != null) 
                             CustomButton(
                               text: 'Join',
                               onPressed: () {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Please log in to join events.'))
                                 );
                               },
                               type: ButtonType.primary,
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                               fontSize: 13,
                             ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
