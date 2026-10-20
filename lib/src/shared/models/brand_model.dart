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

class Brand {
  final int id;
  final String name;
  final String logo;
  final int service;
  final int tax;
  final List<String> category;

  Brand({
    required this.id,
    required this.name,
    required this.logo,
    required this.service,
    required this.tax,
    required this.category,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: _parseInt(json['id']) ?? 0,
      name: formatBrandName(json['name']),
      logo: json['logo']?.toString() ?? '',
      service: _parseInt(json['service']) ?? 0,
      tax: _parseInt(json['tax']) ?? 0,
      category: (json['category'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? []);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'service': service,
      'tax': tax,
      'category': category,
    };
  }

  // Helper getters
  double get servicePercentage => service / 100.0;
  double get taxPercentage => tax / 100.0;
}
