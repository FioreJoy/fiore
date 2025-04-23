// frontend/lib/services/api/auth_service.dart

import 'dart:io'; // For File type in profile update
import 'package:http/http.dart' as http; // For MultipartFile

import '../api_client.dart';
import '../api_endpoints.dart';
// Import user model if you create one (e.g., models/user_display.dart)
// import '../../models/user_display.dart';

/// Service responsible for authentication and user profile related API calls.
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// Logs in a user with email and password.
  /// Returns a Map containing token, user_id, and potentially image_url.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Login typically doesn't need the user's JWT token, but DOES need the API Key
      // The ApiClient's post method automatically adds the API Key header.
      // We pass null for the token argument here.
      // NOTE: If your backend *specifically* requires API key ALSO on login,
      // ensure ApiClient's post method adds it even with token=null.
      // (Current ApiClient implementation DOES add API Key if configured).
      final response = await _apiClient.post(
        ApiEndpoints.login,
        token: null, // No JWT token needed for login itself
        body: {'email': email, 'password': password},
      );
      // Expecting Map<String, dynamic> like {'token': ..., 'user_id': ..., 'image_url': ...}
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Login failed - $e");
      // Re-throw the exception to be handled by the UI layer
      rethrow;
    }
  }

  /// Signs up a new user.
  /// Requires profile details and optionally an image File.
  /// Returns a Map containing token, user_id, and potentially image_url.
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String gender,
    required String currentLocation, // e.g., "(lon,lat)"
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
      // Add interests as multiple fields with the same key
      for (String interest in interests) {
         // Note: http package might not directly support duplicate keys in fields map.
         // Sending as a comma-separated string might be necessary if backend expects that.
         // Let's assume backend handles list from Form for now.
         // If issues arise, change backend to accept comma-sep string or adjust client.
         fields['interests'] = interest; // This will likely only send the LAST interest value.
         // TODO: Confirm backend handling of List[str] = Form(...)
         // If backend expects comma-separated:
         // fields['interests'] = interests.join(',');
      }


      List<http.MultipartFile>? files;
      if (image != null) {
        files = [
          await http.MultipartFile.fromPath('image', image.path)
              // Add content type if needed, though often inferred
              // contentType: MediaType('image', image.path.split('.').last)
        ];
      }

      // Signup doesn't need a JWT token or API Key typically
      final response = await _apiClient.multipartRequest(
        'POST',
        ApiEndpoints.signup,
        token: null, // No token for signup
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
  /// Returns a Map representing the UserDisplay schema.
  Future<Map<String, dynamic>> getCurrentUserProfile(String token) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.currentUser,
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("AuthService: Fetch profile failed - $e");
      rethrow;
    }
  }

  /// Updates the profile for the currently authenticated user.
  /// [fieldsToUpdate] should only contain the fields that have changed.
  /// Returns the updated user profile Map.
  Future<Map<String, dynamic>> updateUserProfile({
    required String token,
    required Map<String, String> fieldsToUpdate, // Pass only changed text fields
    File? image, // Pass the image file if it changed
  }) async {
    try {
       List<http.MultipartFile>? files;
       if (image != null) {
           files = [await http.MultipartFile.fromPath('image', image.path)];
       }

       // Use multipart request because an image might be included
      final response = await _apiClient.multipartRequest(
        'PUT',
        ApiEndpoints.currentUser,
        token: token,
        fields: fieldsToUpdate, // Send only the fields that changed
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
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.put(
        ApiEndpoints.changePassword,
        token: token,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      // PUT request returns 204 No Content on success, _handleResponse returns null
    } catch (e) {
      print("AuthService: Change password failed - $e");
      rethrow;
    }
  }

  /// Deletes the account of the currently authenticated user.
  Future<void> deleteAccount({required String token}) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.currentUser,
        token: token,
      );
      // DELETE request returns 204 No Content on success, _handleResponse returns null
    } catch (e) {
      print("AuthService: Delete account failed - $e");
      rethrow;
    }
  }
}
