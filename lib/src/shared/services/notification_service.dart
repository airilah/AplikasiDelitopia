import '../../core/services/api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Get all notifications
  /// GET /getData/notification
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _apiClient.get('/getData/notification');

      List<dynamic> rawList = [];
      if (response['data'] is List) {
        rawList = response['data'] as List<dynamic>;
      } else if (response['data'] is Map && response['data']['data'] is List) {
        rawList = response['data']['data'] as List<dynamic>;
      } else if (response['notifications'] is List) {
        rawList = response['notifications'] as List<dynamic>;
      } else if (response is List) {
        rawList = response as List<dynamic>;
      }

      return rawList
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get notification details
  /// GET /getData/notification-show/{id}
  Future<NotificationModel> getNotificationDetails(int id) async {
    try {
      final response = await _apiClient.get('/getData/notification-show/$id');

      if (response['message'] != null) {
        return NotificationModel.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception('Failed to load notification details');
    } catch (e) {
      throw Exception('Failed to load notification details: $e');
    }
  }

  /// Delete notification by id
  /// DELETE /notifications/{id}
  Future<void> deleteNotification(int id) async {
    try {
      await _apiClient.delete('/notifications/$id');
    } catch (_) {}
  }
}
