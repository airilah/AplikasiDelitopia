import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_language.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../models/address_model.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class AddressMapPickerView extends ConsumerStatefulWidget {
  final Address? initialAddress;

  const AddressMapPickerView({
    super.key,
    this.initialAddress,
  });

  @override
  ConsumerState<AddressMapPickerView> createState() => _AddressMapPickerViewState();
}

class _AddressMapPickerViewState extends ConsumerState<AddressMapPickerView> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(-6.175110, 106.827153); // Default Jakarta
  String _selectedAddress = '';
  bool _isLoadingAddress = false;
  final _addressController = TextEditingController();
  final _labelController = TextEditingController();
  final _notesController = TextEditingController();
  AppLanguage get _lang => ref.read(appLanguageProvider);

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _selectedPosition = LatLng(
        widget.initialAddress!.latitude,
        widget.initialAddress!.longitude);
      _selectedAddress = widget.initialAddress!.address;
      _addressController.text = widget.initialAddress!.address;
      _labelController.text = widget.initialAddress!.label;
      _notesController.text = widget.initialAddress!.notes ?? '';
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _addressController.dispose();
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Skip location services on web
      if (kIsWeb) {
        // Use default Jakarta coordinates for web
        setState(() {
          _selectedPosition = const LatLng(-6.175110, 106.827153);
        });
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedPosition = newPosition;
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPosition));
      
      await _getAddressFromLatLng(newPosition);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.postalCode,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address;
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
    _getAddressFromLatLng(position);
  }

  void _saveAddress() {
    if (_addressController.text.isEmpty) {
      Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Silakan masukkan alamat' : 'Please enter an address');
      return;
    }

    if (_labelController.text.isEmpty) {
      Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Silakan masukkan label (misal: Rumah, Kantor)' : 'Please enter a label (e.g., Home, Office)');
      return;
    }

    // Return the address data to the previous screen
    Navigator.pop(context, {
      'address': _addressController.text,
      'label': _labelController.text,
      'notes': _notesController.text,
      'latitude': _selectedPosition.latitude,
      'longitude': _selectedPosition.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    // Use simplified form for web (Google Maps doesn't work well on Flutter web)
    if (kIsWeb) {
      return _buildWebAddressForm(context, lang);
    }
    
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          backRoute: '/profile/addresses',
          color: Colors.white,
        ),
        title: Text(lang == AppLanguage.indonesia ? 'PILIH LOKASI PENGIRIMAN' : 'SELECT DELIVERY LOCATION'),
        backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map View
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedPosition, 16),
                    );
                  },
                  onTap: _onMapTap,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedPosition,
                      draggable: true,
                      onDragEnd: (newPosition) {
                        setState(() {
                          _selectedPosition = newPosition;
                        });
                        _getAddressFromLatLng(newPosition);
                      },
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // Current Location Button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location, color: Color(0xFFDD2222)),
                  ),
                ),
              ],
            ),
          ),
          // Address Form
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Preview
                    if (_isLoadingAddress)
                      const Center(child: CircularProgressIndicator())
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFDD2222)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAddress.isEmpty
                                    ? (lang == AppLanguage.indonesia ? 'Pilih lokasi di peta' : 'Select location on map')
                                    : _selectedAddress,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Label Input
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        labelText: lang == AppLanguage.indonesia ? 'Label Alamat' : 'Address Label',
                        hintText: lang == AppLanguage.indonesia ? 'misal: Rumah, Kantor, Apartemen' : 'e.g., Home, Office, Apartment',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Address Input
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: lang == AppLanguage.indonesia ? 'Alamat Lengkap' : 'Full Address',
                        hintText: lang == AppLanguage.indonesia ? 'Jalan, Nomor, RT/RW, dll' : 'Street, Number, RT/RW, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.home),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // Notes Input
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: lang == AppLanguage.indonesia ? 'Catatan (Opsional)' : 'Notes (Optional)',
                        hintText: lang == AppLanguage.indonesia ? 'Patokan, warna rumah, dll' : 'Landmark, house color, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD2222),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          lang == AppLanguage.indonesia ? 'Gunakan Alamat Ini' : 'Use This Address',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simplified web form without Google Maps
  Widget _buildWebAddressForm(BuildContext context, AppLanguage lang) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          backRoute: '/profile/addresses',
          color: Colors.white,
        ),
        title: Text(lang == AppLanguage.indonesia ? 'PILIH LOKASI PENGIRIMAN' : 'SELECT DELIVERY LOCATION'), backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang == AppLanguage.indonesia
                          ? 'Masukkan alamat lengkap dan koordinat lokasi pengiriman'
                          : 'Enter the complete address and delivery coordinates',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Label Input
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: lang == AppLanguage.indonesia ? 'Label Alamat *' : 'Address Label *',
                hintText: lang == AppLanguage.indonesia ? 'misal: Rumah, Kantor, Apartemen' : 'e.g., Home, Office, Apartment',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            
            // Address Input
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: lang == AppLanguage.indonesia ? 'Alamat Lengkap *' : 'Full Address *',
                hintText: lang == AppLanguage.indonesia ? 'Jalan, Nomor, RT/RW, Kelurahan, Kecamatan' : 'Street, Number, RT/RW, Village, Sub-district',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.home),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Latitude Input
            TextField(
              decoration: InputDecoration(
                labelText: 'Latitude *',
                hintText: 'e.g., -6.175110',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.map),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (value) {
                final lat = double.tryParse(value);
                if (lat != null) {
                  setState(() {
                    _tempDeliveryLat = lat;
                    _selectedPosition = LatLng(lat, _tempDeliveryLong ?? 106.827153);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Longitude Input
            TextField(
              decoration: InputDecoration(
                labelText: 'Longitude *',
                hintText: 'e.g., 106.827153',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.map),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (value) {
                final long = double.tryParse(value);
                if (long != null) {
                  setState(() {
                    _tempDeliveryLong = long;
                    _selectedPosition = LatLng(_tempDeliveryLat ?? -6.175110, long);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            
            // Helper text
            Text(
              lang == AppLanguage.indonesia
                  ? 'Tip: Gunakan Google Maps untuk mendapatkan koordinat yang akurat'
                  : 'Tip: Use Google Maps to get accurate coordinates',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            // Notes Input
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: lang == AppLanguage.indonesia ? 'Catatan (Opsional)' : 'Notes (Optional)',
                hintText: lang == AppLanguage.indonesia ? 'Patokan, warna rumah, dll' : 'Landmark, house color, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_addressController.text.isEmpty) {
                    Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Silakan masukkan alamat' : 'Please enter an address');
                    return;
                  }

                  if (_labelController.text.isEmpty) {
                    Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Silakan masukkan label' : 'Please enter a label');
                    return;
                  }

                  if (_tempDeliveryLat == null || _tempDeliveryLong == null) {
                    Helpers.showSnackbar(context, _lang == AppLanguage.indonesia ? 'Silakan masukkan koordinat yang valid' : 'Please enter valid coordinates');
                    return;
                  }

                  Navigator.pop(context, {
                    'address': _addressController.text,
                    'label': _labelController.text,
                    'notes': _notesController.text,
                    'latitude': _tempDeliveryLat,
                    'longitude': _tempDeliveryLong,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  lang == AppLanguage.indonesia ? 'Gunakan Alamat Ini' : 'Use This Address',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
  }
  
  // State variables for web form
  double? _tempDeliveryLat;
  double? _tempDeliveryLong;
}
