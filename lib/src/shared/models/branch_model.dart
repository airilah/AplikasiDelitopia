import '../../core/utils/brand_name_formatter.dart';

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

class Branch {
  final int id;
  final int brandId;
  final String brandName;
  final String? brandLogo;
  final String? code;
  final String outlet;
  final String location;
  final String? address;
  final String? district;
  final String? posCode;
  final String openingHours;
  final String closingHours;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalReviews;

  Branch({
    required this.id,
    required this.brandId,
    required this.brandName,
    this.brandLogo,
    this.code,
    required this.outlet,
    required this.location,
    this.address,
    this.district,
    this.posCode,
    required this.openingHours,
    required this.closingHours,
    required this.latitude,
    required this.longitude,
    this.rating = 4.8,
    this.totalReviews = 0,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final brand = json['brand'];
    final rawBrandName = json['brand_name'] ?? (brand is Map ? brand['name'] : null);
    final brandLogo = json['brand_logo']?.toString() ??
        json['logo']?.toString() ??
        (brand is Map ? brand['logo']?.toString() : null);

    return Branch(
      id: _parseInt(json['id']) ?? 0,
      brandId: _parseInt(json['brand_id']) ?? 0,
      brandName: formatBrandName(rawBrandName ?? 'Unknown'),
      brandLogo: brandLogo,
      code: json['code']?.toString(),
      outlet: json['outlet']?.toString() ?? 'Unnamed Branch',
      location: json['location']?.toString() ?? 'Location not available',
      address: json['address']?.toString(),
      district: json['district']?.toString(),
      posCode: json['pos_code']?.toString(),
      openingHours: json['opening_hours']?.toString() ?? '00:00:00',
      closingHours: json['closing_hours']?.toString() ?? '23:59:59',
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0,
      rating: _parseDouble(json['rating']) ?? 4.8,
      totalReviews: _parseInt(json['total_reviews']) ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'brand_name': brandName,
      if (brandLogo != null) 'brand_logo': brandLogo,
      if (code != null) 'code': code,
      'outlet': outlet,
      'location': location,
      if (address != null) 'address': address,
      if (district != null) 'district': district,
      if (posCode != null) 'pos_code': posCode,
      'opening_hours': openingHours,
      'closing_hours': closingHours,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'total_reviews': totalReviews,
    };
  }

  // Helper getters
  double get lat => latitude;
  double get lng => longitude;

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  String get displayAddress {
    if (address != null && address!.trim().isNotEmpty) {
      return address!.trim();
    }
    if (location.trim().isNotEmpty) {
      return location.trim();
    }
    return outlet;
  }

  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (posCode != null && posCode!.isNotEmpty) parts.add(posCode!);
    return parts.isEmpty ? location : parts.join(', ');
  }
  
  bool get isOpenNow {
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    final opening = _parseTime(openingHours);
    final closing = _parseTime(closingHours);
    
    if (opening == null || closing == null) return true;
    
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final openingMinutes = opening.hour * 60 + opening.minute;
    final closingMinutes = closing.hour * 60 + closing.minute;
    
    return currentMinutes >= openingMinutes && currentMinutes <= closingMinutes;
  }
  
  TimeOfDay? _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }
}

class TimeOfDay {
  final int hour;
  final int minute;
  
  TimeOfDay({required this.hour, required this.minute});
}
