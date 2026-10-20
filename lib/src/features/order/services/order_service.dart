import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/order_model.dart';

final orderServiceProvider = Provider<OrderService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderService(apiClient);
});

class OrderService {
  final ApiClient _apiClient;

  OrderService(this._apiClient);

  List<Order> _sortNewestFirst(Iterable<Order> orders) {
    final sorted = orders.toList();
    sorted.sort((a, b) {
      final bDate = b.updatedAt ?? b.createdAt;
      final aDate = a.updatedAt ?? a.createdAt;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  /// Create a new order
  Future<CreateOrderResponse> createOrder(CreateOrderRequest request) async {
    try {
      final response = await _apiClient.post(
        '/postData/order',
        data: request.toJson());

      if (response['status'] == 'success' || (response['data'] != null && response['data']['order_id'] != null)) {
        return CreateOrderResponse.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to create order');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get order history for a user (all orders including expired/failed)
  Future<List<Order>> getOrderHistory(int userId) async {
    try {
      // Request all orders for the user
      final response = await _apiClient.post(
        '/getData/historyOrder',
        data: {
          'user_id': userId,
          'type': 'user',
        });

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        final List<dynamic> allOrders = [];
        for (var item in data) {
          if (item is Map<String, dynamic> && item.containsKey('orders') && item['orders'] is List) {
            allOrders.addAll(item['orders'] as List);
          } else {
            allOrders.add(item);
          }
        }
        final list = <Order>[];
        for (var raw in allOrders) {
          if (raw is Map<String, dynamic>) {
            try {
              list.add(Order.fromJson(raw));
            } catch (err) {
              // skip malformed order
            }
          }
        }
        return _sortNewestFirst(list.where((order) => order.isTerminal));
      }

      // Return empty list if no orders found (not an error)
      if (response['status'] == 'error' && 
          (response['message']?.toString().contains('No orders found') == true ||
           response['message']?.toString().contains('Server Error') == true)) {
        return [];
      }

      throw Exception(response['message'] ?? 'Failed to get order history');
    } catch (e) {
      // Return empty list instead of throwing error for 404/no orders/server error
      if (e.toString().contains('No orders found') || 
          e.toString().contains('404') || 
          e.toString().contains('Server Error') ||
          e.toString().contains('500')) {
        return [];
      }
      throw Exception('Failed to get order history: $e');
    }
  }

  /// Get order details by order ID
  Future<Order> getOrderDetails(String orderId) async {
    try {
      // URL encode the orderId to handle special characters like dashes
      final encodedOrderId = Uri.encodeComponent(orderId);
      
      // Use the new dedicated order detail endpoint
      final response = await _apiClient.get('/postData/order-detail/$encodedOrderId');

      if (response['status'] == 'success') {
        return Order.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to get order details');
    } catch (e) {
      throw Exception('Failed to get order details: $e');
    }
  }

  /// Cancel an order
  Future<void> cancelOrder(int orderId, String reason) async {
    try {
      final response = await _apiClient.post(
        '/v2/orders/$orderId/cancel',
        data: {'reason': reason});

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to cancel order');
      }
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Complete an order (Pesanan Diterima)
  Future<void> completeOrder(String orderId) async {
    try {
      final response = await _apiClient.post(
        '/postData/order-complete',
        data: {
          'order_id': orderId,
        },
      );

      if (response['status'] != 'success' && response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to complete order');
      }
    } catch (e) {
      throw Exception('Failed to complete order: $e');
    }
  }

  /// Reorder (create new order from previous order)
  Future<CreateOrderResponse> reorder(int orderId) async {
    try {
      final response = await _apiClient.post(
        '/orders/$orderId/reorder',
        data: {});

      if (response['status'] == 'success') {
        return CreateOrderResponse.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to reorder');
    } catch (e) {
      throw Exception('Failed to reorder: $e');
    }
  }

  /// Get active orders (pending, preparing, ready)
  Future<List<Order>> getActiveOrders(int userId) async {
    try {
      // Request all orders for the user
      final response = await _apiClient.post(
        '/getData/historyOrder',
        data: {
          'user_id': userId,
          'type': 'user',
        });

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        final List<dynamic> allOrders = [];
        for (var item in data) {
          if (item is Map<String, dynamic> && item.containsKey('orders') && item['orders'] is List) {
            allOrders.addAll(item['orders'] as List);
          } else {
            allOrders.add(item);
          }
        }
        final list = <Order>[];
        for (var raw in allOrders) {
          if (raw is Map<String, dynamic>) {
            try {
              list.add(Order.fromJson(raw));
            } catch (err) {
              // skip malformed order
            }
          }
        }
        return _sortNewestFirst(list.where((order) => order.isActive));
      }

      // Return empty list if no orders found
      return [];
    } catch (e) {
      // Return empty list for no orders found/server error
      if (e.toString().contains('No orders found') || 
          e.toString().contains('404') || 
          e.toString().contains('Server Error') ||
          e.toString().contains('500')) {
        return [];
      }
      throw Exception('Failed to get active orders: $e');
    }
  }

  /// Get completed orders
  Future<List<Order>> getCompletedOrders(int userId) async {
    try {
      // Request all orders specifically for the user
      final response = await _apiClient.post(
        '/getData/historyOrder',
        data: {
          'user_id': userId,
          'type': 'user',
        });

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        final List<dynamic> allOrders = [];
        for (var item in data) {
          if (item is Map<String, dynamic> && item.containsKey('orders') && item['orders'] is List) {
            allOrders.addAll(item['orders'] as List);
          } else {
            allOrders.add(item);
          }
        }
        final list = <Order>[];
        for (var raw in allOrders) {
          if (raw is Map<String, dynamic>) {
            try {
              list.add(Order.fromJson(raw));
            } catch (err) {
              // skip malformed order
            }
          }
        }
        return _sortNewestFirst(list.where((order) => order.isTerminal || !order.isActive));
      }

      // Return empty list if no orders found
      return [];
    } catch (e) {
      // Return empty list for no orders found/server error
      if (e.toString().contains('No orders found') || 
          e.toString().contains('404') || 
          e.toString().contains('Server Error') ||
          e.toString().contains('500')) {
        return [];
      }
      throw Exception('Failed to get completed orders: $e');
    }
  }
}
