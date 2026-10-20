import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/storage_service.dart';
import '../models/voucher_model.dart';
import '../services/voucher_service.dart';
import '../../../shared/services/service_providers.dart';

// Service provider
final voucherServiceProvider = Provider<VoucherService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return VoucherService(storageService: storageService);
});

// Current user ID provider
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  try {
    final storageService = ref.watch(storageServiceProvider);
    final userId = await storageService.getUserId();
    if (userId != null) {
      return userId;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Try getting as int first
    final userIdInt = prefs.getInt('user_id');
    if (userIdInt != null) {
      debugPrint('✅ User ID (int): $userIdInt');
      return userIdInt;
    }
    
    // Fallback to string
    final userIdStr = prefs.getString('user_id');
    if (userIdStr != null) {
      final parsed = int.tryParse(userIdStr);
      debugPrint('✅ User ID (string->int): $parsed');
      return parsed;
    }
    
    debugPrint('⚠️ No user ID found');
    return null;
  } catch (e, stack) {
    debugPrint('❌ Error getting user ID: $e');
    debugPrint('Stack: $stack');
    return null;
  }
});

// 1. All available vouchers
final availableVouchersProvider = FutureProvider<List<Voucher>>((ref) async {
  try {
    debugPrint('🔵 availableVouchersProvider called');
    final categories = await ref.watch(categorizedVouchersProvider.future);
    final allVouchers = <Voucher>[
      ...?categories['auto_granted'],
      ...?categories['point_redemption'],
      ...?categories['cash_purchase'],
    ];
    debugPrint('🔵 Provider returning ${allVouchers.length} vouchers from categorized');
    return allVouchers;
  } catch (e, stack) {
    debugPrint('🔴 Categorized error, fallback to service: $e');
    debugPrint('🔴 Stack: $stack');
    final service = ref.watch(voucherServiceProvider);
    return service.getAvailableVouchers();
  }
});

// 2. Voucher details by ID
final voucherDetailsProvider = FutureProvider.family<Voucher, int>((ref, voucherId) async {
  final service = ref.watch(voucherServiceProvider);
  return service.getVoucherDetails(voucherId);
});

// 3. Point redemption vouchers
final pointRedemptionVouchersProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(voucherServiceProvider);
  return service.getPointRedemptionVouchers();
});

// 4. Cash purchase vouchers
final cashPurchaseVouchersProvider = FutureProvider<List<Voucher>>((ref) async {
  final service = ref.watch(voucherServiceProvider);
  return service.getCashPurchaseVouchers();
});

// 5. My vouchers (all statuses)
final myVouchersProvider = FutureProvider<List<DetailVoucher>>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  final service = ref.watch(voucherServiceProvider);
  return service.getMyVouchers();
});

// 6. My vouchers by status
final myVouchersByStatusProvider = FutureProvider.family<List<DetailVoucher>, String?>((ref, status) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  final service = ref.watch(voucherServiceProvider);
  return service.getMyVouchers(status: status);
});

// 7. My active vouchers only
final myActiveVouchersProvider = FutureProvider<List<DetailVoucher>>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  final service = ref.watch(voucherServiceProvider);
  return service.getMyActiveVouchers();
});

// 8. User points balance
final userPointsProvider = FutureProvider<int>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return 0;
  }

  try {
    debugPrint('🔵 userPointsProvider called');
    final service = ref.watch(voucherServiceProvider);
    final result = await service.getUserPoints();
    debugPrint('🔵 Provider returning $result points');
    return result;
  } catch (e, stack) {
    debugPrint('🔴 Points provider error: $e');
    debugPrint('🔴 Stack: $stack');
    rethrow;
  }
});

// 9. Points history
final pointsHistoryProvider = FutureProvider<List<PointHistory>>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return [];
  }

  final service = ref.watch(voucherServiceProvider);
  return service.getPointsHistory();
});

// 10. All vouchers categorized
final categorizedVouchersProvider = FutureProvider<Map<String, List<Voucher>>>((ref) async {
  final service = ref.watch(voucherServiceProvider);
  return service.getAllVouchersCategorized();
});

// Voucher actions controller
class VoucherActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final VoucherService _service;
  final Ref _ref;

  VoucherActionsNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  /// Redeem voucher with points
  Future<Map<String, dynamic>> redeemVoucherWithPoints(int voucherId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.redeemVoucherWithPoints(voucherId);
      state = const AsyncValue.data(null);
      
      // Refresh all relevant providers
      _ref.invalidate(categorizedVouchersProvider);
      _ref.invalidate(availableVouchersProvider);
      _ref.invalidate(myVouchersProvider);
      _ref.invalidate(userPointsProvider);
      _ref.invalidate(pointRedemptionVouchersProvider);
      _ref.invalidate(currentUserProvider); // Refresh user points on homepage
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(hasUnreadNotificationsProvider);
      
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Purchase voucher with cash (returns payment URL)
  Future<Map<String, dynamic>> purchaseVoucherWithCash(
    int voucherId,
    String paymentMethod,
  ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.purchaseVoucherWithCash(voucherId, paymentMethod);
      state = const AsyncValue.data(null);
      
      // Refresh providers
      _ref.invalidate(categorizedVouchersProvider);
      _ref.invalidate(availableVouchersProvider);
      _ref.invalidate(myVouchersProvider);
      _ref.invalidate(cashPurchaseVouchersProvider);
      _ref.invalidate(currentUserProvider); // Refresh user points just in case
      
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Activate a voucher
  Future<DetailVoucher> activateVoucher(int detailVoucherId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.activateVoucher(detailVoucherId);
      state = const AsyncValue.data(null);
      
      // Refresh voucher lists
      _ref.invalidate(categorizedVouchersProvider);
      _ref.invalidate(myVouchersProvider);
      _ref.invalidate(myActiveVouchersProvider);
      
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Validate if voucher can be used right now
  Future<VoucherUsageValidation> validateVoucherUsage(int detailVoucherId) async {
    try {
      return await _service.validateVoucherUsage(detailVoucherId);
    } catch (e) {
      return VoucherUsageValidation(
        canUse: false,
        message: 'Error validating voucher: $e',
        usageCount: 0);
    }
  }

  /// Get voucher usage history
  Future<Map<String, dynamic>> getVoucherUsageHistory(int detailVoucherId) async {
    try {
      return await _service.getVoucherUsageHistory(detailVoucherId);
    } catch (e) {
      rethrow;
    }
  }

  /// Use voucher (apply to order)
  Future<DetailVoucher> useVoucher(int detailVoucherId, int orderId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.useVoucher(detailVoucherId, orderId);
      state = const AsyncValue.data(null);
      
      // Refresh voucher lists
      _ref.invalidate(categorizedVouchersProvider);
      _ref.invalidate(myVouchersProvider);
      _ref.invalidate(myActiveVouchersProvider);
      
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Redeem birthday voucher
  Future<Map<String, dynamic>> redeemBirthdayVoucher() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.redeemBirthdayVoucher();
      state = const AsyncValue.data(null);
      
      // Refresh voucher lists
      _ref.invalidate(categorizedVouchersProvider);
      _ref.invalidate(myVouchersProvider);
      
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final voucherActionsProvider = StateNotifierProvider<VoucherActionsNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(voucherServiceProvider);
  return VoucherActionsNotifier(service, ref);
});
