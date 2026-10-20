import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_client.dart';
import '../../core/services/storage_service.dart';
import '../models/product_model.dart';

class HomeService {
  final ApiClient _apiClient;
  final StorageService? _storageService;
  static List<Banner> _cachedBanners = [];
  static ShowcaseProducts? _cachedShowcase;

  HomeService(this._apiClient, {StorageService? storageService})
      : _storageService = storageService;

  ShowcaseProducts? getLocalCachedShowcase() {
    if (_cachedShowcase != null && _cachedShowcase!.combined.isNotEmpty) {
      return _cachedShowcase;
    }
    final rawJson = _storageService?.getShowcaseCatalog();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final cached = ShowcaseProducts.fromJson(decoded);
          if (cached.combined.isNotEmpty) {
            _cachedShowcase = cached;
            return cached;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [HomeService] Failed to parse local cached showcase: $e');
        }
      }
    }
    return null;
  }

  Future<List<Banner>> getBanners() async {
    try {
      final dynamic response = await _apiClient.get(ApiConstants.banners);
      
      List<dynamic> data = [];
      if (response is Map) {
        if (response['data'] is List) {
          data = response['data'];
        } else if (response['banners'] is List) {
          data = response['banners'];
        } else if (response['result'] is List) {
          data = response['result'];
        }
      } else if (response is List) {
        data = response;
      }

      if (data.isNotEmpty) {
        final banners = data
            .map((json) => json is Map<String, dynamic>
                ? Banner.fromJson(json)
                : Banner.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        if (banners.isNotEmpty) {
          _cachedBanners = banners;
        }
        return banners;
      }
      return _cachedBanners.isNotEmpty ? _cachedBanners : [];
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [HomeService] getBanners failed: $e, using cached: ${_cachedBanners.length}');
      }
      return _cachedBanners.isNotEmpty ? _cachedBanners : [];
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      // Get brands to extract categories
      final response = await _apiClient.get('/getData/brand');
      
      if (response['status'] == 'success') {
        final List<dynamic> brandsData = response['data'] ?? [];
        final Set<String> categoryNames = {};
        
        // Extract unique categories from all brands
        for (var brandJson in brandsData) {
          final List<dynamic> categories = brandJson['category'] ?? [];
          categoryNames.addAll(categories.map((e) => e.toString()));
        }
        
        // Convert to Category objects
        return categoryNames.map((name) => Category(
          id: name.hashCode,
          name: name,
        )).toList();
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch categories');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  Future<List<Product>> getProducts({
    int? categoryId,
    String? search,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        ApiConstants.products,
        queryParameters: queryParams);
      
      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => Product.fromJson(json)).toList();
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch products');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  Future<List<Product>> getPopularProducts() async {
    try {
      final response = await _apiClient.get(
        ApiConstants.popularProducts,
        queryParameters: {'limit': 4});

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => Product.fromJson(json)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to fetch popular products');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  Future<ShowcaseProducts> getShowcaseProducts({
    int newLimit = 15,
    int popularLimit = 15,
    int limit = 30,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.showcaseProducts,
        queryParameters: {
          'new_limit': newLimit,
          'popular_limit': popularLimit,
          'limit': limit,
        });

      if (response['status'] == 'success') {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        bool isValidShowcaseProduct(Product p) {
          if (p.branchId == null || p.branchId! <= 0) return false;
          if (p.price <= 0) return false;
          return true;
        }

        final newMenus = (data['new'] as List<dynamic>? ?? [])
            .map((json) => Product.fromJson(json))
            .where(isValidShowcaseProduct)
            .toList();
        final popularMenus = (data['popular'] as List<dynamic>? ?? [])
            .map((json) => Product.fromJson(json))
            .where(isValidShowcaseProduct)
            .toList();
        final recommendedMenus = (data['recommended'] as List<dynamic>? ?? [])
            .map((json) => Product.fromJson(json))
            .where(isValidShowcaseProduct)
            .toList();
        final bestSellerMenus = (data['best_seller'] as List<dynamic>? ?? [])
            .map((json) => Product.fromJson(json))
            .where(isValidShowcaseProduct)
            .toList();
        final topRatedMenus = (data['top_rated'] as List<dynamic>? ?? [])
            .map((json) => Product.fromJson(json))
            .where(isValidShowcaseProduct)
            .toList();

        final result = ShowcaseProducts(
          newMenus: newMenus,
          popularMenus: popularMenus,
          recommendedMenus: recommendedMenus.isNotEmpty
              ? recommendedMenus
              : (popularMenus.isNotEmpty ? popularMenus : newMenus),
          bestSellerMenus: bestSellerMenus.isNotEmpty
              ? bestSellerMenus
              : (popularMenus.isNotEmpty ? popularMenus : newMenus),
          topRatedMenus: topRatedMenus.isNotEmpty
              ? topRatedMenus
              : (popularMenus.isNotEmpty ? popularMenus : newMenus),
        );

        if (result.combined.isNotEmpty) {
          _cachedShowcase = result;
          try {
            _storageService?.saveShowcaseCatalog(jsonEncode(result.toJson()));
          } catch (_) {}
        }

        return result;
      }

      throw Exception(response['message'] ?? 'Failed to fetch showcase products');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [HomeService] getShowcaseProducts network error: $e');
      }

      // Check local cache first on any network failure so user never gets stuck
      final local = getLocalCachedShowcase();
      if (local != null && local.combined.isNotEmpty) {
        return local;
      }

      try {
        final fallbackList = await getPopularProducts();
        if (fallbackList.isNotEmpty) {
          return ShowcaseProducts(
            newMenus: fallbackList.take(newLimit).toList(),
            popularMenus: fallbackList.take(popularLimit).toList(),
            recommendedMenus: fallbackList,
            bestSellerMenus: fallbackList,
            topRatedMenus: fallbackList,
          );
        }
      } catch (_) {}
      if (e is DioException) {
        throw Exception(e.response?.data?['message'] ?? 'Network error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<Product> getProductDetail(int productId) async {
    try {
      final response = await _apiClient.get('${ApiConstants.products}/$productId');
      
      if (response['status'] == 'success') {
        return Product.fromJson(response['data']);
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch product detail');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }
}

class ShowcaseProducts {
  final List<Product> newMenus;
  final List<Product> popularMenus;
  final List<Product> recommendedMenus;
  final List<Product> bestSellerMenus;
  final List<Product> topRatedMenus;

  const ShowcaseProducts({
    required this.newMenus,
    required this.popularMenus,
    this.recommendedMenus = const [],
    this.bestSellerMenus = const [],
    this.topRatedMenus = const [],
  });

  List<Product> get combined => [
        ...newMenus,
        ...popularMenus,
        ...recommendedMenus,
        ...bestSellerMenus,
        ...topRatedMenus
      ];

  Map<String, dynamic> toJson() {
    return {
      'new': newMenus.map((p) => p.toJson()).toList(),
      'popular': popularMenus.map((p) => p.toJson()).toList(),
      'recommended': recommendedMenus.map((p) => p.toJson()).toList(),
      'best_seller': bestSellerMenus.map((p) => p.toJson()).toList(),
      'top_rated': topRatedMenus.map((p) => p.toJson()).toList(),
    };
  }

  factory ShowcaseProducts.fromJson(Map<String, dynamic> json) {
    List<Product> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) {
              if (item is Map<String, dynamic>) {
                return Product.fromJson(item);
              } else if (item is Map) {
                return Product.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<Product>()
            .toList();
      }
      return [];
    }

    final newMenus = parseList(json['new']);
    final popularMenus = parseList(json['popular']);
    final recommendedMenus = parseList(json['recommended']);
    final bestSellerMenus = parseList(json['best_seller']);
    final topRatedMenus = parseList(json['top_rated']);

    return ShowcaseProducts(
      newMenus: newMenus,
      popularMenus: popularMenus,
      recommendedMenus: recommendedMenus.isNotEmpty
          ? recommendedMenus
          : (popularMenus.isNotEmpty ? popularMenus : newMenus),
      bestSellerMenus: bestSellerMenus.isNotEmpty
          ? bestSellerMenus
          : (popularMenus.isNotEmpty ? popularMenus : newMenus),
      topRatedMenus: topRatedMenus.isNotEmpty
          ? topRatedMenus
          : (popularMenus.isNotEmpty ? popularMenus : newMenus),
    );
  }
}
