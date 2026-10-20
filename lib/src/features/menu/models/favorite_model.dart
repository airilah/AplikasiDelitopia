import '../../../core/utils/brand_name_formatter.dart';

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

class Favorite {
  final int id;
  final int userId;
  final int menuId;
  final int? menuTemplateId;
  final int? branchId;
  final String menuName;
  final String? menuImage;
  final double menuPrice;
  final String brandName;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.userId,
    required this.menuId,
    this.menuTemplateId,
    this.branchId,
    required this.menuName,
    this.menuImage,
    required this.menuPrice,
    required this.brandName,
    required this.createdAt,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    final menu = json['menu'] is Map<String, dynamic>
        ? json['menu'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return Favorite(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      menuId: _parseInt(json['menu_id']) ?? _parseInt(menu['id']) ?? 0,
      menuTemplateId:
          _parseInt(json['menu_template_id']) ?? _parseInt(menu['menu_template_id']),
      branchId: _parseInt(json['branch_id']) ??
          _parseInt(menu['branch_id']) ??
          _parseInt(menu['branches_id']),
      menuName: json['menu_name']?.toString() ?? menu['name']?.toString() ?? '',
      menuImage: json['menu_image']?.toString() ??
          menu['photo']?.toString() ??
          menu['image']?.toString(),
      menuPrice: _parseDouble(json['menu_price']) ??
          _parseDouble(menu['price']) ??
          0.0,
      brandName:
          formatBrandName(json['brand_name'] ?? menu['brand_name'] ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'menu_id': menuId,
      if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
      if (branchId != null) 'branch_id': branchId,
      'menu_name': menuName,
      if (menuImage != null) 'menu_image': menuImage,
      'menu_price': menuPrice,
      'brand_name': brandName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AddFavoriteRequest {
  final int menuId;
  final int? menuTemplateId;
  final int? branchId;
  final String menuName;
  final double menuPrice;

  AddFavoriteRequest({
    required this.menuId,
    this.menuTemplateId,
    this.branchId,
    required this.menuName,
    required this.menuPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
      if (branchId != null) 'branch_id': branchId,
      'menu_name': menuName,
      'menu_price': menuPrice,
    };
  }
}
