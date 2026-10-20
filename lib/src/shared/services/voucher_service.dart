import 'package:dio/dio.dart';
import '../../core/services/api_client.dart';
import '../models/voucher_model.dart';

class VoucherService {
  final ApiClient _apiClient;

  VoucherService(this._apiClient);

  /// Get available vouchers (not yet redeemed by user)
  /// GET /getData/voucher
  Future<List<Voucher>> getAvailableVouchers() async {
    try {
      final response = await _apiClient.get('/getData/voucher');
      
      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => Voucher.fromJson(json)).toList();
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch vouchers');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  /// Get all vouchers (admin endpoint)
  /// GET /getData/voucher-list
  Future<List<Voucher>> getAllVouchers() async {
    try {
      final response = await _apiClient.get('/getData/voucher-list');
      
      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => Voucher.fromJson(json)).toList();
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch vouchers');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  /// Get voucher details
  /// GET /getData/voucher-show/{id}
  Future<Voucher> getVoucherDetails(int id) async {
    try {
      final response = await _apiClient.get('/getData/voucher-show/$id');
      
      if (response['status'] == 'success') {
        return Voucher.fromJson(response['data']);
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch voucher details');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  /// Get user vouchers
  /// POST /getData/user-voucher
  Future<List<UserVoucher>> getUserVouchers(int userId) async {
    try {
      final response = await _apiClient.post(
        '/getData/user-voucher',
        data: {'user_id': userId});
      
      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] ?? [];
        return data.map((json) => UserVoucher.fromJson(json)).toList();
      }
      
      throw Exception(response['message'] ?? 'Failed to fetch user vouchers');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  /// Redeem voucher with points
  /// POST /postData/use-voucher
  Future<void> redeemVoucher({
    required int userId,
    required int voucherId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/postData/use-voucher',
        data: {
          'user_id': userId,
          'voucher_id': voucherId,
        });
      
      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to redeem voucher');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }

  /// Redeem birthday voucher
  /// POST /birthday-voucher
  Future<void> redeemBirthdayVoucher({
    required int userId,
    required int voucherId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/birthday-voucher',
        data: {
          'user_id': userId,
          'voucher_id': voucherId,
        });
      
      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to redeem birthday voucher');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Network error: ${e.message}');
    }
  }
}

