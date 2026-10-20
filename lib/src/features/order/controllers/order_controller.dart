import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/services/service_providers.dart';
import '../../voucher/controllers/voucher_controller.dart' as vouchers;

// Provider for order history
final orderHistoryProvider = FutureProvider.family<List<Order>, int>((ref, userId) async {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getOrderHistory(userId);
});

// Provider for active orders
final activeOrdersProvider = FutureProvider.family<List<Order>, int>((ref, userId) async {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getActiveOrders(userId);
});

// Provider for completed orders
final completedOrdersProvider = FutureProvider.family<List<Order>, int>((ref, userId) async {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getCompletedOrders(userId);
});

// Provider for single order details
final orderDetailsProvider = FutureProvider.family<Order, String>((ref, orderId) async {
  final orderService = ref.watch(orderServiceProvider);
  return orderService.getOrderDetails(orderId);
});

// Controller for order operations
class OrderController extends StateNotifier<AsyncValue<CreateOrderResponse?>> {
  final OrderService _orderService;
  final Ref _ref;

  OrderController(this._orderService, this._ref) : super(const AsyncValue.data(null));

  Future<CreateOrderResponse> createOrder(CreateOrderRequest request) async {
    state = const AsyncValue.loading();
    try {
      final response = await _orderService.createOrder(request);
      state = AsyncValue.data(response);
      
      // Invalidate order history to refresh
      _ref.invalidate(orderHistoryProvider(request.userId));
      _ref.invalidate(activeOrdersProvider(request.userId));
      _refreshPoints();
      
      return response;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> cancelOrder(int orderId, int userId, [String reason = 'Dibatalkan oleh pengguna']) async {
    try {
      await _orderService.cancelOrder(orderId, reason);
      
      // Refresh order history
      _ref.invalidate(orderHistoryProvider(userId));
      _ref.invalidate(activeOrdersProvider(userId));
      _ref.invalidate(completedOrdersProvider(userId));
      _refreshPoints();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> completeOrder(String orderId, int userId) async {
    try {
      await _orderService.completeOrder(orderId);
      
      // Refresh order history
      _ref.invalidate(orderHistoryProvider(userId));
      _ref.invalidate(activeOrdersProvider(userId));
      _ref.invalidate(completedOrdersProvider(userId));
      _refreshPoints();
    } catch (e) {
      rethrow;
    }
  }

  Future<CreateOrderResponse> reorder(int orderId) async {
    state = const AsyncValue.loading();
    try {
      final response = await _orderService.reorder(orderId);
      state = AsyncValue.data(response);
      
      // Invalidate order history to refresh
      final userId = await _ref.read(currentUserIdProvider.future);
      if (userId != null) {
        _ref.invalidate(orderHistoryProvider(userId));
        _ref.invalidate(activeOrdersProvider(userId));
      }
      _refreshPoints();
      
      return response;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }

  void _refreshPoints() {
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(vouchers.userPointsProvider);
    _ref.invalidate(vouchers.pointsHistoryProvider);
  }
}

// Order controller provider
final orderControllerProvider = StateNotifierProvider<OrderController, AsyncValue<CreateOrderResponse?>>((ref) {
  final orderService = ref.watch(orderServiceProvider);
  return OrderController(orderService, ref);
});

// Helper provider to get current user ID
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  final storageService = ref.watch(storageServiceProvider);
  final token = storageService.getAuthToken();
  if (token == null || token.isEmpty) {
    return null;
  }

  final user = await ref.watch(currentUserProvider.future);
  if (user != null && user.id > 0) {
    await storageService.saveUserId(user.id);
    return user.id;
  }

  final storedUserId = await storageService.getUserId();
  if (storedUserId != null && storedUserId > 0) {
    return storedUserId;
  }

  return null;
});
