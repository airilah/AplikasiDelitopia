import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';

// Provider for all addresses
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  final addressService = ref.watch(addressServiceProvider);
  return addressService.getAddresses();
});

// Provider for default address
final defaultAddressProvider = FutureProvider<Address?>((ref) async {
  final addressService = ref.watch(addressServiceProvider);
  return addressService.getDefaultAddress();
});

// Provider for nearest branches
final nearestBranchesProvider = FutureProvider.family<List<NearestBranch>, ({double latitude, double longitude})>(
  (ref, params) async {
    final addressService = ref.watch(addressServiceProvider);
    return addressService.findNearestBranches(
      latitude: params.latitude,
      longitude: params.longitude);
  });

// Controller for address operations
class AddressController extends StateNotifier<AsyncValue<List<Address>>> {
  final AddressService _addressService;
  final Ref _ref;

  AddressController(this._addressService, this._ref) : super(const AsyncValue.loading()) {
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    state = const AsyncValue.loading();
    try {
      final addresses = await _addressService.getAddresses();
      state = AsyncValue.data(addresses);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Address> addAddress(AddAddressRequest request) async {
    try {
      final address = await _addressService.addAddress(request);
      await _loadAddresses();
      _ref.invalidate(addressesProvider);
      _ref.invalidate(defaultAddressProvider);
      return address;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Address> updateAddress(int addressId, AddAddressRequest request) async {
    try {
      final address = await _addressService.updateAddress(addressId, request);
      await _loadAddresses();
      _ref.invalidate(addressesProvider);
      _ref.invalidate(defaultAddressProvider);
      return address;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteAddress(int addressId) async {
    try {
      await _addressService.deleteAddress(addressId);
      await _loadAddresses();
      _ref.invalidate(addressesProvider);
      _ref.invalidate(defaultAddressProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> setDefaultAddress(int addressId) async {
    try {
      await _addressService.setDefaultAddress(addressId);
      await _loadAddresses();
      _ref.invalidate(addressesProvider);
      _ref.invalidate(defaultAddressProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadAddresses();
    _ref.invalidate(addressesProvider);
    _ref.invalidate(defaultAddressProvider);
  }
}

// Address controller provider
final addressControllerProvider = StateNotifierProvider<AddressController, AsyncValue<List<Address>>>((ref) {
  final addressService = ref.watch(addressServiceProvider);
  return AddressController(addressService, ref);
});
