import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_client.dart';
import '../../core/services/storage_service.dart';
import '../models/member_profile_model.dart';
import '../models/user_voucher_model.dart';

// Provider for POS Service
final posServiceProvider = Provider<PosService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PosService(apiClient);
});

// Provider for Member Profile
final memberProfileProvider = FutureProvider<MemberProfile?>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return null;
  }

  final posService = ref.watch(posServiceProvider);
  return posService.getMyMemberProfile();
});

// Provider for My Vouchers
final myVouchersProvider = FutureProvider<MyVouchersResponse?>((ref) async {
  final token = ref.watch(storageServiceProvider).getAuthToken();
  if (token == null || token.isEmpty) {
    return null;
  }

  debugPrint('🔵 myVouchersProvider CALLED - Starting to fetch vouchers...');
  final posService = ref.watch(posServiceProvider);
  debugPrint('🔵 PosService instance obtained: $posService');
  final result = await posService.getMyVouchers();
  debugPrint('🔵 myVouchersProvider RESULT: ${result?.vouchers.length ?? 0} vouchers');
  return result;
});

class PosService {
  final ApiClient _apiClient;

  PosService(this._apiClient);

  /// Get member profile with QR code for POS identification
  /// Endpoint: GET /api/postData/pos/my-member-profile
  Future<MemberProfile?> getMyMemberProfile() async {
    try {
      debugPrint('🔵 Fetching member profile for POS...');
      final response = await _apiClient.get('/postData/pos/my-member-profile');
      debugPrint('📦 Member profile response status: ${response['status']}');
      debugPrint('📦 Member profile response data: ${response['data']}');

      if (response['status'] == 'success' && response['data'] != null) {
        debugPrint('🔄 Parsing member profile data...');
        final profile = MemberProfile.fromJson(response['data'] as Map<String, dynamic>);
        debugPrint('✅ Member profile loaded: ${profile.user.name}, Code: ${profile.user.memberCode}, Level: ${profile.user.userLevel.name}');
        return profile;
      }

      debugPrint('⚠️ Failed to load member profile - Status: ${response['status']}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching member profile: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get all user vouchers with claim codes
  /// Endpoint: GET /api/getData/my-vouchers
  Future<MyVouchersResponse?> getMyVouchers() async {
    try {
      debugPrint('🔵 Fetching my vouchers from /getData/my-vouchers...');
      final response = await _apiClient.get('/getData/my-vouchers');
      debugPrint('📦 My vouchers response status: ${response['status']}');
      debugPrint('📦 My vouchers response data type: ${response['data'].runtimeType}');
      debugPrint('📦 My vouchers response data: ${response['data']}');

      if (response['status'] == 'success' && response['data'] != null) {
        // Handle if backend returns array directly
        if (response['data'] is List) {
          final vouchers = (response['data'] as List<dynamic>)
              .map((v) => UserVoucher.fromJson(v as Map<String, dynamic>))
              .toList();
          
          // Calculate totals
          final totalActive = vouchers.where((v) => v.isActive).length;
          final totalInactive = vouchers.where((v) => v.isInactive).length;
          final totalUsed = vouchers.where((v) => v.isUsed).length;
          
          final vouchersData = MyVouchersResponse(
            vouchers: vouchers,
            totalActive: totalActive,
            totalInactive: totalInactive,
            totalUsed: totalUsed);
          
          debugPrint('✅ Vouchers loaded from array: ${vouchersData.vouchers.length} total (Active: $totalActive, Inactive: $totalInactive, Used: $totalUsed)');
          return vouchersData;
        }
        
        // Handle if backend returns object with vouchers array
        final vouchersData = MyVouchersResponse.fromJson(response['data'] as Map<String, dynamic>);
        debugPrint('✅ Vouchers loaded from object: ${vouchersData.vouchers.length} total (Active: ${vouchersData.totalActive}, Inactive: ${vouchersData.totalInactive})');
        return vouchersData;
      }

      debugPrint('⚠️ Failed to load vouchers - Status: ${response['status']}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching vouchers: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Generate claim code for inactive voucher
  /// Endpoint: POST /api/postData/pos/generate-claim-code
  Future<Map<String, dynamic>?> generateClaimCode(int detailVoucherId) async {
    try {
      debugPrint('🔵 Generating claim code for voucher ID: $detailVoucherId');
      final response = await _apiClient.post(
        '/postData/pos/generate-claim-code',
        data: {
          'detail_voucher_id': detailVoucherId,
        });
      debugPrint('📦 Generate claim code response: $response');

      if (response['status'] == 'success' && response['data'] != null) {
        debugPrint('✅ Claim code generated: ${response['data']['claim_code']}');
        return response['data'] as Map<String, dynamic>;
      }

      debugPrint('⚠️ Failed to generate claim code');
      return null;
    } catch (e) {
      debugPrint('❌ Error generating claim code: $e');
      rethrow;
    }
  }
}
