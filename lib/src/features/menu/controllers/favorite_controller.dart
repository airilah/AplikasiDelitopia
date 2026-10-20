import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../models/favorite_model.dart';
import '../services/favorite_service.dart';

// Provider for all favorites
final favoritesProvider = FutureProvider<List<Favorite>>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  final favoriteService = ref.watch(favoriteServiceProvider);
  return favoriteService.getFavorites();
});

// Provider to check if a specific menu is favorited
final isFavoriteProvider = FutureProvider.family<bool, int>((ref, menuId) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return false;
  }

  final favoriteService = ref.watch(favoriteServiceProvider);
  return favoriteService.isFavorite(menuId);
});

// Controller for favorite operations
class FavoriteController extends StateNotifier<AsyncValue<List<Favorite>>> {
  final FavoriteService _favoriteService;
  final Ref _ref;

  FavoriteController(this._favoriteService, this._ref)
      : super(const AsyncValue.loading()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    state = const AsyncValue.loading();
    try {
      final token = _ref.read(storageServiceProvider).getAuthToken();
      if (token == null || token.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final favorites = await _favoriteService.getFavorites();
      state = AsyncValue.data(favorites);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addFavorite(AddFavoriteRequest request) async {
    try {
      await _favoriteService.addFavorite(request);
      await _loadFavorites();
      _ref.invalidate(favoritesProvider);
      _ref.invalidate(isFavoriteProvider(request.menuId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> removeFavorite(int menuId) async {
    try {
      await _favoriteService.removeFavorite(menuId);
      await _loadFavorites();
      _ref.invalidate(favoritesProvider);
      _ref.invalidate(isFavoriteProvider(menuId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<bool> toggleFavorite(
    int menuId,
    String menuName,
    double menuPrice, {
    int? menuTemplateId,
    int? branchId,
  }) async {
    try {
      final result = await _favoriteService.toggleFavorite(
        menuId,
        menuName,
        menuPrice,
        menuTemplateId: menuTemplateId,
        branchId: branchId);
      await _loadFavorites();
      _ref.invalidate(favoritesProvider);
      _ref.invalidate(isFavoriteProvider(menuId));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadFavorites();
    _ref.invalidate(favoritesProvider);
  }
}

// Favorite controller provider
final favoriteControllerProvider =
    StateNotifierProvider<FavoriteController, AsyncValue<List<Favorite>>>((ref) {
  final favoriteService = ref.watch(favoriteServiceProvider);
  return FavoriteController(favoriteService, ref);
});
