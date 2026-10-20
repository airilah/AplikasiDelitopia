import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/delivery_model.dart';

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DeliveryService(apiClient);
});

class DeliveryService {
  final ApiClient _apiClient;

  DeliveryService(this._apiClient);

  /// Get delivery fee quote from Grab Express
  Future<GrabQuote> getGrabQuote(GrabQuoteRequest request) async {
    try {
      final response = await _apiClient.post(
        '/postData/grab-quotes',
        data: request.toJson());

      if (response['status'] == 'success') {
        return GrabQuote.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to get delivery quote');
    } catch (e) {
      // Return a fallback quote if API fails
      return const GrabQuote(
        amount: 15000,
        currency: 'IDR',
        estimatedTimeline: 30,
        serviceType: 'Instant',
        distance: 5.0);
    }
  }

  /// Create a delivery order with Grab Express
  Future<DeliveryOrder> createDeliveryOrder({
    required String orderId,
    required GrabQuoteRequest request,
  }) async {
    try {
      final response = await _apiClient.post(
        '/postData/grab-delivery',
        data: {
          'order_id': orderId,
          ...request.toJson(),
        });

      if (response['status'] == 'success') {
        return DeliveryOrder.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to create delivery order');
    } catch (e) {
      throw Exception('Failed to create delivery order: $e');
    }
  }

  /// Get delivery order status
  Future<DeliveryOrder> getDeliveryStatus(String orderId) async {
    try {
      final response = await _apiClient.get('/getData/delivery-status/$orderId');

      if (response['status'] == 'success') {
        return DeliveryOrder.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to get delivery status');
    } catch (e) {
      throw Exception('Failed to get delivery status: $e');
    }
  }

  /// Cancel delivery order
  Future<void> cancelDelivery(String orderId) async {
    try {
      final response = await _apiClient.post(
        '/postData/cancel-delivery',
        data: {'order_id': orderId});

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to cancel delivery');
      }
    } catch (e) {
      throw Exception('Failed to cancel delivery: $e');
    }
  }

  /// Track delivery in real-time (if available)
  Future<Map<String, dynamic>> trackDelivery(String orderId) async {
    try {
      final response = await _apiClient.get('/getData/track-delivery/$orderId');

      if (response['status'] == 'success') {
        return response['data'] as Map<String, dynamic>;
      }

      throw Exception(response['message'] ?? 'Failed to track delivery');
    } catch (e) {
      throw Exception('Failed to track delivery: $e');
    }
  }
}
