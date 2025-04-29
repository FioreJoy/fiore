// For required annotation if needed

class ChatMessageData {
  final int messageId; // <- renamed from message_id (no underscore for Dart best practices)
  final int? communityId;
  final int? eventId;
  final int userId;
  final String username;
  final String content;
  final DateTime timestamp;

  // --- New Attachment Fields ---
  final String? attachmentUrl; // URL from MinIO
  final String? attachmentType; // e.g., 'image', 'video', 'pdf', 'file'
  final String? attachmentFilename; // Original filename for display

  ChatMessageData({
    required this.messageId,
    this.communityId,
    this.eventId,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFilename,
  });

  factory ChatMessageData.fromJson(Map<String, dynamic> json) {
    if (json['message_id'] == null || json['user_id'] == null || json['content'] == null || json['timestamp'] == null) {
      print("Error parsing ChatMessageData: Missing required fields in JSON: $json");
      throw FormatException("Missing required fields in ChatMessageData JSON", json);
    }

    DateTime parsedTimestamp;
    try {
      if (json['timestamp'] is String) {
        parsedTimestamp = DateTime.parse(json['timestamp'] as String).toLocal();
      } else if (json['timestamp'] is int) {
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int, isUtc: true).toLocal();
      } else {
        parsedTimestamp = DateTime.now();
      }
    } catch (e) {
      print("Error parsing timestamp '${json['timestamp']}': $e. Using current time as fallback.");
      parsedTimestamp = DateTime.now().toLocal();
    }

    return ChatMessageData(
      messageId: json['message_id'] as int,
      communityId: json['community_id'] as int?,
      eventId: json['event_id'] as int?,
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? 'Unknown User',
      content: json['content'] as String,
      timestamp: parsedTimestamp,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      attachmentFilename: json['attachment_filename'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'community_id': communityId,
    'event_id': eventId,
    'user_id': userId,
    'username': username,
    'content': content,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'attachment_url': attachmentUrl,
    'attachment_type': attachmentType,
    'attachment_filename': attachmentFilename,
  };
}
