// frontend/lib/models/chat_message_data.dart
import 'package:flutter/foundation.dart'; // For required annotation if needed

// --- NEW: Import or Define MediaItemDisplay if it's not globally accessible ---
// This should match the structure expected from the backend (schemas.MediaItemDisplay)
// If you have a shared models directory, import from there.
// For now, defining a compatible version here.
class MediaItemDisplay {
  final dynamic id; // Can be int or String from JSON, handle parsing
  final String? url;
  final String mimeType;
  final int? fileSizeBytes;
  final String? originalFilename;
  final int? width;
  final int? height;
  final double? durationSeconds;
  final DateTime createdAt;

  MediaItemDisplay({
    required this.id,
    this.url,
    required this.mimeType,
    this.fileSizeBytes,
    this.originalFilename,
    this.width,
    this.height,
    this.durationSeconds,
    required this.createdAt,
  });

  factory MediaItemDisplay.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = DateTime.parse(json['created_at'] as String).toLocal();
    } catch (e) {
      parsedCreatedAt = DateTime.now().toLocal(); // Fallback
    }
    return MediaItemDisplay(
      id: json['id'], // Keep as dynamic, convert to string if needed where used
      url: json['url'] as String?,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int?,
      originalFilename: json['original_filename'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      createdAt: parsedCreatedAt,
    );
  }
}
// --- END NEW ---

class ChatMessageData {
  final int message_id;
  final int? community_id;
  final int? event_id;
  final int user_id;
  final String username;
  final String content;
  final DateTime timestamp;
  final String? profile_image_url; // This was already present
  final List<MediaItemDisplay> media; // <<< ADDED THIS FIELD

  ChatMessageData({
    required this.message_id,
    this.community_id,
    this.event_id,
    required this.user_id,
    required this.username,
    required this.content,
    required this.timestamp,
    this.profile_image_url,
    List<MediaItemDisplay>?
        media, // Make media optional in constructor, default to empty
  }) : media = media ?? []; // Initialize with empty list if null

  factory ChatMessageData.fromJson(Map<String, dynamic> json) {
    if (json['message_id'] == null ||
        json['user_id'] == null ||
        json['content'] == null ||
        json['timestamp'] == null) {
      print(
          "Error parsing ChatMessageData: Missing required fields in JSON: $json");
      throw FormatException(
          "Missing required fields in ChatMessageData JSON", json);
    }

    DateTime parsedTimestamp;
    try {
      parsedTimestamp = DateTime.parse(json['timestamp'] as String).toLocal();
    } catch (e) {
      parsedTimestamp = DateTime.now().toLocal();
    }

    List<MediaItemDisplay> parsedMedia = [];
    if (json['media'] != null && json['media'] is List) {
      try {
        parsedMedia = (json['media'] as List<dynamic>)
            .where(
                (item) => item is Map<String, dynamic>) // Ensure items are maps
            .map((item) =>
                MediaItemDisplay.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print(
            "Error parsing media items in ChatMessageData: $e. Media data: ${json['media']}");
        // Keep parsedMedia as empty list on error
      }
    }

    return ChatMessageData(
      message_id: json['message_id'] as int,
      community_id: json['community_id'] as int?,
      event_id: json['event_id'] as int?,
      user_id: json['user_id'] as int,
      username: json['username'] as String? ?? 'Unknown User',
      content: json['content'] as String,
      timestamp: parsedTimestamp,
      profile_image_url: json['profile_image_url']
          as String?, // This field was for sender's avatar, not message media
      media: parsedMedia, // Initialize with parsed media
    );
  }

  Map<String, dynamic> toJson() => {
        'message_id': message_id,
        'community_id': community_id,
        'event_id': event_id,
        'user_id': user_id,
        'username': username,
        'content': content,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'profile_image_url': profile_image_url,
        'media': media
            .map((item) => {
                  // Basic serialization for media if needed
                  'id': item.id,
                  'url': item.url,
                  'mime_type': item.mimeType,
                  'original_filename': item.originalFilename,
                  'file_size_bytes': item.fileSizeBytes,
                  // ... other fields from MediaItemDisplay if needed for toJson
                })
            .toList(),
      };
}
