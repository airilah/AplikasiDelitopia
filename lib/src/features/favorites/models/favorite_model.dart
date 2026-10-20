import '../../../shared/models/menu_model.dart';

class Favorite {
  final int id;
  final int userId;
  final int menuId;
  final int? menuTemplateId;
  final int? branchId;
  final String createdAt;
  final Menu? menu;

  Favorite({
    required this.id,
    required this.userId,
    required this.menuId,
    this.menuTemplateId,
    this.branchId,
    required this.createdAt,
    this.menu,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    final menuJson = json['menu'];
    return Favorite(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      menuId: _parseInt(json['menu_id']) ?? 0,
      menuTemplateId: _parseInt(json['menu_template_id']),
      branchId: _parseInt(json['branch_id']),
      createdAt: json['created_at']?.toString() ?? '',
      menu: menuJson is Map<String, dynamic> ? Menu.fromJson(menuJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'menu_id': menuId,
      if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
      if (branchId != null) 'branch_id': branchId,
      'created_at': createdAt,
      if (menu != null) 'menu': menu!.toJson(),
    };
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
