import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
// For formatting dates if needed client-side

import '../api_client.dart';
import '../api_endpoints.dart';
// Import EventModel if you use it for type safety

/// Service responsible for event-related API calls.
class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  /// Fetches details for a specific event.
  /// Requires API Key, token might be optional depending on backend setup.
  Future<Map<String, dynamic>> getEventDetails(int eventId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.eventDetail(eventId),
      );
      return response as Map<String, dynamic>; // Expects EventDisplay schema
    } catch (e) {
      print("EventService: Failed to fetch event details for ID $eventId - $e");
      rethrow;
    }
  }

  /// Fetches events for a specific community.
  /// Requires API Key, token might be optional.
  Future<List<dynamic>> getCommunityEvents(int communityId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communityListEvents(communityId), // Uses community-scoped endpoint
      );
      return response as List<dynamic>; // Expects List<EventDisplay>
    } catch (e) {
      print("EventService: Failed to fetch events for community ID $communityId - $e");
      rethrow;
    }
  }

  /// Creates a new event within a specific community.
  /// Requires authentication token and API Key.
  Future<Map<String, dynamic>> createCommunityEvent({
    required int communityId,
    required String title,
    String? description,
    required String location,
    required DateTime eventTimestamp,
    required int maxParticipants,
    File? image, // Optional event image
  }) async {
    try {
      final fields = {
        'title': title,
        'location': location,
        // Format timestamp to ISO 8601 UTC string for backend compatibility
        'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
        'max_participants': maxParticipants.toString(),
      };
      if (description != null && description.isNotEmpty) {
        fields['description'] = description;
      }

      List<http.MultipartFile>? files;
      if (image != null) {
        files = [await http.MultipartFile.fromPath('image', image.path)];
      }

      // Uses the community-scoped endpoint for creation
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.communityCreateEvent(communityId),
        fields: fields,
        files: files,
      );
      return response as Map<String, dynamic>; // Expects created EventDisplay
    } catch (e) {
      print("EventService: Failed to create event in community $communityId - $e");
      rethrow;
    }
  }

  /// Updates an existing event. Requires user authentication (creator).
  Future<Map<String, dynamic>> updateEvent({
    required int eventId,
    // Pass only fields that can be updated
    String? title,
    String? description,
    String? location,
    DateTime? eventTimestamp,
    int? maxParticipants,
    File? image, // Optional new image
  }) async {
    try {
      final fields = <String, String>{};
      if (title != null) fields['title'] = title;
      if (description != null) fields['description'] = description; // Allow clearing description
      if (location != null) fields['location'] = location;
      if (eventTimestamp != null) fields['event_timestamp'] = eventTimestamp.toUtc().toIso8601String();
      if (maxParticipants != null) fields['max_participants'] = maxParticipants.toString();

      List<http.MultipartFile>? files;
      if (image != null) {
        files = [await http.MultipartFile.fromPath('image', image.path)];
      }

      // Use multipart PUT request to handle optional image update
      final response = await _apiClient.multipartRequest(
        'PUT',
        ApiEndpoints.eventDetail(eventId), // Endpoint for specific event
        fields: fields,
        files: files,
      );
      return response as Map<String, dynamic>; // Expects updated EventDisplay
    } catch (e) {
      print("EventService: Failed to update event $eventId - $e");
      rethrow;
    }
  }

  /// Deletes an event. Requires user authentication (creator).
  Future<void> deleteEvent({
    required int eventId,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.eventDetail(eventId), // Endpoint for specific event
      );
      // Expects 204 No Content
    } catch (e) {
      print("EventService: Failed to delete event $eventId - $e");
      rethrow;
    }
  }

  // --- Event Participation ---

  /// Joins the current user to a specific event.
  Future<void> joinEvent(int eventId) async {
    try {
      await _apiClient.post(
        ApiEndpoints.eventJoin(eventId),
        // No body needed typically
      );
      // Expects 200 OK, _handleResponse returns message map or null
    } catch (e) {
      print("EventService: Failed to join event $eventId - $e");
      rethrow; // Let UI handle specific errors like 'Event is full'
    }
  }

  /// Makes the current user leave a specific event.
  Future<void> leaveEvent(int eventId) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.eventLeave(eventId),
      );
      // Expects 200 OK, _handleResponse returns message map or null
    } catch (e) {
      print("EventService: Failed to leave event $eventId - $e");
      rethrow;
    }
  }
}
