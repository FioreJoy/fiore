import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../theme/theme_constants.dart';
import 'package:intl/intl.dart';

class ChatEventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback? onJoin;
  final bool isJoined;
  final bool showJoinButton;

  const ChatEventCard({
    Key? key,
    required this.event,
    required this.onTap,
    this.onJoin,
    this.isJoined = false,
    this.showJoinButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Format event date
    final dateFormatter = DateFormat('EEEE, MMM d, y');
    final timeFormatter = DateFormat('h:mm a');
    final dateString = dateFormatter.format(event.dateTime);
    final timeString = timeFormatter.format(event.dateTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF2a1a3e) : const Color(0xFFe0e0fb),
              isDark ? const Color(0xFF1a1a2e) : const Color(0xFFd5d5fa),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ThemeConstants.accentColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeConstants.accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: ThemeConstants.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Event Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Time
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: ThemeConstants.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$dateString at $timeString',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: ThemeConstants.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description (if available)
                  if (event.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        event.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // Participants
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: ThemeConstants.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${event.participants.length} / ${event.maxParticipants} participants',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Join Button
                  if (showJoinButton)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: event.isFull || isJoined ? null : onJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConstants.accentColor,
                          foregroundColor: ThemeConstants.primaryColor,
                          disabledBackgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          disabledForegroundColor: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isJoined
                              ? 'Joined'
                              : event.isFull
                                  ? 'Event Full'
                                  : 'Join Event',
                        ),
                      ),
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
