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

class Cart {
  final int id;
  final int userId;
  final int? branchId;
  final String? branchName;
  final String? brandName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CartItem> items;

  Cart({
    required this.id,
    required this.userId,
    this.branchId,
    this.branchName,
    this.brandName,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    final cartData = json['cart'] is Map<String, dynamic>
        ? json['cart'] as Map<String, dynamic>
        : json;

    return Cart(
      id: _parseInt(cartData['id']) ?? _parseInt(json['id']) ?? 0,
      userId: _parseInt(cartData['user_id']) ?? _parseInt(json['user_id']) ?? 0,
      branchId:
          _parseInt(cartData['branch_id']) ?? _parseInt(json['branch_id']),
      branchName: cartData['branch_name']?.toString() ?? json['branch_name']?.toString(),
      brandName: cartData['brand_name']?.toString() ?? json['brand_name']?.toString(),
      createdAt: cartData['created_at'] != null
          ? DateTime.tryParse(cartData['created_at']?.toString() ?? '') ??
              DateTime.now()
          : DateTime.now(),
      updatedAt: cartData['updated_at'] != null
          ? DateTime.tryParse(cartData['updated_at']?.toString() ?? '') ??
              DateTime.now()
          : DateTime.now(),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : []);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (branchId != null) 'branch_id': branchId,
      if (branchName != null) 'branch_name': branchName,
      if (brandName != null) 'brand_name': brandName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Helper getters
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  double get tax => subtotal * 0.10; // 10% tax

  double get service =>
      (subtotal + tax) * 0.05; // 5% service calculated after tax

  double get total => subtotal + tax + service;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  Cart copyWith({
    int? id,
    int? userId,
    int? branchId,
    String? branchName,
    String? brandName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CartItem>? items,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      brandName: brandName ?? this.brandName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items);
  }
}

class CartItem {
  final int id;
  final int cartId;
  final int menuId;
  final int? menuTemplateId;
  final String menuName;
  final String? menuImage;
  final double price;
  final double? originalPrice;
  final double? promoPrice;
  final bool hasPromo;
  final int? discountPercentage;
  final int quantity;
  final String? notes;
  final String? menuCode;
  final String? templateCode;
  final int? branchMenuItemId;
  final String? preparationTime;
  final int? prepTimeMin;
  final int? prepTimeMax;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  CartItem({
    required this.id,
    required this.cartId,
    required this.menuId,
    this.menuTemplateId,
    required this.menuName,
    this.menuImage,
    required this.price,
    this.originalPrice,
    this.promoPrice,
    this.hasPromo = false,
    this.discountPercentage,
    required this.quantity,
    this.notes,
    this.menuCode,
    this.templateCode,
    this.branchMenuItemId,
    this.preparationTime,
    this.prepTimeMin,
    this.prepTimeMax,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Target Menu ID yang valid untuk detail produk
  int get targetMenuId {
    if (menuTemplateId != null && menuTemplateId! > 0) return menuTemplateId!;
    if (menuId > 0) return menuId;
    if (branchMenuItemId != null && branchMenuItemId! > 0) return branchMenuItemId!;
    return 0;
  }

  /// Format harga untuk tampilan
  String get formattedPrice =>
      'Rp ${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  /// Format harga asli (sebelum diskon) untuk tampilan
  String? get formattedOriginalPrice =>
      (originalPrice != null && originalPrice! > 0)
          ? 'Rp ${originalPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'
          : null;

  /// Resolves the lower bound of cooking time in minutes
  int get minPrepMinutes {
    if (prepTimeMin != null && prepTimeMin! > 0) return prepTimeMin!;
    if (preparationTime != null && preparationTime!.trim().isNotEmpty) {
      final clean = preparationTime!.trim();
      final match = RegExp(r'(\d+)\s*(?:-|–|—|to|sampai|s/d)\s*(\d+)', caseSensitive: false).firstMatch(clean);
      if (match != null) {
        final a = int.tryParse(match.group(1)!) ?? 0;
        final b = int.tryParse(match.group(2)!) ?? 0;
        return (a > 0 && b > 0) ? (a < b ? a : b) : (a > 0 ? a : b);
      }
      final single = RegExp(r'(\d+)').firstMatch(clean);
      if (single != null) {
        return int.tryParse(single.group(1)!) ?? 0;
      }
    }
    return 0;
  }

  /// Resolves the upper bound of cooking time in minutes
  int get maxPrepMinutes {
    if (prepTimeMax != null && prepTimeMax! > 0) return prepTimeMax!;
    if (preparationTime != null && preparationTime!.trim().isNotEmpty) {
      final clean = preparationTime!.trim();
      final match = RegExp(r'(\d+)\s*(?:-|–|—|to|sampai|s/d)\s*(\d+)', caseSensitive: false).firstMatch(clean);
      if (match != null) {
        final a = int.tryParse(match.group(1)!) ?? 0;
        final b = int.tryParse(match.group(2)!) ?? 0;
        return (a > 0 && b > 0) ? (a > b ? a : b) : (a > 0 ? a : b);
      }
      final single = RegExp(r'(\d+)').firstMatch(clean);
      if (single != null) {
        return int.tryParse(single.group(1)!) ?? 0;
      }
    }
    return 0;
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Handle menu details from nested 'menu' object or direct fields
    final menuData = json['menu'] as Map<String, dynamic>?;
    final bmiData = json['branch_menu_item'] as Map<String, dynamic>?;

    final parsedMenuTemplateId = _parseInt(json['menu_template_id']) ??
        _parseInt(menuData?['menu_template_id']) ??
        _parseInt(bmiData?['menu_template_id']) ??
        _parseInt(bmiData?['menu_template']?['id']) ??
        _parseInt(json['menu_template']?['id']);

    final parsedBranchMenuItemId = _parseInt(json['branch_menu_item_id']) ??
        _parseInt(bmiData?['id']);

    final parsedMenuId = _parseInt(json['menu_id']) ??
        _parseInt(menuData?['id']) ??
        _parseInt(menuData?['menu_id']) ??
        _parseInt(bmiData?['menu_id']) ??
        0;

    final parsedPrice = _parseDouble(json['price']) ?? 0.0;

    final parsedBasePrice = _parseDouble(json['original_price']) ??
        _parseDouble(json['base_price']) ??
        _parseDouble(menuData?['original_price']) ??
        _parseDouble(menuData?['base_price']) ??
        _parseDouble(bmiData?['menu_template']?['base_price']) ??
        _parseDouble(json['menu_template']?['base_price']);

    final parsedPromoPrice = _parseDouble(json['promo_price']) ??
        _parseDouble(menuData?['promo_price']) ??
        _parseDouble(bmiData?['menu_template']?['promo_price']) ??
        _parseDouble(json['menu_template']?['promo_price']);

    final hasPromoBool = json['has_promo'] == true ||
        json['has_promo'] == 1 ||
        menuData?['has_promo'] == true ||
        (parsedPromoPrice != null &&
            parsedPromoPrice > 0 &&
            parsedBasePrice != null &&
            parsedBasePrice > parsedPromoPrice) ||
        (parsedBasePrice != null && parsedBasePrice > (parsedPrice + 1));

    final parsedOriginalPrice = hasPromoBool &&
            parsedBasePrice != null &&
            parsedBasePrice > parsedPrice
        ? parsedBasePrice
        : null;

    final parsedDiscount = _parseInt(json['discount_percentage']) ??
        _parseInt(menuData?['discount_percentage']) ??
        _parseInt(bmiData?['menu_template']?['discount_percentage']) ??
        (hasPromoBool && parsedOriginalPrice != null && parsedOriginalPrice > 0
            ? (((parsedOriginalPrice - parsedPrice) / parsedOriginalPrice) * 100).round()
            : null);

    return CartItem(
      id: _parseInt(json['id']) ?? 0,
      cartId: _parseInt(json['cart_id']) ?? 0,
      menuId: parsedMenuId,
      menuTemplateId: parsedMenuTemplateId,
      menuName: json['menu_name']?.toString() ??
          menuData?['menu_name']?.toString() ??
          menuData?['name']?.toString() ??
          bmiData?['menu_template']?['name']?.toString() ??
          'Unknown Item',
      menuImage: json['menu_image']?.toString() ??
          json['photo']?.toString() ??
          json['image']?.toString() ??
          menuData?['menu_image']?.toString() ??
          menuData?['photo']?.toString() ??
          menuData?['image']?.toString() ??
          bmiData?['menu_template']?['photo']?.toString() ??
          bmiData?['menu_template']?['image']?.toString(),
      price: parsedPrice,
      originalPrice: parsedOriginalPrice,
      promoPrice: parsedPromoPrice,
      hasPromo: hasPromoBool && parsedOriginalPrice != null,
      discountPercentage: parsedDiscount,
      quantity: _parseInt(json['quantity']) ?? _parseInt(json['qty']) ?? 1,
      notes: json['notes']?.toString(),
      menuCode: json['menu_code']?.toString() ??
          menuData?['menu_code']?.toString() ??
          bmiData?['menu_template']?['code']?.toString(),
      templateCode: json['template_code']?.toString() ??
          bmiData?['menu_template']?['template_code']?.toString() ??
          bmiData?['menu_template']?['code']?.toString(),
      branchMenuItemId: parsedBranchMenuItemId,
      preparationTime: json['preparation_time']?.toString() ??
          json['prep_time']?.toString() ??
          menuData?['preparation_time']?.toString() ??
          menuData?['prep_time']?.toString() ??
          bmiData?['menu_template']?['preparation_time']?.toString(),
      prepTimeMin: _parseInt(json['prep_time_min'] ??
          menuData?['prep_time_min'] ??
          bmiData?['menu_template']?['prep_time_min']),
      prepTimeMax: _parseInt(json['prep_time_max'] ??
          menuData?['prep_time_max'] ??
          bmiData?['menu_template']?['prep_time_max']),
      category: json['category']?.toString() ??
          menuData?['category']?.toString() ??
          bmiData?['menu_template']?['category']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now()
          : DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cart_id': cartId,
      'menu_id': menuId,
      if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
      'menu_name': menuName,
      if (menuImage != null) 'menu_image': menuImage,
      'price': price,
      if (originalPrice != null) 'original_price': originalPrice,
      if (promoPrice != null) 'promo_price': promoPrice,
      'has_promo': hasPromo,
      if (discountPercentage != null) 'discount_percentage': discountPercentage,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
      if (menuCode != null) 'menu_code': menuCode,
      if (templateCode != null) 'template_code': templateCode,
      if (branchMenuItemId != null) 'branch_menu_item_id': branchMenuItemId,
      if (preparationTime != null) 'preparation_time': preparationTime,
      if (prepTimeMin != null) 'prep_time_min': prepTimeMin,
      if (prepTimeMax != null) 'prep_time_max': prepTimeMax,
      if (category != null) 'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get subtotal => price * quantity;

  CartItem copyWith({
    int? id,
    int? cartId,
    int? menuId,
    int? menuTemplateId,
    String? menuName,
    String? menuImage,
    double? price,
    double? originalPrice,
    double? promoPrice,
    bool? hasPromo,
    int? discountPercentage,
    int? quantity,
    String? notes,
    String? preparationTime,
    int? prepTimeMin,
    int? prepTimeMax,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      cartId: cartId ?? this.cartId,
      menuId: menuId ?? this.menuId,
      menuTemplateId: menuTemplateId ?? this.menuTemplateId,
      menuName: menuName ?? this.menuName,
      menuImage: menuImage ?? this.menuImage,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      promoPrice: promoPrice ?? this.promoPrice,
      hasPromo: hasPromo ?? this.hasPromo,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      preparationTime: preparationTime ?? this.preparationTime,
      prepTimeMin: prepTimeMin ?? this.prepTimeMin,
      prepTimeMax: prepTimeMax ?? this.prepTimeMax,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt);
  }
}

class AddToCartRequest {
  // Old menu system
  final int? menuId;
  final String? menuCode;

  // New menu template system (recommended)
  final String? templateCode;
  final int? branchMenuItemId;

  // Common fields
  final int quantity;
  final String? notes;
  final Map<String, dynamic>? customizations;
  final int? branchId;

  AddToCartRequest({
    this.menuId,
    this.menuCode,
    this.templateCode,
    this.branchMenuItemId,
    this.quantity = 1,
    this.notes,
    this.customizations,
    this.branchId,
  });

  Map<String, dynamic> toJson() {
    return {
      // Old system
      if (menuId != null) 'menu_id': menuId,
      if (menuCode != null) 'menu_code': menuCode,

      // New system (recommended)
      if (templateCode != null) 'template_code': templateCode,
      if (branchMenuItemId != null) 'branch_menu_item_id': branchMenuItemId,

      // Common fields
      'qty': quantity,
      if (notes != null) 'notes': notes,
      if (customizations != null) 'customizations': customizations,
      if (branchId != null) 'branch_id': branchId,
    };
  }
}

class UpdateCartItemRequest {
  final int quantity;
  final String? notes;

  UpdateCartItemRequest({
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'qty': quantity,
      if (notes != null) 'notes': notes,
    };
  }
}
