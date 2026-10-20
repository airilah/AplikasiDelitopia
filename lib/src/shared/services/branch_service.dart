import '../../core/services/api_client.dart';
import '../models/branch_model.dart';

class BranchService {
  final ApiClient _apiClient;

  BranchService(this._apiClient);

  /// Get all branches
  /// GET /getData/branch
  Future<List<Branch>> getBranches() async {
    try {
      final response = await _apiClient.get('/getData/branch');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data.map((json) => Branch.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load branches');
    } catch (e) {
      throw Exception('Failed to load branches: $e');
    }
  }

  /// Get branches by brand
  /// POST /getData/branchByBrand
  /// 
  /// [brandId] - The brand ID, or "all" for all branches
  Future<List<Branch>> getBranchesByBrand(String brandId) async {
    try {
      final response = await _apiClient.post(
        '/getData/branchByBrand',
        data: {'brand': brandId});

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data.map((json) => Branch.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to load branches');
    } catch (e) {
      throw Exception('Failed to load branches: $e');
    }
  }
}
