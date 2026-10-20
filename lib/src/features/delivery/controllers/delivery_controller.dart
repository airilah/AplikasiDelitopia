import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';

// Provider for delivery quote
final grabQuoteProvider = FutureProvider.family<GrabQuote, GrabQuoteRequest>(
  (ref, request) async {
    final service = ref.read(deliveryServiceProvider);
    return service.getGrabQuote(request);
  });

// Provider for delivery order status
final deliveryStatusProvider = FutureProvider.family<DeliveryOrder, String>(
  (ref, orderId) async {
    final service = ref.read(deliveryServiceProvider);
    return service.getDeliveryStatus(orderId);
  });

// Controller for delivery operations
class DeliveryController extends StateNotifier<AsyncValue<DeliveryOrder?>> {
  final DeliveryService _deliveryService;
  final Ref _ref;

  DeliveryController(this._deliveryService, this._ref) 
      : super(const AsyncValue.data(null));

  Future<DeliveryOrder> createDeliveryOrder({
    required String orderId,
    required GrabQuoteRequest request,
  }) async {
    state = const AsyncValue.loading();
    try {
      final order = await _deliveryService.createDeliveryOrder(
        orderId: orderId,
        request: request);
      state = AsyncValue.data(order);
      
      // Invalidate delivery status to refresh
      _ref.invalidate(deliveryStatusProvider(orderId));
      
      return order;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> cancelDelivery(String orderId) async {
    try {
      await _deliveryService.cancelDelivery(orderId);
      
      // Refresh delivery status
      _ref.invalidate(deliveryStatusProvider(orderId));
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> trackDelivery(String orderId) async {
    try {
      return await _deliveryService.trackDelivery(orderId);
    } catch (e) {
      rethrow;
    }
  }
}

final deliveryControllerProvider = StateNotifierProvider<DeliveryController, AsyncValue<DeliveryOrder?>>(
  (ref) {
    final service = ref.watch(deliveryServiceProvider);
    return DeliveryController(service, ref);
  });
