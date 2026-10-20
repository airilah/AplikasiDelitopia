import '../../core/services/api_client.dart';
import '../models/menu_model.dart';

class MenuService {
  final ApiClient _apiClient;

  MenuService(this._apiClient);

  /// Get all menus
  /// GET /getData/menu
  Future<List<Menu>> getMenus() async {
    try {
      final response = await _apiClient.get('/getData/menu');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data.map((json) => Menu.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load menus');
    } catch (e) {
      throw Exception('Failed to load menus: $e');
    }
  }

  /// Get menu details by ID
  /// GET /getData/menu-detail/{id}
  Future<Menu> getMenuById(int id, {String? branchId}) async {
    if (id <= 0) {
      throw Exception('Menu not found');
    }
    try {
      final response = await _apiClient.get(
        '/getData/menu-detail/$id',
        queryParameters: {
          if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        });

      if (response['status'] == 'success' && response['data'] != null) {
        return Menu.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to load product details');
    } catch (e) {
      // Fallback: try fetching by brand if single item endpoint fails
      try {
        final menus = await getMenuByBrandOrCategory(type: 'brand', data: 'all');
        return menus.firstWhere((m) => m.id == id);
      } catch (_) {
        throw Exception('Failed to load product details: $e');
      }
    }
  }

  /// Get menu by brand or category
  /// POST /getData/menuByBranch
  ///
  /// [type] - Either "brand" or "category"
  /// [data] - Brand ID or category name, or "all" for all menus
  Future<List<Menu>> getMenuByBrandOrCategory({
    required String type,
    required String data,
  }) async {
    try {
      final response = await _apiClient.post(
        '/getData/menuByBranch',
        data: {
          'type': type,
          'data': data,
        });

      if (response['status'] == 'success') {
        final List<dynamic> responseData = response['data'] as List<dynamic>;
        return responseData.map((json) => Menu.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load menus');
    } catch (e) {
      if (e is ApiException && (e.statusCode == 404 || e.message.toLowerCase().contains('menu not found'))) {
        return [];
      }
      if (e.toString().toLowerCase().contains('menu not found')) {
        return [];
      }
      throw Exception('Failed to load menus: $e');
    }
  }

  /// Get menu by branch and brand
  /// POST /getData/menuByBranches
  ///
  /// [type] - Either "brand" or "category"
  /// [data] - Brand ID or category name
  /// [branchId] - Branch ID
  Future<List<Menu>> getMenuByBranchAndBrand({
    required String type,
    required String data,
    required String branchId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/getData/menuByBranches',
        data: {
          'type': type,
          'data': data,
          'branches': branchId,
        });

      if (response['status'] == 'success') {
        final List<dynamic> responseData = response['data'] as List<dynamic>;
        return responseData.map((json) => Menu.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load menus');
    } catch (e) {
      if (e is ApiException && (e.statusCode == 404 || e.message.toLowerCase().contains('menu not found'))) {
        return [];
      }
      if (e.toString().toLowerCase().contains('menu not found')) {
        return [];
      }
      throw Exception('Failed to load menus: $e');
    }
  }

  /// Helper: Get popular menus
  Future<List<Menu>> getPopularMenus({String? brandId}) async {
    final menus = brandId != null
        ? await getMenuByBrandOrCategory(type: 'brand', data: brandId)
        : await getMenus();

    return menus.where((menu) => menu.isPopular).toList();
  }

  /// Helper: Get menus by category
  Future<List<Menu>> getMenusByCategory(String category) async {
    return await getMenuByBrandOrCategory(type: 'category', data: category);
  }

  /// Helper: Get menus by brand
  Future<List<Menu>> getMenusByBrand(String brandId) async {
    return await getMenuByBrandOrCategory(type: 'brand', data: brandId);
  }
}
