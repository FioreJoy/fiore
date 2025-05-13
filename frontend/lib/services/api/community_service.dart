// frontend/lib/services/api/community_service.dart

import 'dart:io'; // For File type
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for community-related API calls.
class CommunityService {
  final ApiClient _apiClient;

  CommunityService(this._apiClient);

  Future<List<dynamic>> getCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesBase,
        token: token,
      );
      return response as List<dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch communities - $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getTrendingCommunities({String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communitiesTrending,
        token: token,
      );
      return response as List<dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch trending communities - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCommunityDetails(int communityId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.communityDetail(communityId),
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to fetch community details for ID $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCommunity({
    required String token,
    required String name,
    String? description,
    required String primaryLocation,
    String? interest,
    File? logo,
  }) async {
    try {
      final fields = {
        'name': name,
        'primary_location': primaryLocation,
      };
      if (description != null && description.isNotEmpty) fields['description'] = description;
      if (interest != null && interest.isNotEmpty) fields['interest'] = interest;

      List<http.MultipartFile>? files;
      if (logo != null) { files = [await http.MultipartFile.fromPath('logo', logo.path)]; }

      final response = await _apiClient.multipartRequest(
        'POST', ApiEndpoints.communitiesBase, token: token, fields: fields, files: files,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to create community '$name' - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCommunityDetails({
    required String token,
    required int communityId,
    required Map<String, String> fieldsToUpdate,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.communityBaseId(communityId),
        token: token,
        body: fieldsToUpdate,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to update details for community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCommunityLogo({
    required String token,
    required int communityId,
    required File logo,
  }) async {
    try {
      final files = [await http.MultipartFile.fromPath('logo', logo.path)];
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.communityUpdateLogo(communityId),
        token: token,
        fields: {},
        files: files,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to update logo for community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinCommunity(int communityId, String token) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.communityJoin(communityId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to join community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> leaveCommunity(int communityId, String token) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.communityLeave(communityId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to leave community $communityId - $e");
      rethrow;
    }
  }

  Future<void> deleteCommunity(int communityId, String token) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.communityBaseId(communityId), token: token,
      );
    } catch (e) {
      print("CommunityService: Failed to delete community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addPostToCommunity({
    required int communityId, required int postId, required String token,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.communityPostLink(communityId, postId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to add post $postId to community $communityId - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> removePostFromCommunity({
    required int communityId, required int postId, required String token,
  }) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.communityPostLink(communityId, postId), token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("CommunityService: Failed to remove post $postId from community $communityId - $e");
      rethrow;
    }
  }

  // --- NEW METHOD to get community members ---
  /// Fetches the list of members for a specific community.
  /// Auth token is optional but might be needed if the endpoint is protected
  /// or if viewer-specific information (like follow status of members) is returned.
  Future<List<dynamic>> getCommunityMembers(int communityId, {String? token, int limit = 50, int offset = 0}) async {
    try {
      // Assuming an endpoint like /communities/{id}/members
      // Update ApiEndpoints.dart if this new endpoint is added
      final String endpoint = '${ApiEndpoints.communityBaseId(communityId)}/members';
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final response = await _apiClient.get(
        endpoint,
        token: token,
        queryParams: queryParams,
      );
      // Expects a List of user-like objects (e.g., matching UserBase or a simpler MemberInfo schema)
      return response as List<dynamic>? ?? []; // Handle null response defensively
    } catch (e) {
      print("CommunityService: Failed to fetch members for community $communityId - $e");
      rethrow;
    }
  }
// --- END NEW METHOD ---
}