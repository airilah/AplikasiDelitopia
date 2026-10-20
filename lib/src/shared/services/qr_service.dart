import '../../core/services/api_client.dart';
import '../models/qr_model.dart';

class QRService {
  final ApiClient _apiClient;

  QRService(this._apiClient);

  /// Get all QR codes
  /// GET /getData/qr
  Future<List<QRCode>> getAllQR() async {
    try {
      final response = await _apiClient.get('/getData/qr');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data.map((json) => QRCode.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load QR codes');
    } catch (e) {
      throw Exception('Failed to load QR codes: $e');
    }
  }

  /// Get QR code details
  /// GET /getData/qr-show/{id}
  Future<QRCode> getQRDetails(int id) async {
    try {
      final response = await _apiClient.get('/getData/qr-show/$id');

      if (response['status'] == 'success') {
        return QRCode.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to load QR code details');
    } catch (e) {
      throw Exception('Failed to load QR code details: $e');
    }
  }

  /// Create QR code
  /// POST /postData/create-qr
  Future<Map<String, dynamic>> createQR({
    required int brandId,
    required int branchId,
    required String tableNumber,
  }) async {
    try {
      final response = await _apiClient.post(
        '/postData/create-qr',
        data: {
          'brand': brandId,
          'branch': branchId,
          'table_number': tableNumber,
        });

      if (response['status'] == 'success') {
        return response['data'] as Map<String, dynamic>;
      }

      throw Exception(response['message'] ?? 'Failed to create QR code');
    } catch (e) {
      throw Exception('Failed to create QR code: $e');
    }
  }

  /// Decode QR code
  /// POST /postData/decode-qr
  Future<QRDecoded> decodeQR(String qrText) async {
    try {
      final response = await _apiClient.post(
        '/postData/decode-qr',
        data: {'qr_text': qrText});

      if (response['status'] == 'success') {
        return QRDecoded.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response['message'] ?? 'Failed to decode QR code');
    } catch (e) {
      throw Exception('Failed to decode QR code: $e');
    }
  }
}
