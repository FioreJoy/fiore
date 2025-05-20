// frontend/lib/services/api/notification_service.dart

import './api_client.dart';
import './api_endpoints.dart'; // This import allows access to ApiEndpoints.staticMember

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  Future<List<dynamic>> getNotifications({
    required String token,
    int limit = 20,
    int offset = 0,
    bool? unreadOnly,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (unreadOnly != null) {
        queryParams['unread_only'] = unreadOnly.toString();
      }
      final response = await _apiClient.get(
        ApiEndpoints.notificationsBase, // Corrected: ClassName.staticMember
        token: token,
        queryParams: queryParams,
      );
      return response as List<dynamic>? ?? [];
    } catch (e) {
      //print("NotificationService: Failed to fetch notifications - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUnreadNotificationCount({
    required String token,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.notificationsUnreadCount, // Corrected
        token: token,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      //print("NotificationService: Failed to fetch unread notification count - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> markNotificationsRead({
    required String token,
    required List<int> notificationIds,
    bool isRead = true,
  }) async {
    try {
      final body = {
        'notification_ids': notificationIds,
        'is_read': isRead,
      };
      final response = await _apiClient.post(
        ApiEndpoints.notificationsRead, // Corrected
        token: token,
        body: body,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      //print("NotificationService: Failed to mark notifications as read/unread - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> markAllNotificationsRead({
    required String token,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.notificationsReadAll, // Corrected
        token: token,
        body: {},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      //print("NotificationService: Failed to mark all notifications as read - $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerDeviceToken({
    required String token,
    required String deviceToken,
    required String platform,
  }) async {
    try {
      final body = {
        'device_token': deviceToken,
        'platform': platform,
      };
      final response = await _apiClient.post(
        ApiEndpoints.notificationsDeviceTokens, // Corrected
        token: token,
        body: body,
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      //print("NotificationService: Failed to register device token - $e");
      rethrow;
    }
  }

  Future<void> unregisterDeviceToken({
    required String token,
    required String deviceToken,
  }) async {
    try {
      final queryParams = {'device_token': deviceToken};
      await _apiClient.delete(
        ApiEndpoints.notificationsDeviceTokens, // Corrected
        token: token,
        queryParams: queryParams,
      );
    } catch (e) {
      //print("NotificationService: Failed to unregister device token - $e");
      rethrow;
    }
  }
}
