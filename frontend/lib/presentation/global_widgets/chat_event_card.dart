import 'package:flutter/material.dart';

// Data Layer
import '../../data/models/event_model.dart'; // Corrected path

// Core
import '../../core/theme/theme_constants.dart'; // Corrected path
// import 'package:intl/intl.dart'; // Already imported via event_model.dart potentially, but safe to keep if used directly

class ChatEventCard extends StatelessWidget {
  final EventModel event;
  final bool isJoined;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool showJoinButton;
  final Widget? trailingWidget;

  const ChatEventCard({
    Key? key,
    required this.event,
    required this.isJoined,
    this.isSelected = false,
    this.onTap,
    this.onJoin,
    this.showJoinButton = true,
    this.trailingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Not directly used in this simplified version

    final formattedDate = event.formattedDate;
    final formattedTime = event.formattedTime;
    final bool effectiveIsJoined = event.isParticipatingByViewer ?? isJoined;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: EdgeInsets.zero, // Let parent handle margin if needed
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius /
            2), // Smaller radius for compact card
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(ThemeConstants.cardBorderRadius / 2),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align items to the top
            children: [
              // Event Image or Icon
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    // Assuming imageUrl is a full URL
                    event.imageUrl!, width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => const Icon(
                        Icons.event_note_outlined,
                        size: 40,
                        color: Colors.grey),
                  ),
                )
              else
                Icon(Icons.event_note_outlined,
                    size: 40,
                    color: theme.colorScheme.primary.withOpacity(0.7)),

              const SizedBox(width: 12),

              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize.min, // Take only needed vertical space
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedDate at $formattedTime',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${event.participantCount} / ${event.maxParticipants} joined',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: event.isFull
                              ? Colors.orange.shade700
                              : Colors.grey.shade600),
                    ),
                    if (event.locationAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.locationAddress,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8), // Space before trailing widget/button
              // Action Button or Trailing Widget
              if (trailingWidget != null)
                trailingWidget!
              else if (showJoinButton && onJoin != null)
                ElevatedButton(
                  onPressed: (event.isFull && !effectiveIsJoined)
                      ? null
                      : onJoin, // Disable join if full and not joined
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                    backgroundColor: effectiveIsJoined
                        ? Colors.grey.shade400
                        : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    minimumSize: const Size(60, 30),
                  ),
                  child: Text(effectiveIsJoined
                      ? 'Leave'
                      : (event.isFull ? 'Full' : 'Join')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
