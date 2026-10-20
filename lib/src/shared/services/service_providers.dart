import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/api_client.dart';
import '../../core/services/storage_service.dart';
import '../models/product_model.dart';
import '../models/voucher_model.dart';
import '../models/brand_model.dart';
import '../models/branch_model.dart';
import '../models/menu_model.dart';
import '../models/notification_model.dart';
import '../models/qr_model.dart';
import '../models/user_model.dart';
import '../../features/auth/services/auth_service.dart';
import 'home_service.dart';
import 'voucher_service.dart';
import 'brand_service.dart';
import 'branch_service.dart';
import 'menu_service.dart';
import 'notification_service.dart';
import 'qr_service.dart';
import 'location_service.dart';
import '../../features/voucher/controllers/voucher_controller.dart';

// Service Providers
final homeServiceProvider = Provider<HomeService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return HomeService(apiClient, storageService: storageService);
});

final voucherServiceProvider = Provider<VoucherService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VoucherService(apiClient);
});

final brandServiceProvider = Provider<BrandService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BrandService(apiClient);
});

final branchServiceProvider = Provider<BranchService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BranchService(apiClient);
});

final menuServiceProvider = Provider<MenuService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MenuService(apiClient);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationService(apiClient);
});

final qrServiceProvider = Provider<QRService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QRService(apiClient);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Data Providers
final currentUserProvider = FutureProvider<User?>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  final token = storage.getAuthToken();
  if (token == null || token.isEmpty) {
    return null;
  }

  final authService = ref.watch(authServiceProvider);
  try {
    final user = await authService.getCurrentUserWithPoints();
    if (user != null) {
      await storage.saveUserData({
        'name': user.name,
        'email': user.email,
        'phone': user.phoneNumber,
        'point': user.point,
      });
      if (user.id != 0) {
        await storage.saveUserId(user.id);
      }
    }
    return user;
  } catch (error) {
    final message = error.toString().toLowerCase();
    final isAuthError = message.contains('401') ||
        message.contains('unauthorized') ||
        (message.contains('token') && message.contains('expired'));

    if (isAuthError) {
      await storage.clearAll();
      return null;
    }

    // Offline / Slow Network Fallback: Recover from locally cached user profile
    final cachedData = await storage.getUserData();
    final cachedUserId = await storage.getUserId();
    if ((cachedData['name'] != null && cachedData['name']!.isNotEmpty) ||
        (cachedData['phone'] != null && cachedData['phone']!.isNotEmpty)) {
      final cachedPoint = int.tryParse(cachedData['point'] ?? '') ?? 0;
      return User(
        id: cachedUserId ?? 0,
        name: cachedData['name'] ?? '',
        email: cachedData['email'] ?? '',
        phoneNumber: cachedData['phone'],
        point: cachedPoint,
        phoneVerified: cachedData['phone'] != null && cachedData['phone']!.isNotEmpty,
      );
    }

    rethrow;
  }
});

final bannersProvider = FutureProvider<List<Banner>>((ref) async {
  final homeService = ref.watch(homeServiceProvider);
  return homeService.getBanners();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final homeService = ref.watch(homeServiceProvider);
  return homeService.getCategories();
});

final popularProductsProvider = FutureProvider<List<Product>>((ref) async {
  final homeService = ref.watch(homeServiceProvider);
  return homeService.getPopularProducts();
});

class ShowcaseProductsRequest {
  final int newLimit;
  final int popularLimit;
  final int limit;

  const ShowcaseProductsRequest({
    this.newLimit = 15,
    this.popularLimit = 15,
    this.limit = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowcaseProductsRequest &&
          runtimeType == other.runtimeType &&
          newLimit == other.newLimit &&
          popularLimit == other.popularLimit &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(newLimit, popularLimit, limit);
}

final showcaseProductsProvider =
    FutureProvider.family<ShowcaseProducts, ShowcaseProductsRequest>(
        (ref, request) async {
  final homeService = ref.watch(homeServiceProvider);
  return homeService.getShowcaseProducts(
    newLimit: request.newLimit,
    popularLimit: request.popularLimit,
    limit: request.limit,
  );
});

final availableVouchersProvider = FutureProvider<List<Voucher>>((ref) async {
  final voucherService = ref.watch(voucherServiceProvider);
  return voucherService.getAvailableVouchers();
});

final userVouchersProvider =
    FutureProvider.family<List<UserVoucher>, int>((ref, userId) async {
  final voucherService = ref.watch(voucherServiceProvider);
  return voucherService.getUserVouchers(userId);
});

final brandsProvider = FutureProvider<List<Brand>>((ref) async {
  final brandService = ref.watch(brandServiceProvider);
  return brandService.getBrands();
});

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final branchService = ref.watch(branchServiceProvider);
  return branchService.getBranches();
});

final branchesByBrandProvider =
    FutureProvider.family<List<Branch>, String>((ref, brandId) async {
  final branchService = ref.watch(branchServiceProvider);
  return branchService.getBranchesByBrand(brandId);
});

final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final menuService = ref.watch(menuServiceProvider);
  return menuService.getMenus();
});

final popularMenusProvider = FutureProvider<List<Menu>>((ref) async {
  final menuService = ref.watch(menuServiceProvider);
  return menuService.getPopularMenus();
});

final menusByCategoryProvider =
    FutureProvider.family<List<Menu>, String>((ref, category) async {
  final menuService = ref.watch(menuServiceProvider);
  return menuService.getMenusByCategory(category);
});

final menusByBrandProvider =
    FutureProvider.family<List<Menu>, String>((ref, brandId) async {
  final menuService = ref.watch(menuServiceProvider);
  return menuService.getMenusByBrand(brandId);
});

final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  try {
    final notificationService = ref.watch(notificationServiceProvider);
    final notifications = await notificationService.getNotifications();

    final filtered = List<NotificationModel>.from(notifications);
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  } catch (e) {
    return [];
  }
});

final lastSeenNotificationTimeProvider = StateProvider<DateTime?>((ref) {
  return ref.watch(storageServiceProvider).getLastSeenNotificationTime();
});

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  if (notifications.isEmpty) return false;

  final lastSeen = ref.watch(lastSeenNotificationTimeProvider);
  if (lastSeen == null) return true;

  return notifications.any((n) => n.createdAt.isAfter(lastSeen));
});

final qrCodesProvider = FutureProvider<List<QRCode>>((ref) async {
  final qrService = ref.watch(qrServiceProvider);
  return qrService.getAllQR();
});

// Location Providers
final userPositionProvider = FutureProvider<Position?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.getCurrentPosition();
});

final nearbyBranchesProvider =
    FutureProvider<List<BranchWithDistance>>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  final userPosition = await ref.watch(userPositionProvider.future);
  final branches = await ref.watch(branchesProvider.future);

  if (userPosition == null) {
    return [];
  }

  final sortedBranches = await locationService.getBranchesByDistance(
    branches,
    userPosition);

  return sortedBranches.take(3).toList();
});

final nearestBranchForBrandProvider = FutureProvider.family<Branch?, int>((ref, brandId) async {
  try {
    final userPosition = await ref.watch(userPositionProvider.future);
    final branches = await ref.watch(branchesProvider.future);
    if (userPosition == null || branches.isEmpty) {
      return null;
    }
    final brandBranches = branches.where((b) => b.brandId == brandId).toList();
    if (brandBranches.isEmpty) {
      return null;
    }
    final locationService = ref.watch(locationServiceProvider);
    final sorted = await locationService.getBranchesByDistance(brandBranches, userPosition);
    return sorted.isNotEmpty ? sorted.first.branch : null;
  } catch (_) {
    return null;
  }
});

// User Points Balance Provider (uses new points API endpoint)
final userPointsBalanceProvider = FutureProvider<int>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return 0;
  }

  // Delegate to the voucher controller's userPointsProvider
  // which uses the new /getData/points endpoint
  return ref.watch(userPointsProvider.future);
});
