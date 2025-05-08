// frontend/lib/services/api/community_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for community-related API calls.
class CommunityService {
  final ApiClient _apiClient;

  CommunityService(this._apiClient);

  /// Fetches a list of all communities, including counts.
  /// Auth token optional (needed for viewer join status if implemented).
  Future<List<dynamic>> getCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesBase,
        token: token,
      );
      // Backend now returns List<CommunityDisplay> with counts included
      return response as List<dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch communities - $e");
      rethrow;
    }
  }

  /// Fetches a list of trending communities, including counts.
  /// Auth token optional.
  Future<List<dynamic>> getTrendingCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesTrending,
        token: token,
      );
      // Backend now returns List<CommunityDisplay> with counts included
      return response as List<dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch trending communities - $e");
      rethrow;
    }
  }

  /// Fetches details for a specific community, including counts.
  /// Auth token optional (needed for viewer join status).
  Future<Map<String, dynamic>> getCommunityDetails(int communityId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communityDetail(communityId),
        token: token,
      );
      // Backend now returns CommunityDisplay with counts included
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch community details for ID $communityId - $e");
      rethrow;
    }
  }

  /// Creates a new community. Requires auth token.
  Future<Map<String, dynamic>> createCommunity({
    required String token,
    required String name,
    String? description,
    required String primaryLocation, // e.g., "(lon,lat)"
    String? interest, // Made optional to match backend router
    File? logo,
  }) async {
    try {
      final fields = {
        'name': name,
        'primary_location': primaryLocation,
      };
      // Only include optional fields if they have a value
      if (description != null && description.isNotEmpty) fields['description'] = description;
      if (interest != null && interest.isNotEmpty) fields['interest'] = interest;

      List<http.MultipartFile>? files;
      if (logo != null) { files = [await http.MultipartFile.fromPath('logo', logo.path)]; }

      final response = await _apiClient.multipartRequest(
        'POST', ApiEndpoints.communitiesBase, token: token, fields: fields, files: files,
      );
      // Expects created CommunityDisplay with counts
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to create community '$name' - $e");
      rethrow;
    }
  }

  /// Updates community details (excluding logo). Requires auth token (creator).
  Future<Map<String, dynamic>> updateCommunityDetails({
    required String token,
    required int communityId,
    required Map<String, String> fieldsToUpdate, // Pass only changed fields
  }) async {
    try {
      // Use PUT with JSON body for text updates
      final response = await _apiClient.put(
        ApiEndpoints.communityBaseId(communityId), // Endpoint for specific community PUT/DELETE
        token: token,
        body: fieldsToUpdate,
      );
      // Expects updated CommunityDisplay with counts
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to update details for community $communityId - $e");
      rethrow;
    }
  }

  /// Updates community logo. Requires auth token (creator).
  Future<Map<String, dynamic>> updateCommunityLogo({
    required String token,
    required int communityId,
    required File logo,
  }) async {
    try {
      // Use POST to the dedicated logo endpoint
      final files = [await http.MultipartFile.fromPath('logo', logo.path)];
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.communityUpdateLogo(communityId),
        token: token,
        fields: {}, // No extra fields needed
        files: files,
      );
      // Expects updated CommunityDisplay with counts
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to update logo for community $communityId - $e");
      rethrow;
    }
  }


  /// Joins the current user to a specific community. Requires auth token.
  Future<Map<String, dynamic>> joinCommunity(int communityId, String token) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.communityJoin(communityId), token: token,
      );
      // Expects response like {'message':..., 'success':..., 'new_counts':{...}}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to join community $communityId - $e");
      rethrow;
    }
  }

  /// Makes the current user leave a specific community. Requires auth token.
  Future<Map<String, dynamic>> leaveCommunity(int communityId, String token) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.communityLeave(communityId), token: token,
      );
      // Expects response like {'message':..., 'success':..., 'new_counts':{...}}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to leave community $communityId - $e");
      rethrow;
    }
  }

  /// Deletes a community (requires ownership). Requires auth token.
  Future<void> deleteCommunity(int communityId, String token) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.communityBaseId(communityId), token: token, // Use base ID endpoint
      );
      // Expects 204 No Content
    } catch (e) {
      print("CommunityService: Failed to delete community $communityId - $e");
      rethrow;
    }
  }

  // --- Community Post Linking ---

  /// Adds an existing post to a community. Requires auth token.
  Future<Map<String, dynamic>> addPostToCommunity({
    required int communityId, required int postId, required String token,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.communityPostLink(communityId, postId), token: token,
      );
      return response as Map<String, dynamic>; // Expects {'message': ..., 'success': ...}
    } catch (e) {
      print("CommunityService: Failed to add post $postId to community $communityId - $e");
      rethrow;
    }
  }

  /// Removes a post from a community. Requires auth token.
  Future<Map<String, dynamic>> removePostFromCommunity({
    required int communityId, required int postId, required String token,
  }) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.communityPostLink(communityId, postId), token: token,
      );
      return response as Map<String, dynamic>; // Expects {'message': ..., 'success': ...}
    } catch (e) {
      print("CommunityService: Failed to remove post $postId from community $communityId - $e");
      rethrow;
    }
  }

// Note: Listing/Creating events FOR a community uses EventService but calls
// community-scoped endpoints like ApiEndpoints.communityListEvents(id)
}