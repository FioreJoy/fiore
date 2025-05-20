// frontend/lib/models/notification_model.dart

import 'package:flutter/foundation.dart'; // For @required if using older Flutter versions

class NotificationActorInfo {
  final int id;
  final String username;
  final String? name;
  final String? avatarUrl;

  NotificationActorInfo({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
  });

  factory NotificationActorInfo.fromJson(Map<String, dynamic> json) {
    return NotificationActorInfo(
      id: json['id'] as int,
      username: json['username'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class NotificationRelatedEntityInfo {
  final String? type; // e.g., 'post', 'event', 'user', 'community', 'reply'
  final int? id;
  final String? title; // e.g., post title, event name, community name, username

  NotificationRelatedEntityInfo({
    this.type,
    this.id,
    this.title,
  });

  factory NotificationRelatedEntityInfo.fromJson(Map<String, dynamic> json) {
    return NotificationRelatedEntityInfo(
      type: json['type'] as String?,
      id: json['id'] as int?,
      title: json['title'] as String?,
    );
  }
}

// Enum to match backend (can be string if preferred, but enum is safer)
enum NotificationType {
  newFollower,
  postReply,
  replyReply,
  postVote,
  replyVote,
  postFavorite,
  replyFavorite,
  eventInvite,
  eventReminder,
  eventUpdate,
  communityInvite,
  communityPost,
  newCommunityEvent, // Matches the updated backend enum
  userMention,
  unknown // Fallback for types not recognized by frontend
}

NotificationType _notificationTypeFromString(String? typeString) {
  if (typeString == null) return NotificationType.unknown;
  switch (typeString) {
    case 'new_follower':
      return NotificationType.newFollower;
    case 'post_reply':
      return NotificationType.postReply;
    case 'reply_reply':
      return NotificationType.replyReply;
    case 'post_vote':
      return NotificationType.postVote;
    case 'reply_vote':
      return NotificationType.replyVote;
    case 'post_favorite':
      return NotificationType.postFavorite;
    case 'reply_favorite':
      return NotificationType.replyFavorite;
    case 'event_invite':
      return NotificationType.eventInvite;
    case 'event_reminder':
      return NotificationType.eventReminder;
    case 'event_update':
      return NotificationType.eventUpdate;
    case 'community_invite':
      return NotificationType.communityInvite;
    case 'community_post':
      return NotificationType.communityPost;
    case 'new_community_event':
      return NotificationType.newCommunityEvent;
    case 'user_mention':
      return NotificationType.userMention;
    default:
      print("Warning: Unknown notification type string received: $typeString");
      return NotificationType.unknown;
  }
}

class NotificationModel {
  final int id;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String? contentPreview;
  final NotificationActorInfo? actor;
  final NotificationRelatedEntityInfo? relatedEntity;

  NotificationModel({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.contentPreview,
    this.actor,
    this.relatedEntity,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null ||
        json['type'] == null ||
        json['is_read'] == null ||
        json['created_at'] == null) {
      print(
          "Error parsing NotificationModel: Missing required fields in JSON: $json");
      throw FormatException(
          "Missing required fields in NotificationModel JSON", json);
    }

    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = DateTime.parse(json['created_at'] as String).toLocal();
    } catch (e) {
      print(
          "Error parsing notification created_at '${json['created_at']}': $e. Using current time as fallback.");
      parsedCreatedAt = DateTime.now().toLocal();
    }

    return NotificationModel(
      id: json['id'] as int,
      type: _notificationTypeFromString(json['type'] as String?),
      isRead: json['is_read'] as bool,
      createdAt: parsedCreatedAt,
      contentPreview: json['content_preview'] as String?,
      actor: json['actor'] != null
          ? NotificationActorInfo.fromJson(
              json['actor'] as Map<String, dynamic>)
          : null,
      relatedEntity: json['related_entity'] != null
          ? NotificationRelatedEntityInfo.fromJson(
              json['related_entity'] as Map<String, dynamic>)
          : null,
    );
  }

  // Helper method to get a human-readable message (can be expanded)
  String get message {
    String actorName = actor?.username ?? 'Someone';
    String entityTitle = relatedEntity?.title ?? 'something';
    String entityType = relatedEntity?.type ?? 'item';

    switch (type) {
      case NotificationType.newFollower:
        return '$actorName started following you.';
      case NotificationType.postReply:
        return '$actorName replied to your post: "${contentPreview ?? entityTitle}"';
      case NotificationType.replyReply:
        return '$actorName replied to your comment: "${contentPreview ?? 'your comment'}"';
      case NotificationType.postVote:
        return '$actorName voted on your post: "$entityTitle".';
      case NotificationType.communityPost:
        return '$actorName posted in ${relatedEntity?.title ?? "a community"}: "${contentPreview ?? entityTitle}"';
      case NotificationType.newCommunityEvent:
        return 'New event in ${relatedEntity?.title ?? "a community"}: "$entityTitle"';
      case NotificationType.eventUpdate:
        return 'Event "$entityTitle" has been updated.';
      // Add more cases as needed
      default:
        return contentPreview ?? 'You have a new notification.';
    }
  }
}
