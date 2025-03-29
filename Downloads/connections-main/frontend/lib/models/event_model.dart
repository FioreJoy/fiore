import 'package:flutter/material.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime dateTime;
  final int maxParticipants;
  final List<String> participants;
  final String creatorId;
  final String communityId;
  final String? imageUrl;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTime,
    required this.maxParticipants,
    required this.participants,
    required this.creatorId,
    required this.communityId,
    this.imageUrl,
  });

  // Check if event is full
  bool get isFull => participants.length >= maxParticipants;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      location: json['location'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      maxParticipants: json['max_participants'] as int,
      participants: (json['participants'] as List<dynamic>).map((e) => e as String).toList(),
      creatorId: json['creator_id'] as String,
      communityId: json['community_id'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }

  // Method to create mock data for development
  static List<EventModel> getMockEvents() {
    return [
      EventModel(
        id: '1',
        title: 'Tech Conference 2023',
        description: 'Annual tech conference with workshops, panels, and networking opportunities.',
        location: 'Convention Center',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        maxParticipants: 20,
        participants: ['102', '103', '104'],
        creatorId: '100',
        communityId: '1',
        imageUrl: 'https://images.unsplash.com/photo-1523580494863-6f3031224c94',
      ),
      EventModel(
        id: '2',
        title: 'Weekly Workout Session',
        description: 'Outdoor group workout for all fitness levels.',
        location: 'Central Park',
        dateTime: DateTime.now().add(const Duration(hours: 5)),
        maxParticipants: 15,
        participants: ['102', '105', '106', '107'],
        creatorId: '101',
        communityId: '2',
        imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
      ),
      EventModel(
        id: '3',
        title: 'Book Club Meeting',
        description: 'Discussion on "The Midnight Library" by Matt Haig.',
        location: 'Local Library',
        dateTime: DateTime.now().add(const Duration(days: 4)),
        maxParticipants: 10,
        participants: ['102', '108'],
        creatorId: '109',
        communityId: '4',
        imageUrl: 'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0',
      ),
    ];
  }
}
