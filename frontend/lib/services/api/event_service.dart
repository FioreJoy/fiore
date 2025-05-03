// frontend/lib/services/api/event_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Usually not needed in service layer

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for event-related API calls.
class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  /// Fetches details for a specific event, including participant count.
  /// Auth token optional (needed for viewer participation status).
  Future<Map<String, dynamic>> getEventDetails(int eventId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.eventDetail(eventId), token: token,
      );
      // Backend returns EventDisplay with participant_count included
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to fetch event details for ID $eventId - $e");
      rethrow;
    }
  }

  /// Fetches events for a specific community, including participant counts.
  /// Auth token optional.
  Future<List<dynamic>> getCommunityEvents(int communityId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communityListEvents(communityId), token: token, // Use correct endpoint
      );
      // Backend returns List<EventDisplay> with participant_count included
      return response as List<dynamic>;
    } catch (e) {
      print("EventService: Failed to fetch events for community ID $communityId - $e");
      rethrow;
    }
  }

  /// Creates a new event within a specific community. Requires auth token.
  Future<Map<String, dynamic>> createCommunityEvent({
    required String token,
    required int communityId,
    required String title,
    String? description,
    required String location,
    required DateTime eventTimestamp, // Pass DateTime object
    required int maxParticipants,
    File? image,
  }) async {
    try {
      final fields = {
        'title': title,
        'location': location,
        // Format DateTime to ISO8601 UTC string for backend form data
        'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
        'max_participants': maxParticipants.toString(),
      };
      if (description != null && description.isNotEmpty) fields['description'] = description;

      List<http.MultipartFile>? files;
      if (image != null) { files = [await http.MultipartFile.fromPath('image', image.path)]; }

      final response = await _apiClient.multipartRequest(
        'POST', ApiEndpoints.communityCreateEvent(communityId), // Use correct endpoint
        token: token, fields: fields, files: files,
      );
      // Expects created EventDisplay with counts
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to create event in community $communityId - $e");
      rethrow;
    }
  }

  /// Updates an existing event. Requires auth token (creator).
  Future<Map<String, dynamic>> updateEvent({
    required String token,
    required int eventId,
    // Pass only fields provided by user
    String? title, String? description, String? location,
    DateTime? eventTimestamp, int? maxParticipants,
    File? image, // Optional new image
  }) async {
    try {
      final fields = <String, String>{};
      // Add fields only if they are not null
      if (title != null) fields['title'] = title;
      if (description != null) fields['description'] = description; // Allow clearing
      if (location != null) fields['location'] = location;
      if (eventTimestamp != null) fields['event_timestamp'] = eventTimestamp.toUtc().toIso8601String();
      if (maxParticipants != null) fields['max_participants'] = maxParticipants.toString();

      List<http.MultipartFile>? files;
      if (image != null) { files = [await http.MultipartFile.fromPath('image', image.path)]; }

      final response = await _apiClient.multipartRequest( // Use multipart PUT
        'PUT', ApiEndpoints.eventDetail(eventId), token: token, fields: fields, files: files,
      );
      // Expects updated EventDisplay with counts
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to update event $eventId - $e");
      rethrow;
    }
  }

  /// Deletes an event. Requires auth token (creator).
  Future<void> deleteEvent({ required String token, required int eventId, }) async {
    try {
      await _apiClient.delete( ApiEndpoints.eventDetail(eventId), token: token, );
      // Expects 204 No Content
    } catch (e) {
      print("EventService: Failed to delete event $eventId - $e");
      rethrow;
    }
  }

  // --- Event Participation ---

  /// Joins the current user to a specific event. Requires auth token.
  Future<Map<String, dynamic>> joinEvent(int eventId, String token) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.eventJoin(eventId), token: token,
      );
      // Expects response like {'message':..., 'success':..., 'new_participant_count':...}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to join event $eventId - $e");
      // Check for specific error messages if backend sends them (e.g., event full)
      // Example: if (e.toString().contains("Event is full")) ...
      rethrow;
    }
  }

  /// Makes the current user leave a specific event. Requires auth token.
  Future<Map<String, dynamic>> leaveEvent(int eventId, String token) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.eventLeave(eventId), token: token,
      );
      // Expects response like {'message':..., 'success':..., 'new_participant_count':...}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to leave event $eventId - $e");
      rethrow;
    }
  }
}