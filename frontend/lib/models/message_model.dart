import 'package:flutter/material.dart';

// frontend/lib/models/message_model.dart
class MessageModel {
  final String id;
  final String senderId;
  final String senderName; // Changed from username to senderName
  final String content;
  final DateTime timestamp;
  final String? profileImageUrl;
  
  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.profileImageUrl,
  });
  
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'].toString(),
      senderId: json['user_id'].toString(),
      senderName: json['author_name'] ?? 'Unknown',
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      profileImageUrl: json['profile_image_url'],
    );
  }
}
