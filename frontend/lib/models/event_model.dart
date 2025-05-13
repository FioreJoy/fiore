// frontend/lib/models/event_model.dart
import 'package:intl/intl.dart'; // For date formatting

// Simple model for location coordinates, matching backend schema
class LocationPoint {
  final double longitude;
  final double latitude;

  LocationPoint({required this.longitude, required this.latitude});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EventModel {
  final String id;
  final String title;
  final String? description;
  final String locationAddress; // Text address from DB 'location'
  final DateTime eventTimestamp;
  final int maxParticipants;
  final int participantCount; // From backend aggregation
  final String creatorId;
  final String communityId;
  final String? imageUrl; // MinIO object name or full URL from pre-signed
  final LocationPoint? locationCoords; // Parsed from DB 'location_coords'
  final bool? isParticipatingByViewer; // If current user is participating

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.locationAddress,
    required this.eventTimestamp,
    required this.maxParticipants,
    required this.participantCount,
    required this.creatorId,
    required this.communityId,
    this.imageUrl,
    this.locationCoords,
    this.isParticipatingByViewer,
  });

  bool get isFull => participantCount >= maxParticipants;

  String get formattedDate {
    try {
      return DateFormat('EEE, MMM d').format(eventTimestamp);
    } catch (e) {
      return 'Date Error';
    }
  }

  String get formattedTime {
    try {
      return DateFormat('h:mm a').format(eventTimestamp);
    } catch (e) {
      return 'Time Error';
    }
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Basic validation for required fields
    if (json['id'] == null || json['title'] == null || json['location'] == null || json['event_timestamp'] == null || json['creator_id'] == null || json['community_id'] == null) {
      print("EventModel Error: Missing required fields in JSON: $json");
      throw FormatException("Missing required fields in EventModel JSON", json);
    }

    DateTime parsedEventTimestamp;
    try {
      parsedEventTimestamp = DateTime.parse(json['event_timestamp'] as String).toLocal();
    } catch (e) {
      print("EventModel Error parsing event_timestamp '${json['event_timestamp']}': $e. Using current time as fallback.");
      parsedEventTimestamp = DateTime.now().toLocal(); // Fallback
    }

    return EventModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      locationAddress: json['location'] as String, // Backend sends address in 'location' field
      eventTimestamp: parsedEventTimestamp,
      maxParticipants: json['max_participants'] as int? ?? 100,
      participantCount: json['participant_count'] as int? ?? 0,
      creatorId: json['creator_id'].toString(),
      communityId: json['community_id'].toString(),
      imageUrl: json['image_url'] as String?, // This will be the presigned URL from backend
      locationCoords: json['location_coords'] != null && json['location_coords'] is Map
          ? LocationPoint.fromJson(json['location_coords'] as Map<String, dynamic>)
          : null,
      isParticipatingByViewer: json['is_participating_by_viewer'] as bool?,
    );
  }
}