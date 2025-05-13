// frontend/lib/services/api/event_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile
import 'package:http_parser/http_parser.dart'; // For MediaType

import '../api_client.dart';
import '../api_endpoints.dart';

class EventService {
  final ApiClient _apiClient;

  EventService(this._apiClient);

  Future<Map<String, dynamic>> getEventDetails(int eventId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.eventDetail(eventId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to fetch event details for ID $eventId - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getCommunityEvents(int communityId, {String? token, int? limit, int? offset}) async {
    try {
      // Backend /communities/{community_id}/events does NOT currently take limit/offset
      // So we ignore them here. If backend is updated, this can be changed.
      final queryParams = <String, String>{};
      // if (limit != null) queryParams['limit'] = limit.toString();
      // if (offset != null) queryParams['offset'] = offset.toString();

      final response = await _apiClient.get(
        ApiEndpoints.communityListEvents(communityId),
        token: token,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("EventService: Failed to fetch events for community ID $communityId - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getNearbyEvents({
    required String? token,
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 20, // Backend for /location/events/nearby is assumed to support these
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      final response = await _apiClient.get(
        ApiEndpoints.nearbyEvents,
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      print("EventService: Failed to fetch nearby events (Lat: $latitude, Lon: $longitude, Rad: $radiusKm) - $e");
      rethrow;
    }
  }

  // No general getAllEvents as backend doesn't provide it.
  // Callers should use getNearbyEvents or getCommunityEvents.

  Future<Map<String, dynamic>> createCommunityEvent({
    required String token,
    required int communityId,
    required String title,
    String? description,
    required String locationAddress,
    required DateTime eventTimestamp,
    required int maxParticipants,
    File? image,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final fields = {
        'title': title,
        'location': locationAddress,
        'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
        'max_participants': maxParticipants.toString(),
      };
      if (description != null && description.isNotEmpty) fields['description'] = description;
      if (latitude != null) fields['latitude'] = latitude.toString();
      if (longitude != null) fields['longitude'] = longitude.toString();

      List<http.MultipartFile>? filesToUpload;
      if (image != null) {
        String? mimeType;
        final extension = image.path.split('.').last.toLowerCase();
        if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
        else if (extension == 'png') mimeType = 'image/png';
        filesToUpload = [await http.MultipartFile.fromPath('image', image.path, contentType: mimeType != null ? MediaType.parse(mimeType) : null)];
      }

      final response = await _apiClient.multipartRequest(
        'POST', ApiEndpoints.communityCreateEvent(communityId),
        token: token, fields: fields, files: filesToUpload,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to create event in community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateEvent({
    required String token,
    required int eventId,
    String? title, String? description, String? locationAddress,
    DateTime? eventTimestamp, int? maxParticipants,
    File? image, double? latitude, double? longitude,
  }) async {
    try {
      final fields = <String, String>{};
      if (title != null) fields['title'] = title;
      if (description != null) fields['description'] = description;
      if (locationAddress != null) fields['location_address'] = locationAddress;
      if (eventTimestamp != null) fields['event_timestamp'] = eventTimestamp.toUtc().toIso8601String();
      if (maxParticipants != null) fields['max_participants'] = maxParticipants.toString();
      if (latitude != null) fields['latitude'] = latitude.toString();
      if (longitude != null) fields['longitude'] = longitude.toString();

      List<http.MultipartFile>? filesToUpload;
      if (image != null) {
        String? mimeType;
        final extension = image.path.split('.').last.toLowerCase();
        if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
        else if (extension == 'png') mimeType = 'image/png';
        filesToUpload = [await http.MultipartFile.fromPath('image', image.path, contentType: mimeType != null ? MediaType.parse(mimeType) : null)];
      }

      final response = await _apiClient.multipartRequest(
        'PUT', ApiEndpoints.eventDetail(eventId),
        token: token, fields: fields, files: filesToUpload,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to update event $eventId - $e");
      rethrow;
    }
  }

  Future<void> deleteEvent({ required String token, required int eventId, }) async {
    try {
      await _apiClient.delete( ApiEndpoints.eventDetail(eventId), token: token, );
    } catch (e) {
      print("EventService: Failed to delete event $eventId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinEvent(int eventId, String token) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.eventJoin(eventId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to join event $eventId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> leaveEvent(int eventId, String token) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.eventLeave(eventId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("EventService: Failed to leave event $eventId - $e");
      rethrow;
    }
  }
}