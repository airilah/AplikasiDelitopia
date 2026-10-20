import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/favorite_model.dart';

final favoriteServiceProvider = Provider<FavoriteService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FavoriteService(apiClient);
});

class FavoriteService {
  final ApiClient _apiClient;

  FavoriteService(this._apiClient);

  /// Get all favorites for current user
  Future<List<Favorite>> getFavorites() async {
    try {
      final response = await _getWithFallback('/v2/favorites', '/favorites');

      if (_isSuccessResponse(response)) {
        final dataContainer = response['data'];
        final data = dataContainer is Map<String, dynamic>
            ? (dataContainer['data'] as List<dynamic>? ?? const [])
            : (dataContainer as List<dynamic>? ?? const []);
        return data
            .map((json) => Favorite.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception(response['message'] ?? 'Failed to get favorites');
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }

  /// Add menu to favorites
  Future<Favorite> addFavorite(AddFavoriteRequest request) async {
    try {
      final response = await _postWithFallback(
        primaryPath: '/v2/favorites',
        fallbackPath: '/favorites/add',
        data: request.toJson());

      if (_isSuccessResponse(response)) {
        return Favorite.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to add favorite');
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }

  /// Remove menu from favorites
  Future<void> removeFavorite(int menuId) async {
    try {
      final response = await _deleteWithFallback(
          '/v2/favorites/$menuId', '/favorites/$menuId');

      if (!_isSuccessResponse(response)) {
        throw Exception(response['message'] ?? 'Failed to remove favorite');
      }
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }

  /// Check if menu is favorited
  Future<bool> isFavorite(int menuId) async {
    try {
      final response = await _getWithFallback(
        '/v2/favorites/check/$menuId',
        '/favorites/check/$menuId');

      if (_isSuccessResponse(response)) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return data['is_favorite'] as bool? ??
              data['is_favorited'] as bool? ??
              false;
        }
        return response['is_favorited'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(
    int menuId,
    String menuName,
    double menuPrice, {
    int? menuTemplateId,
    int? branchId,
  }) async {
    try {
      final isFav = await isFavorite(menuId);

      if (isFav) {
        await removeFavorite(menuId);
        return false;
      } else {
        await addFavorite(AddFavoriteRequest(
          menuId: menuId,
          menuTemplateId: menuTemplateId,
          branchId: branchId,
          menuName: menuName,
          menuPrice: menuPrice,
        ));
        return true;
      }
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('ApiException: ', '')
        .replaceAll('Failed to toggle favorite: ', '')
        .replaceAll('Failed to add favorite: ', '')
        .replaceAll('Failed to remove favorite: ', '')
        .trim();
  }

  bool _isSuccessResponse(Map<String, dynamic> response) {
    return response['success'] == true || response['status'] == 'success';
  }

  Future<Map<String, dynamic>> _getWithFallback(
    String primaryPath,
    String fallbackPath,
  ) async {
    try {
      return await _apiClient.get(primaryPath);
    } catch (e) {
      if (!_shouldUseFallback(e)) rethrow;
      return _apiClient.get(fallbackPath);
    }
  }

  Future<Map<String, dynamic>> _postWithFallback({
    required String primaryPath,
    required String fallbackPath,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await _apiClient.post(primaryPath, data: data);
    } catch (e) {
      if (!_shouldUseFallback(e)) rethrow;
      return _apiClient.post(fallbackPath, data: data);
    }
  }

  Future<Map<String, dynamic>> _deleteWithFallback(
    String primaryPath,
    String fallbackPath,
  ) async {
    try {
      return await _apiClient.delete(primaryPath);
    } catch (e) {
      if (!_shouldUseFallback(e)) rethrow;
      return _apiClient.delete(fallbackPath);
    }
  }

  bool _shouldUseFallback(Object error) {
    return error is ApiException &&
        (error.statusCode == 404 || error.statusCode == 405);
  }
}
