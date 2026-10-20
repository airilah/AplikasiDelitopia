import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/address_model.dart';

final addressServiceProvider = Provider<AddressService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AddressService(apiClient);
});

class AddressService {
  final ApiClient _apiClient;

  AddressService(this._apiClient);

  /// Get all user addresses
  Future<List<Address>> getAddresses() async {
    try {
      final response = await _apiClient.get('/getData/addresses');

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        return data.map((json) => Address.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to get addresses');
    } catch (e) {
      throw Exception('Failed to get addresses: $e');
    }
  }

  /// Add new address
  Future<Address> addAddress(AddAddressRequest request) async {
    try {
      final response = await _apiClient.post(
        '/postData/address',
        data: request.toJson());

      if (response['status'] == 'success') {
        return Address.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to add address');
    } catch (e) {
      throw Exception('Failed to add address: $e');
    }
  }

  /// Update address
  Future<Address> updateAddress(int addressId, AddAddressRequest request) async {
    try {
      final response = await _apiClient.put(
        '/postData/address/$addressId',
        data: request.toJson());

      if (response['status'] == 'success') {
        return Address.fromJson(response['data']);
      }

      throw Exception(response['message'] ?? 'Failed to update address');
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  /// Delete address
  Future<void> deleteAddress(int addressId) async {
    try {
      final response = await _apiClient.delete('/postData/address/$addressId');

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to delete address');
      }
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  /// Set address as default (exclusive - all others become non-default)
  Future<void> setDefaultAddress(int addressId) async {
    try {
      final response = await _apiClient.post(
        '/postData/address/$addressId/set-default',
        data: {});

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to set default address');
      }
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }

  /// Find nearest branches to given location
  Future<List<NearestBranch>> findNearestBranches({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/postData/addresses/nearest-branches',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        });

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'] as List;
        return data.map((json) => NearestBranch.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw Exception(response['message'] ?? 'Failed to find nearest branches');
    } catch (e) {
      throw Exception('Failed to find nearest branches: $e');
    }
  }

  /// Get default address
  Future<Address?> getDefaultAddress() async {
    try {
      final addresses = await getAddresses();
      return addresses.firstWhere(
        (address) => address.isDefault,
        orElse: () => addresses.isNotEmpty ? addresses.first : throw Exception('No address found'));
    } catch (e) {
      return null;
    }
  }
}
