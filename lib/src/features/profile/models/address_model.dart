int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

class Address {
  final int id;
  final int userId;
  final String? recipientName;
  final String? phoneNumber;
  final String label; // e.g., "Home", "Office", "Apartment"
  final String address;
  final double latitude;
  final double longitude;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  Address({
    required this.id,
    required this.userId,
    this.recipientName,
    this.phoneNumber,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      recipientName: json['recipient_name']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0,
      notes: json['notes']?.toString(),
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now()
          : DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (recipientName != null) 'recipient_name': recipientName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (notes != null) 'notes': notes,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Address copyWith({
    int? id,
    int? userId,
    String? recipientName,
    String? phoneNumber,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      label: label ?? this.label,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt);
  }

  String get fullAddress {
    if (notes != null && notes!.isNotEmpty) {
      return '$address\n$notes';
    }
    return address;
  }
}

class AddAddressRequest {
  final String? recipientName;
  final String? phoneNumber;
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final String? notes;
  final bool isDefault;

  AddAddressRequest({
    this.recipientName,
    this.phoneNumber,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      if (recipientName != null && recipientName!.isNotEmpty)
        'recipient_name': recipientName,
      if (phoneNumber != null && phoneNumber!.isNotEmpty)
        'phone_number': phoneNumber,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'is_default': isDefault,
    };
  }
}

class NearestBranch {
  final int branchId;
  final String branchName;
  final String branchAddress;
  final double distance; // in kilometers
  final double latitude;
  final double longitude;

  NearestBranch({
    required this.branchId,
    required this.branchName,
    required this.branchAddress,
    required this.distance,
    required this.latitude,
    required this.longitude,
  });

  factory NearestBranch.fromJson(Map<String, dynamic> json) {
    return NearestBranch(
      branchId: _parseInt(json['branch_id']) ?? 0,
      branchName: json['branch_name']?.toString() ?? '',
      branchAddress: json['branch_address']?.toString() ?? '',
      distance: _parseDouble(json['distance']) ?? 0.0,
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0);
  }

  String get distanceDisplay {
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }
}
