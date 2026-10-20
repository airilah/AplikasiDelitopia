import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/favorite_service.dart';
import '../models/favorite_model.dart';

final favoritesProvider = FutureProvider<List<Favorite>>((ref) async {
  final service = ref.watch(favoriteServiceProvider);
  return service.getFavorites();
});

final favoriteControllerProvider =
    StateNotifierProvider<FavoriteController, AsyncValue<void>>((ref) {
  return FavoriteController(ref);
});

class FavoriteController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  FavoriteController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addFavorite(int menuId) async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(favoriteServiceProvider);
      await service.addFavorite(menuId);

      // Refresh favorites list
      _ref.invalidate(favoritesProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> removeFavorite(int menuId) async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(favoriteServiceProvider);
      await service.removeFavorite(menuId);

      // Refresh favorites list
      _ref.invalidate(favoritesProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
