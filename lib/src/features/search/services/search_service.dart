import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/api_client.dart';
import '../../../shared/services/location_service.dart';
import '../models/search_result.dart';

class _CachedBranch {
  final int id;
  final int brandId;
  final String rawOutlet;
  final String cleanName;
  final String address;
  final String openingHours;
  final String closingHours;
  final double latitude;
  final double longitude;
  final String searchHaystack;

  _CachedBranch({
    required this.id,
    required this.brandId,
    required this.rawOutlet,
    required this.cleanName,
    required this.address,
    required this.openingHours,
    required this.closingHours,
    required this.latitude,
    required this.longitude,
    required String brandName,
  }) : searchHaystack = '$cleanName $rawOutlet $address $brandName'.toLowerCase();
}

class _CachedMenu {
  final int id;
  final String name;
  final double price;
  final int soldCount;
  final int brandId;
  final int branchId;
  final String category;
  final String description;
  final String searchHaystack;

  _CachedMenu({
    required this.id,
    required this.name,
    required this.price,
    required this.soldCount,
    required this.brandId,
    required this.branchId,
    required this.category,
    required this.description,
  }) : searchHaystack = '$name $category $description'.toLowerCase();
}

class _ScoredMenu {
  final int score;
  final SearchMenuItem item;

  _ScoredMenu({required this.score, required this.item});
}

class SearchService {
  final ApiClient _apiClient;
  final LocationService _locationService;

  List<_CachedBranch>? _cachedBranches;
  Map<int, _CachedBranch>? _branchMap;
  Map<int, List<_CachedBranch>>? _branchesByBrand;
  List<_CachedMenu>? _cachedMenus;
  DateTime? _lastCacheTime;
  bool _isLoadingCache = false;

  SearchService(this._apiClient, this._locationService);

  /// Preload branch and menu catalogs in background for near-zero latency search
  void preloadData() {
    _ensureCacheLoaded();
  }

  /// Clean outlet raw name into concise branch name (e.g. "Sushikun PTC, Surabaya")
  static String cleanOutletName(String raw) {
    var s = raw.trim();
    // Strip CABxxx code
    s = s.replaceAll(RegExp(r'\bCAB\d+\b', caseSensitive: false), '').trim();

    // Split on address words like "Jl.", "Jl ", "Jalan", "Lt."
    final parts = s.split(RegExp(r'\s+(?:Jl\.|Jl\b|Jalan\b|Lt\.)', caseSensitive: false));
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      var name = parts.first.trim();
      while (name.endsWith(',') || name.endsWith('-')) {
        name = name.substring(0, name.length - 1).trim();
      }

      // Check if city name is in the full raw text and add it if not already present
      final cities = [
        'Surabaya', 'Malang', 'Sidoarjo', 'Mojokerto', 'Kediri', 'Madiun',
        'Garut', 'Tasikmalaya', 'Tuban', 'Batu', 'Semarang', 'Solo',
        'Pekalongan', 'Cianjur', 'Depok', 'Cikarang', 'Samarinda',
        'Magelang', 'Purwokerto', 'Tegal', 'Jember',
      ];
      for (final city in cities) {
        if (raw.toLowerCase().contains(city.toLowerCase()) &&
            !name.toLowerCase().contains(city.toLowerCase())) {
          name = '$name, $city';
          break;
        }
      }
      return name;
    }
    return raw;
  }

  Future<void> _ensureCacheLoaded() async {
    final now = DateTime.now();
    if (_cachedBranches != null &&
        _cachedMenus != null &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!).inMinutes < 15) {
      return;
    }

    if (_isLoadingCache) return;
    _isLoadingCache = true;

    try {
      final futures = await Future.wait([
        _apiClient
            .get('/getData/branch')
            .catchError((_) => {'status': 'failed', 'data': []}),
        _apiClient
            .get('/getData/menu')
            .catchError((_) => {'status': 'failed', 'data': []}),
        _apiClient
            .get('/getData/brand')
            .catchError((_) => {'status': 'failed', 'data': []}),
      ]);

      final branchRes = futures[0];
      final menuRes = futures[1];
      final brandRes = futures[2];

      final rawBranches = branchRes['data'] is List ? branchRes['data'] as List : [];
      final rawMenus = menuRes['data'] is List ? menuRes['data'] as List : [];
      final rawBrands = brandRes['data'] is List ? brandRes['data'] as List : [];

      final Set<int> activeBrandIds = {};
      final Set<String> activeBrandNames = {};
      for (final b in rawBrands) {
        if (b is! Map<String, dynamic>) continue;
        final bid = int.tryParse(b['id']?.toString() ?? '') ?? 0;
        if (bid == 0) continue;
        final rawActive = b['is_active'];
        if (rawActive != null && (rawActive == false || rawActive == 0 || rawActive == '0' || rawActive == 'false')) {
          continue;
        }
        activeBrandIds.add(bid);
        final bname = b['name']?.toString().toLowerCase().trim();
        if (bname != null && bname.isNotEmpty) {
          activeBrandNames.add(bname);
        }
      }

      final List<_CachedBranch> branchList = [];
      final Map<int, _CachedBranch> bMap = {};
      final Map<int, List<_CachedBranch>> byBrand = {};

      for (final item in rawBranches) {
        if (item is! Map<String, dynamic>) continue;
        final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
        if (id == 0) continue;

        // Validasi status aktif cabang
        final rawActive = item['is_active'];
        if (rawActive != null) {
          if (rawActive == false || rawActive == 0 || rawActive == '0' || rawActive == 'false') {
            continue;
          }
        }
        final rawStatus = item['status']?.toString().toLowerCase().trim();
        if (rawStatus != null && (rawStatus == 'inactive' || rawStatus == 'nonaktif' || rawStatus == 'closed' || rawStatus == '0')) {
          continue;
        }

        final brandId = int.tryParse(item['brand_id']?.toString() ?? '') ?? 0;
        final brandName = item['brand_name']?.toString() ?? '';
        final lowerBrand = brandName.toLowerCase().trim();

        // Validasi status aktif brand induk
        if (activeBrandIds.isNotEmpty && brandId > 0 && !activeBrandIds.contains(brandId)) {
          continue;
        }
        if (activeBrandNames.isNotEmpty && lowerBrand.isNotEmpty && !activeBrandNames.contains(lowerBrand)) {
          continue;
        }
        final rawBrandActive = item['brand_is_active'];
        if (rawBrandActive != null && (rawBrandActive == false || rawBrandActive == 0 || rawBrandActive == '0' || rawBrandActive == 'false')) {
          continue;
        }
        final outlet = item['outlet']?.toString() ?? '';
        final location = item['location']?.toString() ?? '';
        final address = item['address']?.toString() ?? location;
        final openHours = item['opening_hours']?.toString() ?? '10:00';
        final closeHours = item['closing_hours']?.toString() ?? '22:00';
        final lat = double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0;

        final clean = cleanOutletName(outlet);

        final bItem = _CachedBranch(
          id: id,
          brandId: brandId,
          rawOutlet: outlet,
          cleanName: clean,
          address: address.isNotEmpty ? address : location,
          openingHours: openHours,
          closingHours: closeHours,
          latitude: lat,
          longitude: lng,
          brandName: brandName,
        );

        branchList.add(bItem);
        bMap[id] = bItem;

        if (brandId > 0) {
          byBrand.putIfAbsent(brandId, () => []).add(bItem);
        }
      }

      final List<_CachedMenu> menuList = [];
      for (final item in rawMenus) {
        if (item is! Map<String, dynamic>) continue;
        final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
        if (id == 0) continue;

        // Validasi status aktif menu
        final rawMenuActive = item['is_active'];
        if (rawMenuActive != null) {
          if (rawMenuActive == false || rawMenuActive == 0 || rawMenuActive == '0' || rawMenuActive == 'false') {
            continue;
          }
        }
        final isAvailable = item['is_available'];
        if (isAvailable == false || isAvailable == 0 || isAvailable == '0') {
          continue;
        }
        final canOrder = item['can_order'];
        if (canOrder == false || canOrder == 0 || canOrder == '0') {
          continue;
        }

        final price = double.tryParse(item['price']?.toString() ?? '') ??
            double.tryParse(item['base_price']?.toString() ?? '') ??
            0.0;
        if (price <= 0) continue;

        final brandId = int.tryParse(item['brand_id']?.toString() ?? '') ?? 0;
        final brandName = item['brand_name']?.toString() ?? '';
        final lowerBrand = brandName.toLowerCase().trim();

        // Validasi brand aktif
        if (activeBrandIds.isNotEmpty && brandId > 0 && !activeBrandIds.contains(brandId)) {
          continue;
        }
        if (activeBrandNames.isNotEmpty && lowerBrand.isNotEmpty && !activeBrandNames.contains(lowerBrand)) {
          continue;
        }
        final rawBrandActive = item['brand_is_active'];
        if (rawBrandActive != null && (rawBrandActive == false || rawBrandActive == 0 || rawBrandActive == '0' || rawBrandActive == 'false')) {
          continue;
        }

        final branchId = int.tryParse(item['branches_id']?.toString() ?? '') ??
            int.tryParse(item['branch_id']?.toString() ?? '') ??
            0;

        // Pastikan menu terhubung ke cabang aktif:
        // 1. Jika terikat ke cabang spesifik, pastikan cabang tersebut aktif
        if (branchId != 0 && !bMap.containsKey(branchId)) {
          continue;
        }
        // 2. Jika hanya terikat brand, pastikan brand memiliki minimal 1 cabang aktif
        if (branchId == 0 && brandId != 0 && (!byBrand.containsKey(brandId) || byBrand[brandId]!.isEmpty)) {
          continue;
        }

        menuList.add(_CachedMenu(
          id: id,
          name: item['name']?.toString() ?? '',
          price: price,
          soldCount: int.tryParse(item['sold_count']?.toString() ?? '') ??
              int.tryParse(item['total_sold']?.toString() ?? '') ??
              int.tryParse(item['pos_sold_count']?.toString() ?? '') ??
              0,
          brandId: brandId,
          branchId: branchId,
          category: item['category']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
        ));
      }

      _cachedBranches = branchList;
      _branchMap = bMap;
      _branchesByBrand = byBrand;
      _cachedMenus = menuList;
      _lastCacheTime = DateTime.now();
    } catch (e) {
      debugPrint('Error populating local search cache: $e');
    } finally {
      _isLoadingCache = false;
    }
  }

  Future<GlobalSearchResult> search(String query, {Position? position}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const GlobalSearchResult(outlets: [], menus: []);
    }

    // Attempt to get user position if not supplied
    Position? userPos = position;
    if (userPos == null) {
      try {
        userPos = await _locationService.getCurrentPosition();
      } catch (e) {
        debugPrint('Location lookup ignored in search: $e');
      }
    }

    // Fallback: perform search on intelligent localized catalog
    return await _fallbackSearch(cleanQuery, userPos);
  }

  Future<GlobalSearchResult> _fallbackSearch(String query, Position? userPos) async {
    try {
      await _ensureCacheLoaded();

      final branches = _cachedBranches ?? [];
      final menus = _cachedMenus ?? [];
      final bMap = _branchMap ?? {};
      final byBrand = _branchesByBrand ?? {};

      final tokens = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();

      // 1. Search Outlets: every token MUST match the outlet/city/brand
      final List<SearchOutletItem> matchedOutlets = [];
      for (final b in branches) {
        final matches = tokens.every((tok) => b.searchHaystack.contains(tok));
        if (matches) {
          double? distance;
          if (userPos != null && b.latitude != 0.0 && b.longitude != 0.0) {
            distance = _locationService.calculateDistance(
              userPos.latitude,
              userPos.longitude,
              b.latitude,
              b.longitude,
            );
          }
          final isOpen = _checkIsOpen(b.openingHours, b.closingHours);
          matchedOutlets.add(SearchOutletItem(
            branchId: b.id,
            brandId: b.brandId,
            outletName: b.cleanName,
            address: b.address,
            openingHours: b.openingHours,
            closingHours: b.closingHours,
            isOpen: isOpen,
            distanceInKm: distance,
          ));
        }
      }

      // Sort Outlets: nearest first
      matchedOutlets.sort((a, b) {
        if (a.distanceInKm == null && b.distanceInKm == null) return 0;
        if (a.distanceInKm == null) return 1;
        if (b.distanceInKm == null) return -1;
        return a.distanceInKm!.compareTo(b.distanceInKm!);
      });

      // 2. Search Menus: Match query tokens against food name, category, description
      final List<_ScoredMenu> scoredMenus = [];
      final lowerQuery = query.toLowerCase();

      for (final m in menus) {
        final lowerName = m.name.toLowerCase();
        final lowerCategory = m.category.toLowerCase();

        int score = 0;

        if (tokens.length >= 2) {
          // Opsi A: Strict Title Matching untuk query multi-kata (seperti "Salmon Sushi")
          // Semua kata pencarian WAJIB ada di nama makanan!
          final allInName = tokens.every((tok) => lowerName.contains(tok));
          final allInCategory = tokens.every((tok) => lowerCategory.contains(tok));

          if (allInName) {
            if (lowerName == lowerQuery) {
              score = 100;
            } else if (lowerName.startsWith(lowerQuery)) {
              score = 85;
            } else {
              score = 60;
            }
          } else if (allInCategory) {
            // Cocok ke kategori khusus jika dicari nama kategorinya persis (misal "Kids Menu")
            score = 25;
          } else {
            // Discard makanan yang hanya ada salah satu kata di nama dan kata lain di kategori
            continue;
          }
        } else {
          // Query 1 kata (misal "Salmon" atau "Sushi" atau "Ramen")
          final singleToken = tokens.first;
          final inName = lowerName.contains(singleToken);
          final inCategory = lowerCategory.contains(singleToken);
          final inDesc = m.description.toLowerCase().contains(singleToken);

          if (inName) {
            if (lowerName == lowerQuery) {
              score = 100;
            } else if (lowerName.startsWith(lowerQuery)) {
              score = 80;
            } else {
              score = 60;
            }
          } else if (inCategory) {
            score = 30;
          } else if (inDesc) {
            score = 15;
          } else {
            continue;
          }
        }

        // Dynamically find the NEAREST ACTIVE BRANCH of this menu's brand
        _CachedBranch? nearestBranch;
        double? minDistance;

        final candidateBranches = (m.branchId != 0 && bMap.containsKey(m.branchId))
            ? [bMap[m.branchId]!]
            : (byBrand[m.brandId] ?? <_CachedBranch>[]);

        // Jika tidak ada cabang aktif yang menjual menu ini, jangan tampilkan
        if (candidateBranches.isEmpty) {
          continue;
        }

        if (userPos != null) {
          for (final b in candidateBranches) {
            if (b.latitude == 0.0 && b.longitude == 0.0) continue;
            final dist = _locationService.calculateDistance(
              userPos.latitude,
              userPos.longitude,
              b.latitude,
              b.longitude,
            );
            if (minDistance == null || dist < minDistance) {
              minDistance = dist;
              nearestBranch = b;
            }
          }
        }

        // Fallback jika candidate belum ada koordinat GPS
        nearestBranch ??= candidateBranches.first;

        final branchId = nearestBranch.id;
        final branchName = nearestBranch.cleanName;
        final isOpen = _checkIsOpen(nearestBranch.openingHours, nearestBranch.closingHours);

        scoredMenus.add(_ScoredMenu(
          score: score,
          item: SearchMenuItem(
            menuId: m.id,
            name: m.name,
            price: m.price,
            soldCount: m.soldCount,
            branchId: branchId,
            branchName: branchName,
            isOpen: isOpen,
            distanceInKm: minDistance,
          ),
        ));
      }

      // Sort Menus: higher relevance score first, then nearest distance ascending
      scoredMenus.sort((a, b) {
        if (b.score != a.score) {
          return b.score.compareTo(a.score);
        }
        if (a.item.distanceInKm == null && b.item.distanceInKm == null) return 0;
        if (a.item.distanceInKm == null) return 1;
        if (b.item.distanceInKm == null) return -1;
        return a.item.distanceInKm!.compareTo(b.item.distanceInKm!);
      });

      final matchedMenus = scoredMenus.map((s) => s.item).toList();

      return GlobalSearchResult(
        outlets: matchedOutlets,
        menus: matchedMenus,
      );
    } catch (e) {
      debugPrint('Fallback search error: $e');
      return const GlobalSearchResult(outlets: [], menus: []);
    }
  }

  bool _checkIsOpen(String openingHours, String closingHours) {
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final openParts = openingHours.split(':');
      final closeParts = closingHours.split(':');
      if (openParts.length < 2 || closeParts.length < 2) return true;

      final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
    } catch (_) {
      return true;
    }
  }
}
