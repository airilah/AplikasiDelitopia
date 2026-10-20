import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';
import '../../../shared/models/brand_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import '../../../shared/services/service_providers.dart' show branchesProvider;

Cart _emptyCart() {
  final now = DateTime.now();
  return Cart(id: 0, userId: 0, createdAt: now, updatedAt: now);
}

// Simple independent FutureProvider — does NOT watch cartControllerProvider.
// CartController operations call ref.invalidate(cartProvider) to trigger refresh.
final cartProvider = FutureProvider<Cart>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return _emptyCart();
  }

  final cartService = ref.watch(cartServiceProvider);
  final cart = await cartService.getCart();

  // Sync local selected branch/brand state in microtask to avoid build-phase side-effects
  if (cart.branchId != null) {
    Future.microtask(() async {
      try {
        final currentBranch = ref.read(selectedBranchProvider);
        if (currentBranch?.id != cart.branchId) {
          final branches = await ref.read(branchesProvider.future);
          final matched = branches.where((b) => b.id == cart.branchId);
          if (matched.isNotEmpty) {
            final branch = matched.first;
            ref.read(selectedBranchProvider.notifier).state = branch;
            ref.read(selectedBrandProvider.notifier).state = Brand(
              id: branch.brandId,
              name: branch.brandName,
              logo: branch.brandLogo ?? '',
              service: 0,
              tax: 0,
              category: const []);
          }
        }
      } catch (_) {}
    });
  }

  return cart;
});

// Provider for cart item count (for badges)
final cartItemCountProvider = Provider<int>((ref) {
  final cartAsync = ref.watch(cartProvider);
  return cartAsync.when(
    data: (cart) => cart.itemCount,
    loading: () => 0,
    error: (_, __) => 0);
});

// Controller for cart operations
class CartController extends StateNotifier<AsyncValue<Cart>> {
  final CartService _cartService;
  final Ref _ref;

  CartController(this._cartService, this._ref) : super(const AsyncValue.loading()) {
    _loadCart();
  }

  Future<void> _loadCart() async {
    state = const AsyncValue.loading();
    try {
      final token = _ref.read(storageServiceProvider).getAuthToken();
      if (token == null || token.isEmpty) {
        state = AsyncValue.data(_emptyCart());
        return;
      }

      final cart = await _cartService.getCart();
      state = AsyncValue.data(cart);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addToCart(AddToCartRequest request) async {
    try {
      final cart = await _cartService.addToCart(request);
      state = AsyncValue.data(cart);
      // Invalidate the independent cartProvider to refresh cart UI
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateItem(int itemId, UpdateCartItemRequest request) async {
    try {
      final cart = await _cartService.updateCartItem(itemId, request);
      state = AsyncValue.data(cart);
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> removeItem(int itemId) async {
    try {
      final cart = await _cartService.removeCartItem(itemId);
      state = AsyncValue.data(cart);
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> incrementItem(int itemId, int currentQuantity) async {
    try {
      final cart = await _cartService.incrementItem(itemId, currentQuantity);
      state = AsyncValue.data(cart);
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> decrementItem(int itemId, int currentQuantity) async {
    try {
      final cart = await _cartService.decrementItem(itemId, currentQuantity);
      state = AsyncValue.data(cart);
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await _cartService.clearCart();
      state = AsyncValue.data(Cart(
        id: 0,
        userId: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [],
      ));
      _ref.invalidate(cartProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadCart();
    _ref.invalidate(cartProvider);
  }
}

// Cart controller provider
final cartControllerProvider = StateNotifierProvider<CartController, AsyncValue<Cart>>((ref) {
  final cartService = ref.watch(cartServiceProvider);
  return CartController(cartService, ref);
});
