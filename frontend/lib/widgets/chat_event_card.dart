// frontend/lib/widgets/chat_event_card.dart
import 'package:flutter/material.dart';
import '../models/event_model.dart'; // Assuming model path
import '../theme/theme_constants.dart'; // Assuming theme path
import 'package:intl/intl.dart'; // For date formatting

class ChatEventCard extends StatelessWidget {
  final EventModel event;
  final bool isJoined; // This is now based on event.isParticipatingByViewer
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onJoin; // This might be deprecated if join handled differently
  final bool showJoinButton;
  final Widget? trailingWidget;

  const ChatEventCard({
    Key? key,
    required this.event,
    required this.isJoined, // Keep for UI consistency, but source it from event.isParticipatingByViewer
    this.isSelected = false,
    this.onTap,
    this.onJoin,
    this.showJoinButton = true,
    this.trailingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Not directly used, but kept for context

    // Use getters from EventModel for formatted date/time
    final formattedDate = event.formattedDate;
    final formattedTime = event.formattedTime;
    final bool effectiveIsJoined = event.isParticipatingByViewer ?? isJoined; // Prioritize from model

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty) // Use imageUrl directly
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network( // Assuming imageUrl is a full URL from pre-signed
                    event.imageUrl!,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => const Icon(Icons.event, size: 40, color: Colors.grey),
                  ),
                )
              else
                Icon(Icons.event_note_outlined, size: 40, color: theme.primaryColor.withOpacity(0.7)),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedDate at $formattedTime', // Use model's formatted getters
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    Text(
                      // Use event.participantCount from the model
                      '${event.participantCount} / ${event.maxParticipants} joined',
                      style: theme.textTheme.bodySmall?.copyWith(color: event.isFull ? Colors.orange.shade700 : Colors.grey.shade600),
                    ),
                    if (event.locationAddress.isNotEmpty) ...[ // Use locationAddress
                      const SizedBox(height: 2),
                      Text(
                        event.locationAddress, // Use locationAddress
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showJoinButton && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                        backgroundColor: effectiveIsJoined ? Colors.grey : theme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(60, 30),
                      ),
                      child: Text(effectiveIsJoined ? 'Leave' : (event.isFull ? 'Full' : 'Join')),
                    ),
                  if (trailingWidget != null) ...[
                    if(showJoinButton && onJoin != null) const SizedBox(height: 4),
                    trailingWidget!,
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}