import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

// Payment channels provider
final paymentChannelsProvider = FutureProvider<List<PaymentChannel>>((ref) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getPaymentChannels();
});

// Payment inquiry provider
final paymentInquiryProvider =
    FutureProvider.family<PaymentInquiry, String>((ref, transactionId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.checkPaymentStatus(transactionId);
});

// Payment controller for creating payments
class PaymentController extends StateNotifier<AsyncValue<PaymentResponse?>> {
  final PaymentService _paymentService;

  PaymentController(this._paymentService)
      : super(const AsyncValue.data(null));

  Future<PaymentResponse> createPayment(CreatePaymentRequest request) async {
    state = const AsyncValue.loading();
    try {
      final response = await _paymentService.createPayment(request);
      state = AsyncValue.data(response);
      return response;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<PaymentInquiry> checkStatus(String transactionId) async {
    try {
      return await _paymentService.checkPaymentStatus(transactionId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelPayment(String transactionId) async {
    try {
      await _paymentService.cancelPayment(transactionId);
    } catch (e) {
      rethrow;
    }
  }
}

final paymentControllerProvider =
    StateNotifierProvider<PaymentController, AsyncValue<PaymentResponse?>>((ref) {
  final paymentService = ref.watch(paymentServiceProvider);
  return PaymentController(paymentService);
});
