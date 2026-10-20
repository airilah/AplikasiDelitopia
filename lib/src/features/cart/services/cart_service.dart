import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/cart_model.dart';

final cartServiceProvider = Provider<CartService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CartService(apiClient);
});

class CartService {
  final ApiClient _apiClient;

  CartService(this._apiClient);

  /// Get current user's cart
  Future<Cart> getCart() async {
    try {
      final response = await _apiClient.get('/cart');

      if (response['status'] == 'success') {
        // If cart data is null or empty, return an empty cart
        if (response['data'] == null) {
          return Cart(
            id: 0,
            userId: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            items: []);
        }
        return Cart.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to get cart');
    } catch (e) {
      throw Exception('Failed to get cart: $e');
    }
  }

  /// Add item to cart
  Future<Cart> addToCart(AddToCartRequest request) async {
    try {
      final requestData = request.toJson();
      debugPrint('🛒 Adding to cart - Request data: $requestData');
      
      final response = await _apiClient.post(
        '/cart/add',
        data: requestData);

      debugPrint('🛒 Add to cart response: $response');

      if (response['status'] == 'success') {
        return await getCart();
      }

      throw Exception(response['message'] ?? 'Failed to add to cart');
    } catch (e) {
      debugPrint('❌ Add to cart error: $e');
      throw Exception('Failed to add to cart: $e');
    }
  }

  /// Update cart item quantity
  Future<Cart> updateCartItem(int itemId, UpdateCartItemRequest request) async {
    try {
      final response = await _apiClient.put(
        '/cart/item/$itemId',
        data: request.toJson());

      if (response['status'] == 'success') {
        return await getCart();
      }

      throw Exception(response['message'] ?? 'Failed to update cart item');
    } catch (e) {
      throw Exception('Failed to update cart item: $e');
    }
  }

  /// Remove item from cart
  Future<Cart> removeCartItem(int itemId) async {
    try {
      final response = await _apiClient.delete('/cart/item/$itemId');

      if (response['status'] == 'success') {
        return await getCart();
      }

      throw Exception(response['message'] ?? 'Failed to remove cart item');
    } catch (e) {
      throw Exception('Failed to remove cart item: $e');
    }
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    try {
      final response = await _apiClient.delete('/cart/clear');

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to clear cart');
      }
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }

  /// Increment item quantity
  Future<Cart> incrementItem(int itemId, int currentQuantity) async {
    return updateCartItem(
      itemId,
      UpdateCartItemRequest(quantity: currentQuantity + 1));
  }

  /// Decrement item quantity (removes if quantity becomes 0)
  Future<Cart> decrementItem(int itemId, int currentQuantity) async {
    if (currentQuantity <= 1) {
      return removeCartItem(itemId);
    }
    return updateCartItem(
      itemId,
      UpdateCartItemRequest(quantity: currentQuantity - 1));
  }
}
