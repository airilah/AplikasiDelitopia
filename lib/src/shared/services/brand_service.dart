import '../../core/services/api_client.dart';
import '../models/brand_model.dart';

class BrandService {
  final ApiClient _apiClient;

  BrandService(this._apiClient);

  /// Get all brands
  /// GET /getData/brand
  Future<List<Brand>> getBrands() async {
    try {
      final response = await _apiClient.get('/getData/brand');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data.map((json) => Brand.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load brands');
    } catch (e) {
      throw Exception('Failed to load brands: $e');
    }
  }
}
