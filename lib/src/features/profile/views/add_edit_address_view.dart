import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/services/service_providers.dart';
import '../controllers/address_controller.dart';
import '../models/address_model.dart';
import 'address_map_picker_view.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class AddEditAddressView extends ConsumerStatefulWidget {
  final String? addressId;
  const AddEditAddressView({super.key, this.addressId});

  @override
  ConsumerState<AddEditAddressView> createState() => _AddEditAddressViewState();
}

class _AddEditAddressViewState extends ConsumerState<AddEditAddressView> {
  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  AppLanguage get _lang => ref.read(appLanguageProvider);

  bool _isDefault = false;
  bool _isLoading = false;
  bool _userDataLoaded = false;

  // Map/location state
  LatLng? _selectedPosition;
  String _detectedAddress = '';
  GoogleMapController? _mapController;

  // Autocomplete state
  List<dynamic> _addressSuggestions = [];
  Timer? _debounceTimer;
  bool _isSearchingAddress = false;


  static const Color _primaryColor = Color(0xFFDD2222);

  @override
  void initState() {
    super.initState();
    if (widget.addressId != null) {
      _loadAddress();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-fill user data when first opened (only for new address)
    if (!_userDataLoaded && widget.addressId == null) {
      _prefillUserData();
    }
  }

  void _prefillUserData() {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _recipientNameController.text = user.name;
      _phoneController.text = user.phoneNumber ?? '';
      setState(() => _userDataLoaded = true);
    }
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _labelController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAutocompleteSuggestions(String input) async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (input.trim().length < 3) {
      setState(() {
        _addressSuggestions = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearchingAddress = true;
      });

      try {
        final apiKey = AppConfig.googleMapsApiKey;
        final dio = Dio();
        final response = await dio.get(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json',
          queryParameters: {
            'input': input,
            'key': apiKey,
            'components': 'country:id',
            'language': 'id',
          });

        if (response.data != null && response.data['status'] == 'OK') {
          setState(() {
            _addressSuggestions = response.data['predictions'] as List<dynamic>;
          });
        } else {
          debugPrint('Places Autocomplete API Error or No Results: ${response.data}');
          setState(() {
            _addressSuggestions = [];
          });
        }
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        setState(() {
          _addressSuggestions = [];
        });
      } finally {
        setState(() {
          _isSearchingAddress = false;
        });
      }
    });
  }

  Future<void> _getLatLngFromPlaceId(String placeId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = AppConfig.googleMapsApiKey;
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry',
          'key': apiKey,
        });

      if (response.data != null && response.data['status'] == 'OK') {
        final location = response.data['result']['geometry']['location'];
        final double lat = location['lat'];
        final double lng = location['lng'];
        final latLng = LatLng(lat, lng);

        setState(() {
          _selectedPosition = latLng;
        });

        // Animate map camera to the new coordinates
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16));
      } else {
        debugPrint('Place Details API Error: ${response.data}');
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await ref.read(addressesProvider.future);
      final address = addresses.firstWhere((a) => a.id.toString() == widget.addressId);

      setState(() {
        _recipientNameController.text = address.recipientName ?? '';
        _phoneController.text = address.phoneNumber ?? '';
        _labelController.text = address.label;
        _addressController.text = address.address;
        _notesController.text = address.notes ?? '';
        _isDefault = address.isDefault;
        if (address.latitude != 0.0 && address.longitude != 0.0) {
          _selectedPosition = LatLng(address.latitude, address.longitude);
          _detectedAddress = address.address;
        }
        _userDataLoaded = true;
      });

      // If no user data pre-filled, auto-fill from current user
      if (_recipientNameController.text.isEmpty) {
        _prefillUserData();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackbar(context, '${_lang == AppLanguage.indonesia ? 'Gagal memuat alamat' : 'Error loading address'}: ${e.toString()}');
      }
    }
  }

  Future<void> _pickLocationFromMap() async {
    final tempAddress = Address(
      id: 0,
      userId: 0,
      label: _labelController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      latitude: _selectedPosition?.latitude ?? -6.175110,
      longitude: _selectedPosition?.longitude ?? 106.827153,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPickerView(initialAddress: tempAddress),
      ));

    if (result != null) {
      setState(() {
        if (_labelController.text.isEmpty && result['label'] != null) {
          _labelController.text = result['label'] as String;
        }
        if (result['address'] != null) {
          _addressController.text = result['address'] as String;
        }
        if (_notesController.text.isEmpty && result['notes'] != null) {
          _notesController.text = result['notes'] as String;
        }
        final lat = result['latitude'] as double?;
        final lng = result['longitude'] as double?;
        if (lat != null && lng != null) {
          _selectedPosition = LatLng(lat, lng);
          _detectedAddress = result['address'] as String? ?? '';
        }
      });
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addressController.text.trim().isEmpty) {
      _showSnack(_lang == AppLanguage.indonesia ? 'Mohon isi alamat lengkap' : 'Please fill in the full address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = AddAddressRequest(
        recipientName: _recipientNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        label: _labelController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        latitude: _selectedPosition?.latitude ?? 0.0,
        longitude: _selectedPosition?.longitude ?? 0.0,
        isDefault: _isDefault);

      if (widget.addressId != null) {
        await ref
            .read(addressControllerProvider.notifier)
            .updateAddress(int.parse(widget.addressId!), request);
      } else {
        await ref.read(addressControllerProvider.notifier).addAddress(request);
      }

      if (mounted) {
        _showSnack(
          _lang == AppLanguage.indonesia
              ? (widget.addressId != null ? 'Alamat berhasil diperbarui' : 'Alamat berhasil ditambahkan')
              : (widget.addressId != null ? 'Address updated successfully' : 'Address added successfully'));
        BackButtonWrapper.handleBack(context, backRoute: '/profile/addresses');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    Helpers.showSnackbar(context, msg, backgroundColor: isError ? Colors.red : Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.addressId != null;
    final lang = ref.watch(appLanguageProvider);
    // Watch user provider to auto-fill when data arrives
    final userAsync = ref.watch(currentUserProvider);
    userAsync.whenData((user) {
      if (!_userDataLoaded && user != null && widget.addressId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_userDataLoaded) {
            setState(() {
              _recipientNameController.text = user.name;
              _phoneController.text = user.phoneNumber ?? '';
              _userDataLoaded = true;
            });
          }
        });
      }
    });

    return BackButtonWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          leading: AppBackButton(
            backRoute: '/profile/addresses',
            color: Colors.white,
          ),
          title: Text(
            isEdit
                ? (lang == AppLanguage.indonesia ? 'UBAH ALAMAT' : 'EDIT ADDRESS')
                : (lang == AppLanguage.indonesia ? 'TAMBAH ALAMAT' : 'ADD ADDRESS'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ), backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ─── Section: Data Penerima ───
              _sectionHeader(lang == AppLanguage.indonesia ? 'Data Penerima' : 'Recipient Info'),
              _sectionCard([
                // Nama Lengkap (editable)
                _buildField(
                  controller: _recipientNameController,
                  label: lang == AppLanguage.indonesia ? 'Nama Lengkap' : 'Full Name',
                  hint: lang == AppLanguage.indonesia ? 'Nama penerima paket' : 'Recipient full name',
                  icon: Icons.person_outline_rounded,
                  helperText: lang == AppLanguage.indonesia ? 'Bisa diubah jika membelikan orang lain' : 'Can be changed if buying for others',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? (lang == AppLanguage.indonesia ? 'Nama lengkap wajib diisi' : 'Full name is required') : null,
                ),
                const Divider(height: 1, indent: 52),
                // Nomor Telepon (disabled)
                _buildField(
                  controller: _phoneController,
                  label: lang == AppLanguage.indonesia ? 'Nomor Telepon' : 'Phone Number',
                  hint: lang == AppLanguage.indonesia ? 'Nomor telepon terdaftar' : 'Registered phone number',
                  icon: Icons.phone_outlined,
                  enabled: false,
                  keyboardType: TextInputType.phone,
                  helperText: lang == AppLanguage.indonesia ? 'Nomor telepon tidak dapat diubah' : 'Phone number cannot be changed',
                ),
              ]),

              // ─── Section: Detail Alamat ───
              _sectionHeader(lang == AppLanguage.indonesia ? 'Detail Alamat' : 'Address Details'),
              _sectionCard([
                // Label
                _buildField(
                  controller: _labelController,
                  label: lang == AppLanguage.indonesia ? 'Label Alamat' : 'Address Label',
                  hint: lang == AppLanguage.indonesia ? 'Contoh: Rumah, Kantor, Apartemen' : 'Example: Home, Office, Apartment',
                  icon: Icons.label_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? (lang == AppLanguage.indonesia ? 'Label wajib diisi' : 'Label is required') : null,
                ),
                // Quick label chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    children: (lang == AppLanguage.indonesia
                            ? ['Rumah', 'Kantor', 'Apartemen', 'Kos']
                            : ['Home', 'Office', 'Apartment', 'Room'])
                        .map((label) {
                      return GestureDetector(
                        onTap: () => setState(() => _labelController.text = label),
                        child: Chip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          backgroundColor: _labelController.text == label
                              ? _primaryColor.withValues(alpha: 0.15)
                              : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: _labelController.text == label
                                ? _primaryColor
                                : Colors.grey[700],
                            fontWeight: _labelController.text == label
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: _labelController.text == label
                                ? _primaryColor
                                : Colors.transparent,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, indent: 52),
                // Alamat Lengkap
                _buildField(
                  controller: _addressController,
                  label: lang == AppLanguage.indonesia ? 'Nama Jalan, Gedung, No. Rumah' : 'Street name, Building, House No.',
                  hint: lang == AppLanguage.indonesia ? 'Contoh: Jl. Ahmad Yani No.234, Gayungan, Kec. Gayungan, Surabaya, Jawa Timur 60235' : 'Example: Jl. Ahmad Yani No.234, Gayungan, Kec. Gayungan, Surabaya, Jawa Timur 60235',
                  icon: Icons.home_outlined,
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? (lang == AppLanguage.indonesia ? 'Alamat wajib diisi' : 'Address is required') : null,
                  onChanged: _fetchAutocompleteSuggestions,
                ),
                if (_isSearchingAddress)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang == AppLanguage.indonesia ? 'Mencari rekomendasi alamat...' : 'Searching address recommendations...',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else if (_addressSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _addressSuggestions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _addressSuggestions[index];
                        final description = suggestion['description'] as String;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                          title: Text(
                            description,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            _addressController.text = description;
                            final placeId = suggestion['place_id'] as String;
                            _getLatLngFromPlaceId(placeId);
                            setState(() {
                              _detectedAddress = description;
                              _addressSuggestions = [];
                            });
                          });
                      },
                    ),
                  ),
                const Divider(height: 1, indent: 52),
                // Catatan
                _buildField(
                  controller: _notesController,
                  label: lang == AppLanguage.indonesia ? 'Detail Lainnya (Opsional)' : 'Other Details (Optional)',
                  hint: lang == AppLanguage.indonesia ? 'Contoh: Blok A No.5, Patokan: sebelah warung Bu Siti' : 'Example: Block A No.5, Landmark: next to the shop',
                  icon: Icons.notes_outlined,
                  maxLines: 2,
                ),
              ]),

              // ─── Section: Titik Lokasi ───
              _sectionHeader(lang == AppLanguage.indonesia ? 'Titik Lokasi' : 'Location Pin'),
              _buildMapSection(lang),

              // ─── Section: Pengaturan ───
              _sectionHeader(lang == AppLanguage.indonesia ? 'Pengaturan' : 'Settings'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    lang == AppLanguage.indonesia ? 'Jadikan Alamat Utama' : 'Set as Main Address',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _isDefault
                        ? (lang == AppLanguage.indonesia ? 'Alamat ini akan digunakan sebagai default' : 'This address will be used as default')
                        : (lang == AppLanguage.indonesia ? 'Aktifkan untuk jadikan alamat utama' : 'Enable to set as main address'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _isDefault,
                  activeThumbColor: _primaryColor,
                  onChanged: (v) => setState(() => _isDefault = v),
                  secondary: Icon(
                    _isDefault ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _isDefault ? _primaryColor : Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ─── Save Button ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isEdit
                                ? (lang == AppLanguage.indonesia ? 'Simpan Perubahan' : 'Save Changes')
                                : (lang == AppLanguage.indonesia ? 'Simpan Alamat' : 'Save Address'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                  ),
                ),
              ),

              if (isEdit) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _confirmDelete(lang),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        lang == AppLanguage.indonesia ? 'Hapus Alamat' : 'Delete Address',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ));
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF888888),
          letterSpacing: 0.5,
        ),
      ));
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: enabled ? Colors.black87 : Colors.grey[600],
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          labelStyle: TextStyle(
            fontSize: 13,
            color: enabled ? Colors.grey[700] : Colors.grey[400],
          ),
          prefixIcon: Icon(icon, color: enabled ? _primaryColor : Colors.grey[400], size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          helperText: helperText,
          helperStyle: TextStyle(fontSize: 11, color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        ),
      ));
  }

  Widget _buildMapSection(AppLanguage lang) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: _selectedPosition != null
                ? SizedBox(
                    height: 160,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedPosition!,
                        zoom: 16,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: _selectedPosition!,
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      liteModeEnabled: false,
                    ),
                  )
                : Container(
                    height: 140,
                    color: Colors.grey[100],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            lang == AppLanguage.indonesia ? 'Lokasi belum dipilih' : 'Location not selected',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Detected address display
          if (_selectedPosition != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xFFDD2222), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                            _detectedAddress.isNotEmpty
                                ? _detectedAddress
                                : 'Koordinat: ${_selectedPosition!.latitude.toStringAsFixed(5)}, '
                                    '${_selectedPosition!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                  ),
                ],
              ),
            ),

          // Pick location button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickLocationFromMap,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _selectedPosition != null
                      ? (lang == AppLanguage.indonesia ? 'Ubah Titik Lokasi' : 'Change Pin Location')
                      : (lang == AppLanguage.indonesia ? 'Pilih Titik Lokasi di Peta' : 'Select Pin Location on Map'),
                  style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: const BorderSide(color: Color(0xFFDD2222)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ));
  }

  void _confirmDelete(AppLanguage lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == AppLanguage.indonesia ? 'Hapus Alamat' : 'Delete Address'),
        content: Text(lang == AppLanguage.indonesia ? 'Yakin ingin menghapus alamat ini?' : 'Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == AppLanguage.indonesia ? 'Batal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await ref
                    .read(addressControllerProvider.notifier)
                    .deleteAddress(int.parse(widget.addressId!));
                if (mounted) {
                  _showSnack(_lang == AppLanguage.indonesia ? 'Alamat berhasil dihapus' : 'Address deleted successfully');
                  BackButtonWrapper.handleBack(context,
                      backRoute: '/profile/addresses');
                }
              } catch (e) {
                if (mounted) {
                  _showSnack('${_lang == AppLanguage.indonesia ? 'Gagal menghapus' : 'Failed to delete'}: ${e.toString()}', isError: true);
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text(lang == AppLanguage.indonesia ? 'Hapus' : 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ));
  }
}

