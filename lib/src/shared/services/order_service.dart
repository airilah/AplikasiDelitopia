import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_client.dart';
import '../models/order_model.dart';

// Provider for OrderService
final orderServiceProvider = Provider<OrderService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderService(apiClient);
});

class OrderService {
  final ApiClient _apiClient;

  OrderService(this._apiClient);

  /// Create order
  /// POST /postData/order
  Future<Map<String, dynamic>> createOrder(Order order) async {
    try {
      final response = await _apiClient.post(
        '/postData/order',
        data: order.toJson());
      return response;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Create order with delivery fee
  /// POST /postData/order-new
  Future<Map<String, dynamic>> createOrderWithDelivery(Order order) async {
    try {
      final response = await _apiClient.post(
        '/postData/order-new',
        data: order.toJson());
      return response;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get order history
  /// POST /getData/historyOrder
  /// 
  /// [type] - Either "status" or "order_id"
  /// [status] - Either "pending" or "success"  
  Future<List<Order>> getOrders({
    required int userId,
    required String type, // 'status' or 'order_id'
    String? status, // 'pending' or 'success'
    String? orderId,
  }) async {
    try {
      final data = {
        'user_id': userId.toString(),
        'type': type,
        if (status != null) 'status': status,
        if (orderId != null) 'order_id': orderId,
      };

      final response = await _apiClient.post(
        '/getData/historyOrder',
        data: data);

      if (response['status'] == 'success') {
        final responseData = response['data'] as List;
        
        // If grouped by date (for status=success)
        if (responseData.isNotEmpty && 
            responseData.first is Map && 
            responseData.first.containsKey('date') && 
            responseData.first.containsKey('orders')) {
          final allOrders = <Order>[];
          for (var group in responseData) {
            final orders = (group['orders'] as List)
                .map((json) => Order.fromJson(json as Map<String, dynamic>))
                .toList();
            allOrders.addAll(orders);
          }
          return allOrders;
        }
        
        // Otherwise, flat list
        return responseData.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get orders: $e');
    }
  }

  /// Get pending orders
  Future<List<Order>> getPendingOrders(int userId) async {
    return getOrders(userId: userId, type: 'status', status: 'pending');
  }

  /// Get completed orders
  Future<List<Order>> getCompletedOrders(int userId) async {
    return getOrders(userId: userId, type: 'status', status: 'success');
  }

  /// Get specific order by ID
  Future<Order?> getOrderById(int userId, String orderId) async {
    final orders = await getOrders(
      userId: userId,
      type: 'order_id',
      orderId: orderId);
    return orders.isNotEmpty ? orders.first : null;
  }

  /// Mark order as paid
  /// POST /postData/order-paid
  Future<bool> markOrderAsPaid(String orderId) async {
    try {
      final response = await _apiClient.post(
        '/postData/order-paid',
        data: {'order_id': orderId});
      return response['status'] == 'success';
    } catch (e) {
      throw Exception('Failed to mark order as paid: $e');
    }
  }

  /// Update order status
  /// POST /postData/order-status
  /// 
  /// [status] - Either "paid" or "completed"
  /// Valid transitions: pending → paid/completed, paid → completed
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _apiClient.post(
        '/postData/order-status',
        data: {
          'order_id': orderId,
          'status': status,
        });
      return response['status'] == 'success';
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Get point history
  /// POST /getData/historyPoint
  Future<List<PointHistory>> getPointHistory(int userId) async {
    try {
      final response = await _apiClient.post(
        '/getData/historyPoint',
        data: {'user_id': userId.toString()});

      if (response['status'] == 'success') {
        final data = response['data'] as List;
        return data.map((json) => PointHistory.fromJson(json as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to get point history: $e');
    }
  }

  /// Calculate points from grand total
  /// Points = floor(grand_total / 10000)
  int calculatePoints(double grandTotal) {
    return (grandTotal / 10000).floor();
  }

  /// Get total valid points
  Future<int> getTotalValidPoints(int userId) async {
    final pointHistory = await getPointHistory(userId);
    return pointHistory.fold<int>(
      0,
      (sum, history) => sum + int.parse(history.point));
  }
}

