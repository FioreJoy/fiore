import '../api_client.dart';
import '../api_endpoints.dart';
// Import specific settings models if you create them (e.g., NotificationSettings)

/// Service responsible for fetching and updating user settings.
class SettingsService {
  final ApiClient _apiClient;

  SettingsService(this._apiClient);

  /// Fetches the user's notification settings.
  /// Requires authentication token and API Key.
  /// Returns a Map representing the settings structure.
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      // Assuming a GET request retrieves the settings object
      final response = await _apiClient.get(
        ApiEndpoints.notificationSettings, // Adjust endpoint if different
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print("SettingsService: Failed to fetch notification settings - $e");
      rethrow;
    }
  }

  /// Updates the user's notification settings.
  /// Requires authentication token and API Key.
  /// [settings] should be a Map matching the backend's expected format (e.g., {'email_on_reply': true}).
  Future<void> updateNotificationSettings({
    required Map<String, dynamic> settings,
  }) async {
    try {
      // Assuming a PUT request updates the settings
      await _apiClient.put(
        ApiEndpoints.notificationSettings, // Adjust endpoint if different
        body: settings,
      );
      // Expects 200 OK or 204 No Content on success
    } catch (e) {
      print("SettingsService: Failed to update notification settings - $e");
      rethrow;
    }
  }

// --- Add methods for other settings sections as needed ---
// Example: Privacy Settings
// Future<Map<String, dynamic>> getPrivacySettings() async { ... }
// Future<void> updatePrivacySettings({required Map<String, dynamic> settings}) async { ... }

// Example: Account Preferences
// Future<Map<String, dynamic>> getAccountPreferences() async { ... }
// Future<void> updateAccountPreferences({required Map<String, dynamic> settings}) async { ... }
}
