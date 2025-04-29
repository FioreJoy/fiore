// frontend/lib/services/api/auth_service.dart

import 'dart:io'; // For File type in profile update
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';

/// Service responsible for authentication and user profile related API calls.
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// Logs in a user with email and password.
  /// Returns a Map containing token, user_id, and potentially image_url.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Login doesn't need the token, ApiClient handles it automatically
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Login failed - $e");
      rethrow;
    }
  }

  /// Signs up a new user.
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String gender,
    required String currentLocation,
    required String college,
    required List<String> interests,
    File? image,
  }) async {
    try {
      final fields = {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'gender': gender,
        'current_location': currentLocation,
        'college': college,
      };

      // Add interests
      for (String interest in interests) {
        fields['interests'] = interest;
      }

      List<http.MultipartFile>? files;
      if (image != null) {
        files = [
          await http.MultipartFile.fromPath('image', image.path)
        ];
      }

      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.signup,
        fields: fields,
        files: files,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Signup failed - $e");
      rethrow;
    }
  }

  /// Fetches the profile data for the currently authenticated user.
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.currentUser);
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Fetch profile failed - $e");
      rethrow;
    }
  }

  /// Updates the profile for the currently authenticated user.
  Future<Map<String, dynamic>> updateUserProfile({
    required Map<String, String> fieldsToUpdate,
    File? image,
  }) async {
    try {
      List<http.MultipartFile>? files;
      if (image != null) {
        files = [await http.MultipartFile.fromPath('image', image.path)];
      }

      final response = await _apiClient.multipartRequest(
        'PUT',
        ApiEndpoints.currentUser,
        fields: fieldsToUpdate,
        files: files,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Update profile failed - $e");
      rethrow;
    }
  }

  /// Changes the password for the currently authenticated user.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.put(
        ApiEndpoints.changePassword,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      print("AuthService: Change password failed - $e");
      rethrow;
    }
  }

  /// Deletes the account of the currently authenticated user.
  Future<void> deleteAccount() async {
    try {
      await _apiClient.delete(ApiEndpoints.currentUser);
    } catch (e) {
      print("AuthService: Delete account failed - $e");
      rethrow;
    }
  }
}
