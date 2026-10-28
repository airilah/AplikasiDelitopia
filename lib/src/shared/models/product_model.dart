import '../../core/utils/brand_name_formatter.dart';
import '../../core/utils/sold_count_formatter.dart';
import '../../core/localization/app_language.dart';

String? _parseImage(dynamic value, {int? brandId, String? brandName}) {
  final image = value?.toString().trim() ?? '';
  if (image.isEmpty ||
      image.toLowerCase() == 'null' ||
      image.toLowerCase() == 'undefined' ||
      image == '[base64-image]') {
    return null;
  }

  // Already absolute URL or asset path
  if (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('assets/')) {
    return image;
  }

  // Local storage path
  if (image.startsWith('storage/') || image.startsWith('menus/')) {
    return 'https://aplikasi.mannagroup.id/$image';
  }

  // Raw POS cFoto filename (e.g. "P0001.jpg" or "/uploads/transaksi/menu/P0001.jpg")
  var clean = image.startsWith('/') ? image.substring(1) : image;
  if (clean.startsWith('uploads/transaksi/menu/')) {
    clean = clean.substring('uploads/transaksi/menu/'.length);
  } else if (clean.startsWith('uploads/menu/')) {
    clean = clean.substring('uploads/menu/'.length);
  }
  if (clean.isEmpty) return null;

  final isSushikun = brandId == 2 || (brandName != null && brandName.toLowerCase().contains('sushikun'));
  final host = isSushikun ? 'https://sales.mannapertiwi.com' : 'https://sales.mannagroup.id';
  return '$host/uploads/transaksi/menu/$clean';
}

class Product {
  final int id;
  final int? branchMenuItemId;
  final String? templateCode;
  final String code;
  final String name;
  final String description;
  final String? image;
  final double price;
  final double? originalPrice;
  final int? discount;
  final String category;
  final int categoryId;
  final int brandId;
  final String? brandName;
  final int? branchId;
  final String? branchAddress;
  final String? branchesLocation;
  final bool isAvailable;
  final bool isFeatured;
  final bool isPopular;
  final bool isNew;
  final String? showcaseType;
  final double rating;
  final int reviewCount;
  final int totalSold;
  final String? preparationTime;
  final List<String>? tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    this.branchMenuItemId,
    this.templateCode,
    required this.code,
    required this.name,
    required this.description,
    this.image,
    required this.price,
    this.originalPrice,
    this.discount,
    required this.category,
    required this.categoryId,
    this.brandId = 0,
    this.brandName,
    this.branchId,
    this.branchAddress,
    this.branchesLocation,
    this.isAvailable = true,
    this.isFeatured = false,
    this.isPopular = false,
    this.isNew = false,
    this.showcaseType,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.totalSold = 0,
    this.preparationTime,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ??
            json['showcase_type'] ??
            json['tipe'] ??
            json['type_name'])
        ?.toString();

    final bool parsedIsPopular = (json['is_popular'] == 1 ||
            json['is_popular'] == true) ||
        (json['popularity'] == 1) ||
        (typeStr != null &&
            (typeStr.toLowerCase().contains('populer') ||
                typeStr.toLowerCase() == 'popular'));

    final bool parsedIsNew = (json['is_new'] == 1 || json['is_new'] == true) ||
        (typeStr != null &&
            (typeStr.toLowerCase().contains('baru') ||
                typeStr.toLowerCase() == 'new'));

    final parsedBrandId = (json['brand_id'] as num?)?.toInt() ?? 0;
    final parsedBrandName = json['brand_name'] != null ? formatBrandName(json['brand_name']) : null;

    return Product(
      id: json['id'],
      branchMenuItemId: (json['branch_menu_item_id'] as num?)?.toInt(),
      templateCode: json['template_code']?.toString(),
      code: json['code']?.toString() ?? json['menu_code']?.toString() ?? '',
      name: json['name']?.toString() ?? json['menu_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: _parseImage(json['image'], brandId: parsedBrandId, brandName: parsedBrandName) ??
          _parseImage(json['image_url'], brandId: parsedBrandId, brandName: parsedBrandName) ??
          _parseImage(json['photo'], brandId: parsedBrandId, brandName: parsedBrandName),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble() ??
          ((json['has_promo'] == true || (json['promo_price'] != null && (json['promo_price'] as num) > 0))
              ? (json['base_price'] as num?)?.toDouble()
              : null),
      discount: (json['discount'] as num?)?.toInt() ?? (json['discount_percentage'] as num?)?.toInt(),
      category: json['category']?.toString() ??
          json['category_name']?.toString() ??
          '',
      categoryId: (json['category_id'] as num?)?.toInt() ??
          parsedBrandId,
      brandId: parsedBrandId,
      brandName: parsedBrandName,
      branchId: (json['branch_id'] as num?)?.toInt() ??
          (json['branches_id'] as num?)?.toInt(),
      branchAddress: json['branch_address']?.toString() ??
          json['branches_address']?.toString() ??
          json['address']?.toString(),
      branchesLocation: json['branches_location']?.toString() ??
          json['location']?.toString() ??
          json['branches_outlet']?.toString(),
      isAvailable: json['is_available'] ??
          json['available'] ??
          (json['is_active'] == 1) ??
          true,
      isFeatured: json['is_featured'] ?? false,
      isPopular: parsedIsPopular,
      isNew: parsedIsNew,
      showcaseType: typeStr,
      rating: (() {
        final rc = (json['review_count'] as num?)?.toInt() ??
            (json['total_reviews'] as num?)?.toInt() ??
            0;
        if (rc <= 0) return 0.0;
        return (json['rating'] as num?)?.toDouble() ??
            (json['average_rating'] as num?)?.toDouble() ??
            (json['avg_rating'] as num?)?.toDouble() ??
            0.0;
      })(),
      reviewCount: (json['review_count'] as num?)?.toInt() ??
          (json['total_reviews'] as num?)?.toInt() ??
          0,
      totalSold: (json['total_sold'] as num?)?.toInt() ??
          (json['sold_count'] as num?)?.toInt() ??
          (json['pos_sold_count'] as num?)?.toInt() ??
          0,
      preparationTime:
          json['preparation_time']?.toString() ?? json['prep_time']?.toString(),
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '')
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
          : null);
  }

  String get formattedSold => formatSoldCount(totalSold, lang: AppLanguage.indonesia);

  String formattedSoldFor(AppLanguage lang) => formatSoldCount(totalSold, lang: lang);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (branchMenuItemId != null) 'branch_menu_item_id': branchMenuItemId,
      if (templateCode != null) 'template_code': templateCode,
      'code': code,
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'original_price': originalPrice,
      'discount': discount,
      'category': category,
      'category_id': categoryId,
      'brand_id': brandId,
      'brand_name': brandName,
      'branch_id': branchId,
      'branch_address': branchAddress,
      'branches_location': branchesLocation,
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'is_popular': isPopular,
      'is_new': isNew,
      'showcase_type': showcaseType,
      'rating': rating,
      'review_count': reviewCount,
      'total_sold': totalSold,
      'preparation_time': preparationTime,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Calculate discount percentage
  int get discountPercentage {
    if (discount != null) return discount!;
    if (originalPrice != null && originalPrice! > price) {
      return (((originalPrice! - price) / originalPrice!) * 100).round();
    }
    return 0;
  }

  // Get formatted price
  String get formattedPrice {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  // Get formatted original price (for strikethrough)
  String get formattedOriginalPrice {
    if (originalPrice == null || originalPrice! <= price) return '';
    return 'Rp ${originalPrice!.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  bool get hasPromo => originalPrice != null && originalPrice! > price;

  // Copy with method
  Product copyWith({
    int? id,
    String? code,
    String? name,
    String? description,
    String? image,
    double? price,
    double? originalPrice,
    int? discount,
    String? category,
    int? categoryId,
    int? brandId,
    String? brandName,
    int? branchId,
    bool? isAvailable,
    bool? isFeatured,
    bool? isPopular,
    double? rating,
    int? reviewCount,
    int? totalSold,
    String? preparationTime,
    List<String>? tags,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discount: discount ?? this.discount,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      branchId: branchId ?? this.branchId,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isPopular: isPopular ?? this.isPopular,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      totalSold: totalSold ?? this.totalSold,
      preparationTime: preparationTime ?? this.preparationTime,
      tags: tags ?? this.tags);
  }
}

class Category {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final String? image;
  final int productCount;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.image,
    this.productCount = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      image: json['image'],
      productCount: json['product_count'] ?? json['products_count'] ?? 0,
      isActive: json['is_active'] ?? json['active'] ?? true);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'image': image,
      'product_count': productCount,
      'is_active': isActive,
    };
  }
}

class Banner {
  final int id;
  final String title;
  final String? description;
  final String photo;
  final String? popup;
  final String? startDate;
  final String? endDate;
  final String? linkType; // 'product', 'category', 'external', etc.
  final String? linkId;
  final int order;
  final bool isActive;

  Banner({
    required this.id,
    required this.title,
    this.description,
    required this.photo,
    this.popup,
    this.startDate,
    this.endDate,
    this.linkType,
    this.linkId,
    this.order = 0,
    this.isActive = true,
  });

  // Backward compatibility: use photo as image
  String get image => photo;
  bool get hasPopup => popup != null && popup!.isNotEmpty;

  factory Banner.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] is int) {
      parsedId = json['id'];
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    int parsedOrder = 0;
    if (json['order'] is int) {
      parsedOrder = json['order'];
    } else if (json['order'] != null) {
      parsedOrder = int.tryParse(json['order'].toString()) ?? 0;
    }

    final rawPhoto = json['photo'] ??
        json['image'] ??
        json['banner_image'] ??
        json['path'] ??
        json['url'] ??
        '';

    return Banner(
      id: parsedId,
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      photo: rawPhoto.toString(),
      popup: json['popup'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      linkType: json['link_type'],
      linkId: json['link_id']?.toString(),
      order: parsedOrder,
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active'] == '1');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'photo': photo,
      'popup': popup,
      'start_date': startDate,
      'end_date': endDate,
      'link_type': linkType,
      'link_id': linkId,
      'order': order,
      'is_active': isActive,
    };
  }
}
