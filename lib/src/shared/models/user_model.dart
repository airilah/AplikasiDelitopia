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

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'verified';
  }
  return false;
}

class User {
  final int id;
  final String name;
  final String email;
  final String? photo;
  final String? birthday;
  final String? gender; // 'M' or 'F'
  final String? phoneNumber;
  final int point;
  final String? fcmToken;
  final String? isActive; // '1' or '0'
  final bool emailVerified;
  final bool phoneVerified;
  final bool hasPassword;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.photo,
    this.birthday,
    this.gender,
    this.phoneNumber,
    this.point = 0,
    this.fcmToken,
    this.isActive,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.hasPassword = false,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle is_active - can be bool or string
    String? isActiveValue;
    if (json['is_active'] != null) {
      if (json['is_active'] is bool) {
        isActiveValue = json['is_active'] ? '1' : '0';
      } else {
        isActiveValue = json['is_active']?.toString();
      }
    }

    final rawPhone = json['phone_number']?.toString();
    final bool isPhoneVerified = json['phone_verified'] != null
        ? _parseBool(json['phone_verified'])
        : (json['phone_verified_at'] != null);

    return User(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      photo: json['photo']?.toString(),
      birthday: json['birthday']?.toString(),
      gender: json['gender']?.toString(),
      phoneNumber: rawPhone,
      point: _parseInt(json['point']) ??
          _parseInt(json['points_balance']) ??
          _parseInt(json['points'] is Map<String, dynamic>
              ? (json['points'] as Map<String, dynamic>)['current']
              : null) ??
          0,
      fcmToken: json['fcm_token']?.toString(),
      isActive: isActiveValue,
      emailVerified: _parseBool(
        json['email_verified'] ?? (json['email_verified_at'] != null),
      ),
      phoneVerified: isPhoneVerified,
      hasPassword: _parseBool(json['has_password']),
      profileCompleted: _parseBool(json['profile_completed']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (photo != null) 'photo': photo,
      if (birthday != null) 'birthday': birthday,
      if (gender != null) 'gender': gender,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'point': point,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (isActive != null) 'is_active': isActive,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'has_password': hasPassword,
      'profile_completed': profileCompleted,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? photo,
    String? birthday,
    String? gender,
    String? phoneNumber,
    int? point,
    String? fcmToken,
    String? isActive,
    bool? emailVerified,
    bool? phoneVerified,
    bool? hasPassword,
    bool? profileCompleted,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      point: point ?? this.point,
      fcmToken: fcmToken ?? this.fcmToken,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      hasPassword: hasPassword ?? this.hasPassword,
      profileCompleted: profileCompleted ?? this.profileCompleted);
  }

  // Getter for compatibility
  String? get photoUrl => photo;

  // Helper getters
  bool get active => isActive == '1';
  bool get isMale => gender == 'M';
  bool get isFemale => gender == 'F';

  String get displayGender {
    if (gender == 'M') return 'Male';
    if (gender == 'F') return 'Female';
    return 'Not specified';
  }
}

class Address {
  final int? id;
  final String label;
  final String fullAddress;
  final String? recipientName;
  final String? recipientPhone;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  Address({
    this.id,
    required this.label,
    required this.fullAddress,
    this.recipientName,
    this.recipientPhone,
    this.latitude,
    this.longitude,
    this.notes,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: _parseInt(json['id']),
      label: json['label']?.toString() ?? '',
      fullAddress:
          json['full_address']?.toString() ?? json['address']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      latitude: _parseDouble(json['latitude']) ?? _parseDouble(json['lat']),
      longitude: _parseDouble(json['longitude']) ?? _parseDouble(json['long']),
      notes: json['notes']?.toString(),
      isDefault: json['is_default'] == 1 ||
          json['is_default'] == true ||
          json['is_default'] == '1');
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'full_address': fullAddress,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'is_default': isDefault,
    };
  }
}
