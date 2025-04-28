import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';
// Import models if created, e.g., CommunityDisplay, EventModel, PostDisplay

/// Service responsible for community-related API calls.
class CommunityService {
  final ApiClient _apiClient;

  CommunityService(this._apiClient);

  /// Fetches a list of all communities.
  /// Requires API Key but usually not user JWT token (depends on backend security).
  Future<List<dynamic>> getCommunities({String? token}) async {
    try {
      // Pass token if required by backend for listing, otherwise null might be okay
      // ApiClient automatically adds API Key header
      final response = await _apiClient.get(
        ApiEndpoints.communitiesBase,
        token: token, // Pass token if needed
      );
      return response as List<dynamic>; // Expects List<CommunityDisplay>
    } catch (e) {
      print("CommunityService: Failed to fetch communities - $e");
      rethrow;
    }
  }

  /// Fetches a list of trending communities.
  Future<List<dynamic>> getTrendingCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesTrending,
        token: token, // Pass token if needed
      );
      return response as List<dynamic>; // Expects List<CommunityDisplay>
    } catch (e) {
      print("CommunityService: Failed to fetch trending communities - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getJoinedCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesTrending,
        token: token, // Pass token if needed
      );
      return response as List<dynamic>; // Expects List<CommunityDisplay>
    } catch (e) {
      print("CommunityService: Failed to fetch trending communities - $e");
      rethrow;
    }
  }

  /// Fetches details for a specific community.
  Future<Map<String, dynamic>> getCommunityDetails(int communityId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communityDetail(communityId),
        token: token, // Pass token if needed
      );
      return response as Map<String, dynamic>; // Expects CommunityDisplay
    } catch (e) {
      print("CommunityService: Failed to fetch community details for ID $communityId - $e");
      rethrow;
    }
  }

  /// Creates a new community. Requires user authentication token and API Key.
  Future<Map<String, dynamic>> createCommunity({
    required String token,
    required String name,
    String? description,
    required String primaryLocation, // e.g., "(lon,lat)"
    required String interest,
    File? logo, // Optional logo file
  }) async {
    try {
      final fields = {
        'name': name,
        'primary_location': primaryLocation,
        'interest': interest,
      };
      if (description != null && description.isNotEmpty) {
        fields['description'] = description;
      }

      List<http.MultipartFile>? files;
      if (logo != null) {
        files = [await http.MultipartFile.fromPath('logo', logo.path)];
      }

      // Use multipart request to handle optional logo upload
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.communitiesBase,
        token: token, // Auth token is required
        fields: fields,
        files: files,
      );
      return response as Map<String, dynamic>; // Expects created CommunityDisplay
    } catch (e) {
      print("CommunityService: Failed to create community '$name' - $e");
      rethrow;
    }
  }

  /// Joins the current user to a specific community.
  Future<void> joinCommunity(int communityId, String token) async {
    try {
      await _apiClient.post(
        ApiEndpoints.communityJoin(communityId),
        token: token,
        // No request body needed for this POST based on backend router
      );
      // Expects 200 OK, _handleResponse returns null or simple message map
    } catch (e) {
      print("CommunityService: Failed to join community $communityId - $e");
      rethrow;
    }
  }

  /// Makes the current user leave a specific community.
  Future<void> leaveCommunity(int communityId, String token) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.communityLeave(communityId),
        token: token,
      );
      // Expects 200 OK, _handleResponse returns null or simple message map
    } catch (e) {
      print("CommunityService: Failed to leave community $communityId - $e");
      rethrow;
    }
  }

  /// Deletes a community (requires ownership).
  Future<void> deleteCommunity(int communityId, String token) async {
     try {
      await _apiClient.delete(
        ApiEndpoints.communityBaseId(communityId), // Use base ID endpoint for DELETE
        token: token,
      );
      // Expects 204 No Content, _handleResponse returns null
    } catch (e) {
      print("CommunityService: Failed to delete community $communityId - $e");
      rethrow;
    }
  }

  // --- Community Post Management ---

  /// Adds an existing post to a community.
  Future<void> addPostToCommunity({
    required int communityId,
    required int postId,
    required String token,
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.communityAddPost(communityId, postId),
        token: token,
        // No request body typically needed
      );
      // Expects 201 Created, _handleResponse returns simple message map or null
    } catch (e) {
      print("CommunityService: Failed to add post $postId to community $communityId - $e");
      rethrow;
    }
  }

  /// Removes a post from a community.
  Future<void> removePostFromCommunity({
    required int communityId,
    required int postId,
    required String token,
  }) async {
     try {
      await _apiClient.delete(
        ApiEndpoints.communityRemovePost(communityId, postId),
        token: token,
      );
      // Expects 200 OK, _handleResponse returns simple message map or null
    } catch (e) {
      print("CommunityService: Failed to remove post $postId from community $communityId - $e");
      rethrow;
    }
  }

  // Note: Creating/Listing events within a community are handled by EventService
  // but use endpoints defined under community paths in ApiEndpoints.
  // Example: EventService.createCommunityEvent(communityId: ...) calls
  // apiClient.multipartRequest('POST', ApiEndpoints.communityCreateEvent(communityId), ...)
}
