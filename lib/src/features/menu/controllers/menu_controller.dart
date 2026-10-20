import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/menu_model.dart';
import '../../../shared/services/menu_service.dart';
import '../../../core/services/api_client.dart';
import '../../../shared/models/review_model.dart';

// Service provider
final menuServiceProvider = Provider<MenuService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return MenuService(apiClient);
});

// Get all menus
final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final service = ref.read(menuServiceProvider);
  return service.getMenus();
});

class ProductDetailsKey {
  final int menuId;
  final String? branchId;

  const ProductDetailsKey({
    required this.menuId,
    this.branchId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDetailsKey &&
          runtimeType == other.runtimeType &&
          menuId == other.menuId &&
          branchId == other.branchId;

  @override
  int get hashCode => Object.hash(menuId, branchId);
}

// Get product details by ID
final productDetailsProvider =
    FutureProvider.family<Menu, ProductDetailsKey>((ref, key) async {
  final service = ref.read(menuServiceProvider);
  return service.getMenuById(key.menuId, branchId: key.branchId);
});

// Get menus by category
final menusByCategoryProvider = FutureProvider.family<List<Menu>, String>((ref, category) async {
  final service = ref.read(menuServiceProvider);
  return service.getMenusByCategory(category);
});

// Get menus by brand
final menusByBrandProvider = FutureProvider.family<List<Menu>, String>((ref, brandId) async {
  final service = ref.read(menuServiceProvider);
  return service.getMenusByBrand(brandId);
});

// Get popular menus
final popularMenusProvider = FutureProvider<List<Menu>>((ref) async {
  final service = ref.read(menuServiceProvider);
  return service.getPopularMenus();
});

class MenuReviewsKey {
  final int menuId;
  final int? rating;
  final bool withComment;
  final int? perPage;
  final bool all;

  const MenuReviewsKey({
    required this.menuId,
    this.rating,
    this.withComment = false,
    this.perPage,
    this.all = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuReviewsKey &&
          runtimeType == other.runtimeType &&
          menuId == other.menuId &&
          rating == other.rating &&
          withComment == other.withComment &&
          perPage == other.perPage &&
          all == other.all;

  @override
  int get hashCode => Object.hash(menuId, rating, withComment, perPage, all);
}

final menuReviewsProvider =
    FutureProvider.family<MenuReviewsResponse, MenuReviewsKey>((ref, key) async {
  final apiClient = ref.read(apiClientProvider);
  try {
    final queryParams = <String, dynamic>{};
    if (key.rating != null) {
      queryParams['rating'] = key.rating;
    }
    if (key.withComment) {
      queryParams['with_comment'] = 1;
    }
    if (key.all) {
      queryParams['all'] = 1;
      queryParams['per_page'] = 1000;
    } else if (key.perPage != null) {
      queryParams['per_page'] = key.perPage;
    }
    final res = await apiClient.get('/reviews/menu/${key.menuId}',
        queryParameters: queryParams);
    return MenuReviewsResponse.fromJson(res);
  } catch (e, stack) {
    debugPrint('❌ [menuReviewsProvider] Error fetching reviews for menu ${key.menuId} (rating: ${key.rating}): $e\n$stack');
    return MenuReviewsResponse(
      reviews: [],
      averageRating: 5.0,
      totalReviews: 0,
      totalWithComment: 0,
    );
  }
});
