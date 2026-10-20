import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/payment_model.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentService(apiClient);
});

class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  /// Get available payment channels
  Future<List<PaymentChannel>> getPaymentChannels() async {
    try {
      final response = await _apiClient.get('/payment-channels');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        return data
            .map((json) => PaymentChannel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception(response['message'] ?? 'Failed to get payment channels');
    } catch (e) {
      // Return default payment channels if API fails
      return [
        PaymentChannel(
          id: 1,
          name: 'E-Smartlink',
          type: 'gateway',
          methods: [
            PaymentMethod(code: 'VA_BRI', name: 'BRI Virtual Account', fee: 4000),
            PaymentMethod(code: 'VA_BCA', name: 'BCA Virtual Account', fee: 4000),
            PaymentMethod(code: 'VA_MANDIRI', name: 'Mandiri Virtual Account', fee: 4000),
            PaymentMethod(code: 'QRIS', name: 'QRIS', fee: 0),
          ],
        ),
        PaymentChannel(
          id: 2,
          name: 'Cash',
          type: 'manual',
        ),
      ];
    }
  }

  /// Create E-Smartlink payment
  Future<PaymentResponse> createPayment(CreatePaymentRequest request) async {
    try {
      final response = await _apiClient.post(
        '/esmartlink/create-payment',
        data: request.toJson());

      if (response['status'] == 'success') {
        return PaymentResponse.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to create payment');
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Check payment status
  Future<PaymentInquiry> checkPaymentStatus(String orderId) async {
    try {
      final response =
          await _apiClient.get('/postData/payment-inquiry/$orderId');

      if (response['status'] == 'success' && response['data'] != null) {
        return PaymentInquiry.fromJson(response['data']);
      }
    } catch (_) {}

    // Fallback 1: order-detail endpoint
    try {
      final response = await _apiClient.get('/postData/order-detail/$orderId');
      if (response['status'] == 'success' && response['data'] != null) {
        return PaymentInquiry.fromJson(response['data']);
      }
    } catch (_) {}

    // Fallback 2: v2 orders endpoint
    try {
      final response = await _apiClient.get('/v2/orders/$orderId');
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return PaymentInquiry.fromJson(data);
      }
    } catch (_) {}

    throw Exception('Failed to check payment status for $orderId');
  }

  /// Cancel payment
  Future<void> cancelPayment(String transactionId) async {
    try {
      final response = await _apiClient.post(
        '/esmartlink/cancel/$transactionId',
        data: {});

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to cancel payment');
      }
    } catch (e) {
      throw Exception('Failed to cancel payment: $e');
    }
  }
}
