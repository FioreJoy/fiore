// frontend/lib/widgets/chat_event_card.dart
import 'package:flutter/material.dart';
import '../models/event_model.dart'; // Assuming model path
import '../theme/theme_constants.dart'; // Assuming theme path
import 'package:intl/intl.dart'; // For date formatting

class ChatEventCard extends StatelessWidget {
  final EventModel event;
  final bool isJoined;
  final bool isSelected; // Added previously
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool showJoinButton;
  final Widget? trailingWidget; // <-- ADD THIS FIELD

  const ChatEventCard({
    Key? key,
    required this.event,
    required this.isJoined,
    this.isSelected = false, // Default to false
    this.onTap,
    this.onJoin,
    this.showJoinButton = true,
    this.trailingWidget, // <-- ADD TO CONSTRUCTOR
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Example formatting (adjust as needed)
    final formattedDate = DateFormat('MMM d, ').format(event.dateTime);
    final formattedTime = DateFormat('h:mm a').format(event.dateTime);

    return Card(
      elevation: isSelected ? 4 : 1, // Highlight if selected
      margin: EdgeInsets.zero, // Margin handled by parent usually
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : Colors.transparent, // Border if selected
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row( // Use Row for layout
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional: Event Image or Icon
              if (event.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    event.imageUrl!,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => const Icon(Icons.event, size: 40, color: Colors.grey),
                  ),
                )
              else
                Icon(Icons.event_note, size: 40, color: theme.primaryColor.withOpacity(0.7)),

              const SizedBox(width: 12),

              // Event Info Column
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
                      '${formattedDate}at $formattedTime',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${event.participants.length} / ${event.maxParticipants} joined', // Show participant count
                      style: theme.textTheme.bodySmall?.copyWith(color: event.isFull ? Colors.orange.shade700 : Colors.grey.shade600),
                    ),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.location,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),

              // Actions Column (Join Button / Trailing Widget)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showJoinButton && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                        backgroundColor: isJoined ? Colors.grey : theme.primaryColor, // Style based on join status
                        foregroundColor: Colors.white,
                        minimumSize: const Size(60, 30), // Ensure minimum size
                      ),
                      child: Text(isJoined ? 'Leave' : 'Join'),
                    ),

                  // --- ADD TRAILING WIDGET HERE ---
                  if (trailingWidget != null) ...[
                    if(showJoinButton) const SizedBox(height: 4), // Add space if join button is also shown
                    trailingWidget!,
                  ]
                  // -------------------------------
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}