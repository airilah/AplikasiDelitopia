import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../models/voucher_model.dart';

class VoucherService {
  final String baseUrl = ApiConstants.baseUrl;
  final StorageService? _storageService;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  VoucherService({StorageService? storageService})
      : _storageService = storageService;

  Future<String?> _getAuthToken() async {
    // 1. Try injected StorageService in-memory token
    final storageToken = _storageService?.getAuthToken();
    if (storageToken != null && storageToken.isNotEmpty) {
      return storageToken;
    }

    // 2. Try FlutterSecureStorage directly
    try {
      final secureToken =
          await _secureStorage.read(key: AppConstants.keyAuthToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}

    // 3. Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsToken = prefs.getString(AppConstants.keyAuthToken) ??
          prefs.getString('auth_token');
      if (prefsToken != null && prefsToken.isNotEmpty) {
        return prefsToken;
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Get all available vouchers
  /// Endpoint: GET /api/getData/voucher
  Future<List<Voucher>> getAvailableVouchers() async {
    try {
      final headers = await _getHeaders();
      debugPrint('🎫 Fetching vouchers from: $baseUrl${ApiConstants.vouchers}');
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.vouchers}'),
        headers: headers);

      debugPrint('🎫 Voucher Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final vouchers = data['data'] as List;
          final List<Voucher> parsedVouchers = [];
          for (int i = 0; i < vouchers.length; i++) {
            try {
              final voucher = Voucher.fromJson(vouchers[i] as Map<String, dynamic>);
              parsedVouchers.add(voucher);
            } catch (e) {
              debugPrint('❌ Error parsing voucher $i: $e');
            }
          }
          if (parsedVouchers.isNotEmpty) {
            return parsedVouchers;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Voucher Error: $e');
      debugPrint('🔍 Stack trace: $stack');
    }

    try {
      final categorized = await getAllVouchersCategorized();
      final allVouchers = <Voucher>[
        ...?categorized['auto_granted'],
        ...?categorized['point_redemption'],
        ...?categorized['cash_purchase'],
      ];
      return allVouchers;
    } catch (_) {
      return [];
    }
  }

  /// 2. Get voucher details
  /// Endpoint: GET /api/getData/voucher-show/{id}
  Future<Voucher> getVoucherDetails(int voucherId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.voucherShow}/$voucherId'),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return Voucher.fromJson(data['data']);
        }
      }
      throw Exception('Failed to load voucher details');
    } catch (e) {
      throw Exception('Error loading voucher details: $e');
    }
  }

  /// 3. Get point redemption vouchers
  /// Endpoint: GET /api/getData/vouchers/point-redemption
  Future<Map<String, dynamic>> getPointRedemptionVouchers({int? brandId}) async {
    try {
      final headers = await _getHeaders();
      var url = '$baseUrl${ApiConstants.pointRedemptionVouchers}';
      if (brandId != null) {
        url += '?brand_id=$brandId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final responseData = data['data'];
          return {
            'user_points': (responseData['user_points'] as num?)?.toInt() ?? 0,
            'vouchers': (responseData['vouchers'] as List?)
                    ?.map((v) => Voucher.fromJson(v))
                    .toList() ??
                [],
          };
        }
      }
      throw Exception('Failed to load point redemption vouchers');
    } catch (e) {
      throw Exception('Error loading point redemption vouchers: $e');
    }
  }

  /// 4. Redeem voucher with points
  /// Endpoint: POST /api/postData/vouchers/redeem-points
  Future<Map<String, dynamic>> redeemVoucherWithPoints(int voucherId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.redeemVoucherPoints}'),
        headers: headers,
        body: jsonEncode({'voucher_id': voucherId}));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'detail_voucher': DetailVoucher.fromJson(data['data']['detail_voucher']),
            'points_remaining': (data['data']['points_remaining'] as num?)?.toInt() ?? 0,
            'message': data['message'] ?? 'Voucher redeemed successfully',
          };
        }
      }

      // Handle error
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to redeem voucher');
    } catch (e) {
      throw Exception('Error redeeming voucher: $e');
    }
  }

  /// 5. Get cash purchase vouchers
  /// Endpoint: GET /api/getData/vouchers/cash-purchase
  Future<List<Voucher>> getCashPurchaseVouchers({int? brandId}) async {
    try {
      final headers = await _getHeaders();
      var url = '$baseUrl${ApiConstants.cashPurchaseVouchers}';
      if (brandId != null) {
        url += '?brand_id=$brandId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final vouchers = data['data'] as List;
          return vouchers.map((v) => Voucher.fromJson(v)).toList();
        }
      }
      throw Exception('Failed to load cash purchase vouchers');
    } catch (e) {
      throw Exception('Error loading cash purchase vouchers: $e');
    }
  }

  /// 6. Purchase voucher with cash (QRIS)
  /// Endpoint: POST /api/postData/vouchers/purchase-cash
  Future<Map<String, dynamic>> purchaseVoucherWithCash(
    int voucherId,
    String paymentMethod,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.purchaseVoucherCash}'),
        headers: headers,
        body: jsonEncode({
          'voucher_id': voucherId,
          'payment_method': paymentMethod,
        }));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'order_id': data['data']['order_id']?.toString(),
            'detail_voucher_id': data['data']['detail_voucher_id'],
            'payment_url': data['data']['payment_url']?.toString(),
            'amount': data['data']['amount'],
            'voucher': data['data']['voucher'] != null
                ? Voucher.fromJson(data['data']['voucher'])
                : null,
            'message': data['message'] ?? 'Payment initiated successfully',
          };
        }
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to purchase voucher');
    } catch (e) {
      throw Exception('Error purchasing voucher: $e');
    }
  }

  /// 7. Get my vouchers
  /// Endpoint: GET /api/getData/my-vouchers
  Future<List<DetailVoucher>> getMyVouchers({String? status}) async {
    try {
      final headers = await _getHeaders();
      var url = '$baseUrl${ApiConstants.myVouchers}';
      if (status != null) {
        url += '?status=$status';
      }

      debugPrint('📋 Fetching my vouchers from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: headers);

      debugPrint('📋 My Vouchers Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📋 My Vouchers Response: ${data['status']}');
        
        if (data['status'] == 'success' && data['data'] != null) {
          final vouchers = data['data'] as List;
          debugPrint('✅ Found ${vouchers.length} my vouchers');
          return vouchers.map((v) => DetailVoucher.fromJson(v as Map<String, dynamic>)).toList();
        }
      }
      debugPrint('⚠️ No my vouchers found');
      return [];
    } catch (e) {
      debugPrint('❌ My Vouchers Error: $e');
      return [];
    }
  }

  /// 8. Get my active vouchers
  /// Endpoint: GET /api/getData/my-active-vouchers
  Future<List<DetailVoucher>> getMyActiveVouchers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.myActiveVouchers}'),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final vouchers = data['data'] as List;
          return vouchers.map((v) => DetailVoucher.fromJson(v)).toList();
        }
      }
      throw Exception('Failed to load active vouchers');
    } catch (e) {
      throw Exception('Error loading active vouchers: $e');
    }
  }

  /// 9. Activate voucher
  /// Endpoint: POST /api/postData/voucher-activate
  Future<DetailVoucher> activateVoucher(int detailVoucherId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.activateVoucher}'),
        headers: headers,
        body: jsonEncode({'detail_voucher_id': detailVoucherId}));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return DetailVoucher.fromJson(data['data']);
        }
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to activate voucher');
    } catch (e) {
      throw Exception('Error activating voucher: $e');
    }
  }

  /// 10. Validate voucher usage
  /// Endpoint: POST /api/getData/vouchers/validate-usage
  Future<VoucherUsageValidation> validateVoucherUsage(int detailVoucherId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.validateVoucherUsage}'),
        headers: headers,
        body: jsonEncode({'detail_voucher_id': detailVoucherId}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return VoucherUsageValidation.fromJson(data['data']);
        }
      }

      // Return cannot use if error
      return VoucherUsageValidation(
        canUse: false,
        message: 'Unable to validate voucher usage',
        usageCount: 0);
    } catch (e) {
      return VoucherUsageValidation(
        canUse: false,
        message: 'Error validating voucher: $e',
        usageCount: 0);
    }
  }

  /// 11. Get voucher usage history
  /// Endpoint: GET /api/getData/vouchers/usage-history
  Future<Map<String, dynamic>> getVoucherUsageHistory(int detailVoucherId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl${ApiConstants.voucherUsageHistory}?detail_voucher_id=$detailVoucherId',
        ),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Failed to load usage history');
    } catch (e) {
      throw Exception('Error loading usage history: $e');
    }
  }

  /// 12. Use voucher (apply to order)
  /// Endpoint: POST /api/postData/use-voucher-api
  Future<DetailVoucher> useVoucher(int detailVoucherId, int orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.useVoucher}'),
        headers: headers,
        body: jsonEncode({
          'detail_voucher_id': detailVoucherId,
          'order_id': orderId,
        }));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return DetailVoucher.fromJson(data['data']);
        }
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to use voucher');
    } catch (e) {
      throw Exception('Error using voucher: $e');
    }
  }

  /// 13. Get all vouchers categorized
  /// Endpoint: GET /api/postData/vouchers/all-categorized or /api/getData/vouchers/all-categorized
  Future<Map<String, List<Voucher>>> getAllVouchersCategorized() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.allVouchersCategorized}'),
        headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final responseData = data['data'] as Map<String, dynamic>;
          return {
            'point_redemption': (responseData['point_vouchers'] as List?)
                    ?.map((v) => Voucher.fromJson(v))
                    .toList() ??
                [],
            'cash_purchase': (responseData['cash_vouchers'] as List?)
                    ?.map((v) => Voucher.fromJson(v))
                    .toList() ??
                [],
            'auto_granted': (responseData['free_vouchers'] as List?)
                    ?.map((v) => Voucher.fromJson(v))
                    .toList() ??
                [],
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading categorized vouchers directly: $e');
    }

    // Fallback: fetch from /api/getData/voucher and categorize locally
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.vouchers}'),
        headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final vouchers = (data['data'] as List)
              .map((v) => Voucher.fromJson(v as Map<String, dynamic>))
              .toList();
          final pointVouchers = vouchers.where((v) => v.point > 0).toList();
          final cashVouchers = vouchers.where((v) => v.price > 0).toList();
          final freeVouchers = vouchers.where((v) => v.point <= 0 && v.price <= 0).toList();
          return {
            'point_redemption': pointVouchers,
            'cash_purchase': cashVouchers,
            'auto_granted': freeVouchers.isNotEmpty ? freeVouchers : vouchers,
          };
        }
      }
    } catch (_) {}

    return {
      'point_redemption': [],
      'cash_purchase': [],
      'auto_granted': [],
    };
  }

  /// 14. Redeem birthday voucher
  /// Endpoint: POST /api/birthday-voucher
  Future<Map<String, dynamic>> redeemBirthdayVoucher() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.birthdayVoucher}'),
        headers: headers);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'detail_voucher_id': data['data']['detail_voucher_id'],
            'voucher': data['data']['voucher'] != null
                ? Voucher.fromJson(data['data']['voucher'])
                : null,
            'expiry_date': data['data']['expiry_date'],
            'message': data['message'] ?? 'Birthday voucher claimed successfully',
          };
        }
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to claim birthday voucher');
    } catch (e) {
      throw Exception('Error claiming birthday voucher: $e');
    }
  }

  /// Get user's points balance
  /// Endpoint: GET /api/getData/points
  Future<int> getUserPoints() async {
    try {
      final headers = await _getHeaders();
      debugPrint('💰 Fetching user points from: $baseUrl${ApiConstants.getUserPoints}');
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.getUserPoints}'),
        headers: headers);

      debugPrint('💰 Points Response Status: ${response.statusCode}');
      debugPrint('💰 Points Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('💰 Points Response Data: $data');
        
        if (data is Map<String, dynamic>) {
          // Try different response structures
          // Check if data is directly a number
          if (data['data'] is num) {
            final points = (data['data'] as num).toInt();
            debugPrint('✅ User has $points points (from data as num)');
            return points;
          }
          
          // Check nested data object
          if (data['data'] is Map<String, dynamic>) {
            final dataMap = data['data'] as Map<String, dynamic>;
            final points = (dataMap['point_balance'] as num?)?.toInt() ??
                   (dataMap['points_balance'] as num?)?.toInt() ??
                   (dataMap['points'] as num?)?.toInt() ?? 
                   (dataMap['point'] as num?)?.toInt() ?? 
                   (dataMap['balance'] as num?)?.toInt() ?? 0;
            debugPrint('✅ User has $points points (from data.points)');
            return points;
          }
          
          // Check top-level points fields
          final points = (data['point_balance'] as num?)?.toInt() ??
                 (data['points_balance'] as num?)?.toInt() ??
                 (data['points'] as num?)?.toInt() ?? 
                 (data['point'] as num?)?.toInt() ?? 
                 (data['balance'] as num?)?.toInt() ?? 0;
          debugPrint('✅ User has $points points (from top-level)');
          return points;
        }
      }
      debugPrint('⚠️ No points data found, returning 0');
      return 0;
    } catch (e, stack) {
      debugPrint('❌ Points Error: $e');
      debugPrint('❌ Stack trace: $stack');
      return 0;
    }
  }

  /// Get points history
  Future<List<PointHistory>> getPointsHistory() async {
    try {
      final headers = await _getHeaders();
      debugPrint('📜 Fetching points history from: $baseUrl${ApiConstants.getPointsHistory}');
      final response = await http.post(
        Uri.parse('$baseUrl${ApiConstants.getPointsHistory}'),
        headers: headers);

      debugPrint('📜 Points History Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📜 Points History Response: $data');
        
        if (data['data'] != null && data['data'] is List) {
          final history = data['data'] as List;
          debugPrint('✅ Found ${history.length} point history entries');
          return history.map((h) => PointHistory.fromJson(h as Map<String, dynamic>)).toList();
        }
      }
      debugPrint('⚠️ No points history found');
      return [];
    } catch (e) {
      debugPrint('❌ Points History Error: $e');
      return [];
    }
  }
}
