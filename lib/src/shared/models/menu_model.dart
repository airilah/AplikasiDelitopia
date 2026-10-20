import '../../core/utils/brand_name_formatter.dart';
import '../../core/utils/sold_count_formatter.dart';
import '../../core/localization/app_language.dart';

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

String _parseImage(dynamic value, {int? brandId, String? brandName}) {
  final image = value?.toString().trim() ?? '';
  if (image.isEmpty ||
      image.toLowerCase() == 'null' ||
      image.toLowerCase() == 'undefined' ||
      image == '[base64-image]') {
    return '';
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
  if (clean.isEmpty) return '';

  final isSushikun = brandId == 2 || (brandName != null && brandName.toLowerCase().contains('sushikun'));
  final host = isSushikun ? 'https://sales.mannapertiwi.com' : 'https://sales.mannagroup.id';
  return '$host/uploads/transaksi/menu/$clean';
}

class Menu {
  final int id;
  final int? menuTemplateId;
  final int? branchMenuItemId;
  final String? templateCode;
  final String code;
  final String name;
  final String photo;
  final double price;
  final double? promoPrice;
  final double? basePrice;
  final bool? hasPromoFlag;
  final int? discountPercentageValue;
  final String description;
  final int brandId;
  final String? brandName;
  final String category;
  final int? popularity;
  final int? isActive;
  final int? branchesId;
  final String? branchesOutlet;
  final String? branchesLocation;
  final bool isAvailable;
  final bool canOrder;
  final String? unavailableReason;
  final String? unavailableNote;
  final int totalSold;
  final double averageRating;
  final int reviewCount;

  Menu({
    required this.id,
    this.menuTemplateId,
    this.branchMenuItemId,
    this.templateCode,
    required this.code,
    required this.name,
    required this.photo,
    required this.price,
    this.promoPrice,
    this.basePrice,
    this.hasPromoFlag,
    this.discountPercentageValue,
    required this.description,
    required this.brandId,
    this.brandName,
    required this.category,
    this.popularity,
    this.isActive,
    this.branchesId,
    this.branchesOutlet,
    this.branchesLocation,
    this.isAvailable = true,
    this.canOrder = true,
    this.unavailableReason,
    this.unavailableNote,
    this.totalSold = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    final bool available = json['is_available'] == true ||
        json['is_available'] == 1 ||
        (json['is_available'] == null && (json['is_active'] == 0 || json['is_active'] == null));
    final bool orderable = json['can_order'] == true ||
        json['can_order'] == 1 ||
        (json['can_order'] == null && available);

    final parsedBrandId = _parseInt(json['brand_id']) ?? 0;
    final parsedBrandName = json['brand_name'] != null ? formatBrandName(json['brand_name']) : null;

    final rawPhoto = _parseImage(json['photo'], brandId: parsedBrandId, brandName: parsedBrandName);
    final rawImage = _parseImage(json['image'], brandId: parsedBrandId, brandName: parsedBrandName);
    final rawImageUrl = _parseImage(json['image_url'], brandId: parsedBrandId, brandName: parsedBrandName);

    final parsedBasePrice = _parseDouble(json['base_price']);
    final parsedPromoPrice = _parseDouble(json['promo_price']);
    final hasPromoJson = json['has_promo'] == true || json['has_promo'] == 1;
    final discountVal = _parseInt(json['discount_percentage']);

    return Menu(
      id: _parseInt(json['id']) ?? 0,
      menuTemplateId: _parseInt(json['menu_template_id']) ?? _parseInt(json['id']),
      branchMenuItemId: _parseInt(json['branch_menu_item_id']),
      templateCode: json['template_code']?.toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      photo: rawPhoto.isNotEmpty
          ? rawPhoto
          : (rawImage.isNotEmpty ? rawImage : rawImageUrl),
      price: (() {
        final p = _parseDouble(json['price']) ?? 0.0;
        if (p > 0) return p;
        if (parsedPromoPrice != null && parsedPromoPrice > 0) return parsedPromoPrice;
        final bp = parsedBasePrice ?? 0.0;
        return bp > 0 ? bp : 0.0;
      })(),
      promoPrice: parsedPromoPrice,
      basePrice: parsedBasePrice,
      hasPromoFlag: hasPromoJson,
      discountPercentageValue: discountVal,
      description: json['description']?.toString() ?? '',
      brandId: parsedBrandId,
      brandName: parsedBrandName,
      category: json['category']?.toString() ?? '',
      popularity: _parseInt(json['popularity']),
      isActive: _parseInt(json['is_active']),
      branchesId: _parseInt(json['branches_id']) ?? _parseInt(json['branch_id']),
      branchesOutlet: json['branches_outlet']?.toString(),
      branchesLocation: json['branches_location']?.toString(),
      isAvailable: available,
      canOrder: orderable,
      unavailableReason: json['unavailable_reason']?.toString(),
      unavailableNote: json['unavailable_note']?.toString(),
      totalSold: _parseInt(json['total_sold']) ??
          _parseInt(json['sold_count']) ??
          _parseInt(json['pos_sold_count']) ??
          0,
      averageRating: _parseDouble(json['average_rating']) ??
          _parseDouble(json['rating']) ??
          0.0,
      reviewCount: _parseInt(json['review_count']) ??
          _parseInt(json['total_reviews']) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
      if (branchMenuItemId != null) 'branch_menu_item_id': branchMenuItemId,
      if (templateCode != null) 'template_code': templateCode,
      'code': code,
      'name': name,
      'photo': photo,
      'price': price,
      if (promoPrice != null) 'promo_price': promoPrice,
      if (basePrice != null) 'base_price': basePrice,
      'has_promo': hasPromo,
      'discount_percentage': discountPercentage,
      'description': description,
      'brand_id': brandId,
      if (brandName != null) 'brand_name': brandName,
      'category': category,
      if (popularity != null) 'popularity': popularity,
      if (isActive != null) 'is_active': isActive,
      if (branchesId != null) 'branches_id': branchesId,
      if (branchesOutlet != null) 'branches_outlet': branchesOutlet,
      if (branchesLocation != null) 'branches_location': branchesLocation,
      'is_available': isAvailable,
      'can_order': canOrder,
      if (unavailableReason != null) 'unavailable_reason': unavailableReason,
      if (unavailableNote != null) 'unavailable_note': unavailableNote,
      'total_sold': totalSold,
      'sold_count': totalSold,
      'average_rating': averageRating,
      'review_count': reviewCount,
    };
  }

  // Helper getters
  int? get branchId => branchesId;
  bool get isPopular => popularity == 1;
  bool get active => isActive == null || isActive == 0;
  bool get canBeOrdered => isAvailable && canOrder;

  /// Check whether menu has an active promotional price
  bool get hasPromo =>
      (hasPromoFlag == true) ||
      (promoPrice != null &&
          promoPrice! > 0 &&
          basePrice != null &&
          promoPrice! < basePrice!);

  double get displayPromoPrice => (promoPrice != null && promoPrice! > 0) ? promoPrice! : price;
  double get displayOriginalPrice => (basePrice != null && basePrice! > 0) ? basePrice! : price;

  int get discountPercentage {
    if (discountPercentageValue != null && discountPercentageValue! > 0) {
      return discountPercentageValue!;
    }
    if (!hasPromo || (basePrice ?? 0) <= 0) return 0;
    final orig = basePrice!;
    final promo = (promoPrice != null && promoPrice! > 0) ? promoPrice! : price;
    if (promo >= orig) return 0;
    return (((orig - promo) / orig) * 100).round();
  }

  String get formattedPromoPrice => _formatRupiah(displayPromoPrice);
  String get formattedOriginalPrice => _formatRupiah(displayOriginalPrice);

  String get formattedSold => formatSoldCount(totalSold, lang: AppLanguage.indonesia);

  String formattedSoldFor(AppLanguage lang) => formatSoldCount(totalSold, lang: lang);

  /// Returns a user-friendly label based on the unavailable reason from the backend, localized by language.
  String unavailableLabelFor([AppLanguage lang = AppLanguage.indonesia]) {
    final isEn = lang == AppLanguage.english;
    switch (unavailableReason) {
      case 'stok_habis':
        return isEn ? 'Out of Stock' : 'Stok Habis';
      case 'bahan_habis':
        return isEn ? 'Ingredients Out' : 'Bahan Habis';
      case 'sedang_tidak_dijual':
        return isEn ? 'Not for Sale' : 'Tidak Dijual';
      case 'maintenance':
        return isEn ? 'Temporarily Closed' : 'Tutup Sementara';
      case 'lainnya':
        return unavailableNote?.isNotEmpty == true
            ? unavailableNote!
            : (isEn ? 'Unavailable' : 'Tidak Tersedia');
      default:
        return isEn ? 'Unavailable' : 'Tidak Tersedia';
    }
  }

  String get unavailableLabel => unavailableLabelFor(AppLanguage.indonesia);

  static String _formatRupiah(double val) => 'Rp ${val.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  )}';

  String get formattedPrice => _formatRupiah(price);
}
