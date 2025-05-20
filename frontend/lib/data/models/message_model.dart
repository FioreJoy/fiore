// frontend/lib/models/message_model.dart
import 'package:flutter/material.dart'; // Not strictly needed for this model but often present
// NEW: Import a model for media items if you have one, or define a simple one here.
// Let's assume you might have a structure like this, matching backend/schemas.py MediaItemDisplay
// If not, we can define a simpler one or use Map<String, dynamic>.
// For now, let's assume a structure similar to what ChatMessageData might expect for its media.

class MediaItem {
  // Simple model for media items in a message
  final String id;
  final String? url;
  final String mimeType;
  final String? originalFilename;
  final int? fileSize; // Optional: if you want to display size

  MediaItem({
    required this.id,
    this.url,
    required this.mimeType,
    this.originalFilename,
    this.fileSize,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id']?.toString() ??
          '', // Backend usually sends int, convert to string
      url: json['url'] as String?,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      originalFilename: json['original_filename'] as String?,
      fileSize: json['file_size_bytes'] as int?,
    );
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String? profileImageUrl;
  final List<MediaItem>? media; // <<< NEW: List to hold media items

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.profileImageUrl,
    this.media, // <<< NEW: Add to constructor
  });

  // fromJson might not be directly used if ChatScreen constructs this model,
  // but good to have for completeness or other use cases.
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    List<MediaItem>? mediaItems;
    if (json['media'] != null && json['media'] is List) {
      mediaItems = (json['media'] as List)
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return MessageModel(
      id: json['id']?.toString() ?? '',
      senderId: json['user_id']?.toString() ??
          json['sender_id']?.toString() ??
          '', // Handle potential key differences
      senderName: json['author_name'] ?? json['sender_name'] ?? 'Unknown',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      profileImageUrl: json['profile_image_url'] as String?,
      media: mediaItems, // <<< NEW: Initialize media
    );
  }

  // toJson might be useful if you ever send this model back or store it locally.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'profile_image_url': profileImageUrl,
        'media': media
            ?.map((item) => {
                  // Basic serialization for media
                  'id': item.id,
                  'url': item.url,
                  'mime_type': item.mimeType,
                  'original_filename': item.originalFilename,
                  'file_size_bytes': item.fileSize,
                })
            .toList(),
      };
}
