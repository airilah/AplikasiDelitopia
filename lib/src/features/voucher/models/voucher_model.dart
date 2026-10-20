import 'dart:convert';

import '../../../core/localization/app_language.dart';
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

List<Voucher> voucherFromJson(String str) =>
    List<Voucher>.from(json.decode(str).map((x) => Voucher.fromJson(x)));

String voucherToJson(List<Voucher> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

Voucher singleVoucherFromJson(String str) =>
    Voucher.fromJson(json.decode(str));

String singleVoucherToJson(Voucher data) => json.encode(data.toJson());

class Voucher {
  final int id;
  final String voucherName;
  final String? code;
  final String description;
  final String? brandName;
  final int? brandId;
  final int? userLevelId;
  final String voucherType; // 'percentage', 'amount', 'buy_1_get_1', 'free_item'
  final double? discountAmount;
  final double? discountPercentage;
  final double? maxDiscountAmount;
  final double? minSpend;
  final int point; // Points required to redeem
  final double price; // Cash price
  final bool isPurchasable;
  final bool isAutoGranted;
  final bool requiresActivation;
  final String acquisitionType; // 'free', 'outlet_qr', 'points', 'cash', 'birthday'
  final String usageChannel; // 'all', 'app_only', 'cashier_only'
  final String? outletQrCode;
  final String? usageLimitType; // 'unlimited', 'once_per_day', 'total_limit', 'both'
  final int? maxUsagePerUser;
  final int? maxUsagePerDay;
  final int? cooldownHours;
  final String? startDate;
  final String? endDate;
  final String? expiryType; // 'duration', 'monthly', 'fixed'
  final int? durationDays;
  final int? specificMonth;
  final int? specificYear;
  final int? buy1Get1BuyId;
  final int? buy1Get1FreeId;
  final int? freeMenuItemId;
  final String? freeMenuName;
  final String? freeMenuCode;
  final String? image;
  final int? totalStock;
  final int? remainingStock;

  bool get isValid {
    if (startDate != null && startDate!.isNotEmpty) {
      final start = DateTime.tryParse(startDate!);
      if (start != null && DateTime.now().isBefore(start)) return false;
    }
    if (endDate != null && endDate!.isNotEmpty) {
      final end = DateTime.tryParse(endDate!);
      if (end != null && DateTime.now().isAfter(end)) return false;
    }
    return true;
  }

  Voucher({
    required this.id,
    required this.voucherName,
    this.code,
    required this.description,
    this.brandName,
    this.brandId,
    this.userLevelId,
    required this.voucherType,
    this.discountAmount,
    this.discountPercentage,
    this.maxDiscountAmount,
    this.minSpend,
    this.point = 0,
    this.price = 0,
    this.isPurchasable = false,
    this.isAutoGranted = false,
    this.requiresActivation = false,
    this.acquisitionType = 'free',
    this.usageChannel = 'all',
    this.outletQrCode,
    this.usageLimitType,
    this.maxUsagePerUser,
    this.maxUsagePerDay,
    this.cooldownHours,
    this.startDate,
    this.endDate,
    this.expiryType,
    this.durationDays,
    this.specificMonth,
    this.specificYear,
    this.buy1Get1BuyId,
    this.buy1Get1FreeId,
    this.freeMenuItemId,
    this.freeMenuName,
    this.freeMenuCode,
    this.image,
    this.totalStock,
    this.remainingStock,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    String? parsedBrandName;
    if (json['brand_name'] != null && json['brand_name'].toString().trim().isNotEmpty) {
      parsedBrandName = formatBrandName(json['brand_name']);
    } else if (json['brand'] != null) {
      if (json['brand'] is Map && (json['brand'] as Map)['name'] != null) {
        parsedBrandName = formatBrandName((json['brand'] as Map)['name']);
      } else if (json['brand'] is String && json['brand'].toString().trim().isNotEmpty) {
        parsedBrandName = formatBrandName(json['brand']);
      }
    }

    // Additional smart detection from voucherName or description if brandName is not found
    if (parsedBrandName == null || parsedBrandName.isEmpty) {
      final nameLower = (json['voucher_name']?.toString() ?? json['name']?.toString() ?? '').toLowerCase();
      final descLower = (json['description']?.toString() ?? '').toLowerCase();
      final combined = '$nameLower $descLower';
      if (combined.contains('sushikun') || combined.contains('sushi kun')) {
        parsedBrandName = 'Sushikun';
      } else if (combined.contains('ah bang') || combined.contains('ahbang')) {
        parsedBrandName = 'Ah Bang';
      } else if (combined.contains('tomoko')) {
        parsedBrandName = 'Tomoko';
      } else if (combined.contains('manna')) {
        parsedBrandName = 'Manna Coffee';
      }
    }

    final parsedBrandId = _parseInt(json['brand_id']) ?? ((json['brand'] is Map) ? _parseInt((json['brand'] as Map)['id']) : null);

    if (parsedBrandName == null || parsedBrandName.isEmpty) {
      parsedBrandName = 'Semua Brand';
    } else if (parsedBrandName.toLowerCase() == 'delitopia' && (parsedBrandId == null || parsedBrandId == 0)) {
      parsedBrandName = 'Semua Brand';
    }

    return Voucher(
      id: _parseInt(json['id']) ?? 0,
      voucherName: json['voucher_name']?.toString() ?? '',
      code: json['code']?.toString(),
      description: json['description']?.toString() ?? '',
      brandName: parsedBrandName,
      brandId: parsedBrandId,
      userLevelId: _parseInt(json['user_level_id']),
      voucherType: json['voucher_type']?.toString() ?? 'percentage',
      discountAmount: _parseDouble(json['discount_amount']),
      discountPercentage: _parseDouble(json['discount_percentage']),
      maxDiscountAmount: _parseDouble(json['max_discount_amount'] ?? json['max_discount']),
      minSpend: _parseDouble(json['min_spend']),
      point: _parseInt(json['point']) ?? 0,
      price: _parseDouble(json['price']) ?? 0,
      isPurchasable: json['is_purchasable'] == 1 || json['is_purchasable'] == true,
      isAutoGranted: json['is_auto_granted'] == 1 || json['is_auto_granted'] == true,
      requiresActivation: json['requires_activation'] == 1 || json['requires_activation'] == true,
      acquisitionType: json['acquisition_type']?.toString() ?? 'free',
      usageChannel: json['usage_channel']?.toString() ?? 'all',
      outletQrCode: json['outlet_qr_code']?.toString(),
      usageLimitType: json['usage_limit_type']?.toString(),
      maxUsagePerUser: _parseInt(json['max_usage_per_user']),
      maxUsagePerDay: _parseInt(json['max_usage_per_day']),
      cooldownHours: _parseInt(json['cooldown_hours']),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      expiryType: json['expiry_type']?.toString(),
      durationDays: _parseInt(json['duration_days']),
      specificMonth: _parseInt(json['specific_month']),
      specificYear: _parseInt(json['specific_year']),
      buy1Get1BuyId: _parseInt(json['buy_1_get_1_buy_id']),
      buy1Get1FreeId: _parseInt(json['buy_1_get_1_free_id']),
      freeMenuItemId: _parseInt(json['free_menu_item_id']),
      freeMenuName: json['free_menu_name']?.toString(),
      freeMenuCode: json['free_menu_code']?.toString(),
      image: json['image']?.toString(),
      totalStock: _parseInt(json['total_stock'] ?? json['max_usage']),
      remainingStock: _parseInt(json['remaining_stock']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_name': voucherName,
      if (code != null) 'code': code,
      'description': description,
      if (brandName != null) 'brand_name': brandName,
      if (brandId != null) 'brand_id': brandId,
      if (userLevelId != null) 'user_level_id': userLevelId,
      'voucher_type': voucherType,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (discountPercentage != null) 'discount_percentage': discountPercentage,
      if (maxDiscountAmount != null) 'max_discount_amount': maxDiscountAmount,
      if (minSpend != null) 'min_spend': minSpend,
      'point': point,
      'price': price,
      'is_purchasable': isPurchasable,
      'is_auto_granted': isAutoGranted,
      'requires_activation': requiresActivation,
      'acquisition_type': acquisitionType,
      'usage_channel': usageChannel,
      if (outletQrCode != null) 'outlet_qr_code': outletQrCode,
      if (usageLimitType != null) 'usage_limit_type': usageLimitType,
      if (maxUsagePerUser != null) 'max_usage_per_user': maxUsagePerUser,
      if (maxUsagePerDay != null) 'max_usage_per_day': maxUsagePerDay,
      if (cooldownHours != null) 'cooldown_hours': cooldownHours,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (expiryType != null) 'expiry_type': expiryType,
      if (durationDays != null) 'duration_days': durationDays,
      if (specificMonth != null) 'specific_month': specificMonth,
      if (specificYear != null) 'specific_year': specificYear,
      if (buy1Get1BuyId != null) 'buy_1_get_1_buy_id': buy1Get1BuyId,
      if (buy1Get1FreeId != null) 'buy_1_get_1_free_id': buy1Get1FreeId,
      if (freeMenuItemId != null) 'free_menu_item_id': freeMenuItemId,
      if (freeMenuName != null) 'free_menu_name': freeMenuName,
      if (freeMenuCode != null) 'free_menu_code': freeMenuCode,
      if (image != null) 'image': image,
      if (totalStock != null) 'total_stock': totalStock,
      if (remainingStock != null) 'remaining_stock': remainingStock,
    };
  }

  // Helper getters
  bool get isPurchasableWithMoney => (acquisitionType == 'cash') || (isPurchasable && price > 0 && acquisitionType != 'outlet_qr');
  bool get isRedeemableWithPoints => (acquisitionType == 'points') || (point > 0 && acquisitionType != 'outlet_qr');
  bool get isFreeVoucher => (acquisitionType == 'free') || (price == 0 && point == 0 && !isOutletQrVoucher);
  bool get isOutletQrVoucher => acquisitionType == 'outlet_qr';
  bool get isCashierOnly => usageChannel == 'cashier_only';
  bool get isAppOnly => usageChannel == 'app_only';
  bool get canUseAtCheckout => usageChannel != 'cashier_only';
  bool get canUseAtCashier => usageChannel != 'app_only';
  bool get isAvailable => isPurchasableWithMoney || isRedeemableWithPoints || isFreeVoucher;
  
  String get displayBrandName {
    if (brandName != null && brandName!.trim().isNotEmpty) {
      final bnLower = brandName!.trim().toLowerCase();
      if ((bnLower == 'delitopia' || bnLower == 'all' || bnLower == 'semua' || bnLower == 'semua brand') && (brandId == null || brandId == 0)) {
        return 'Semua Brand';
      }
      return brandName!;
    }
    return 'Semua Brand';
  }
  
  String get formattedPrice {
    if (price > 0) {
      return 'Rp ${price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';
    }
    return '';
  }

  String get formattedPoints {
    if (point > 0) {
      return '$point Poin';
    }
    return '';
  }

  String get formattedMinSpend {
    if (minSpend != null && minSpend! > 0) {
      return 'Rp ${minSpend!.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';
    }
    return '';
  }

  String get formattedDiscount {
    if ((voucherType == 'percentage' ||
            voucherType == 'percentage_off' ||
            voucherType == 'discount_percentage' ||
            voucherType == 'birthday') &&
        discountPercentage != null &&
        discountPercentage! > 0) {
      if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
        final cap = maxDiscountAmount!;
        final capText = cap >= 1000
            ? '${(cap / 1000).toInt()}rb'
            : cap.toInt().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]}.',
              );
        return '${discountPercentage!.toInt()}% s.d. Rp $capText';
      }
      return '${discountPercentage!.toInt()}%';
    } else if ((voucherType == 'amount' ||
            voucherType == 'discount' ||
            voucherType == 'discount_amount' ||
            voucherType == 'free_delivery') &&
        discountAmount != null &&
        discountAmount! > 0) {
      return 'Rp ${discountAmount!.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';
    } else if (voucherType == 'buy_1_get_1') {
      return 'B1G1';
    } else if (voucherType == 'free_menu' || voucherType == 'free_item') {
      return 'FREE';
    }
    return '';
  }

  /// Ringkasan benefit dinamis (e.g. "25% Off up to 20k", "Potongan 15rb", "Gratis Ice Ocha")
  String getBenefitSummary(AppLanguage lang) {
    final isId = lang == AppLanguage.indonesia;
    final type = voucherType.trim().toLowerCase();

    // Format nilai singkatan: 20rb (ID) / 20k (EN)
    String formatShort(double amt) {
      if (amt >= 1000000) {
        final val = amt / 1000000;
        final valStr = val % 1 == 0
            ? val.toInt().toString()
            : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        return isId ? '${valStr}jt' : '${valStr}m';
      } else if (amt >= 1000) {
        final val = amt / 1000;
        final valStr = val % 1 == 0
            ? val.toInt().toString()
            : val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        return isId ? '${valStr}rb' : '${valStr}k';
      } else {
        return 'Rp ${amt.toInt()}';
      }
    }

    String formatPct(double pct) {
      return pct % 1 == 0 ? pct.toInt().toString() : pct.toString();
    }

    // 1. Free Delivery
    if (type == 'free_delivery') {
      if (discountAmount != null && discountAmount! > 0) {
        final amt = formatShort(discountAmount!);
        return isId ? 'Potongan Ongkir $amt' : '$amt Off Delivery';
      }
      return isId ? 'Gratis Ongkir' : 'Free Delivery';
    }

    // 2. Birthday
    if (type == 'birthday') {
      final prefix = isId ? 'Ultah: ' : 'Birthday: ';
      if (discountPercentage != null && discountPercentage! > 0) {
        final pct = formatPct(discountPercentage!);
        if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
          final cap = formatShort(maxDiscountAmount!);
          return isId
              ? '${prefix}Diskon $pct% s.d. $cap'
              : '$prefix$pct% Off up to $cap';
        }
        return isId ? '${prefix}Diskon $pct%' : '$prefix$pct% Off';
      } else if (discountAmount != null && discountAmount! > 0) {
        final amt = formatShort(discountAmount!);
        return isId ? '${prefix}Potongan $amt' : '$prefix$amt Off';
      } else if (freeMenuName != null && freeMenuName!.trim().isNotEmpty) {
        return isId
            ? '${prefix}Gratis ${freeMenuName!.trim()}'
            : '${prefix}Free ${freeMenuName!.trim()}';
      }
      return isId ? 'Spesial Ulang Tahun' : 'Birthday Special';
    }

    // 3. Buy 1 Get 1
    if (type == 'buy_1_get_1' || type == 'b1g1') {
      if (freeMenuName != null && freeMenuName!.trim().isNotEmpty) {
        return isId
            ? 'Gratis ${freeMenuName!.trim()} (B1G1)'
            : 'Free ${freeMenuName!.trim()} (B1G1)';
      }
      return isId ? 'Beli 1 Gratis 1' : 'Buy 1 Get 1 Free';
    }

    // 4. Free Menu / Free Item
    if (type == 'free_menu' || type == 'free_item') {
      if (freeMenuName != null && freeMenuName!.trim().isNotEmpty) {
        return isId
            ? 'Gratis ${freeMenuName!.trim()}'
            : 'Free ${freeMenuName!.trim()}';
      }
      return isId ? 'Gratis 1 Menu' : '1 Free Menu';
    }

    // 5. Percentage Discount
    if (type == 'percentage' ||
        type == 'percentage_off' ||
        type == 'discount_percentage' ||
        (discountPercentage != null && discountPercentage! > 0)) {
      if (discountPercentage != null && discountPercentage! > 0) {
        final pct = formatPct(discountPercentage!);
        if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
          final cap = formatShort(maxDiscountAmount!);
          return isId ? 'Diskon $pct% s.d. $cap' : '$pct% Off up to $cap';
        }
        return isId ? 'Diskon $pct%' : '$pct% Off';
      }
    }

    // 6. Fixed / Amount Discount
    if (type == 'amount' ||
        type == 'fixed' ||
        type == 'discount' ||
        type == 'discount_amount' ||
        (discountAmount != null && discountAmount! > 0)) {
      if (discountAmount != null && discountAmount! > 0) {
        final amt = formatShort(discountAmount!);
        return isId ? 'Potongan $amt' : '$amt Off';
      }
    }

    // 7. Fallback if freeMenuName exists
    if (freeMenuName != null && freeMenuName!.trim().isNotEmpty) {
      return isId
          ? 'Gratis ${freeMenuName!.trim()}'
          : 'Free ${freeMenuName!.trim()}';
    }

    return isId ? 'Promo Spesial' : 'Special Promo';
  }

  String get usageLimitText {
    if (usageLimitType == 'once_per_day' || (maxUsagePerDay != null && maxUsagePerDay == 1 && (maxUsagePerUser == null || maxUsagePerUser == 0))) {
      return 'Gunakan 1x sehari';
    } else if (usageLimitType == 'both' || (maxUsagePerDay != null && maxUsagePerDay! > 0 && maxUsagePerUser != null && maxUsagePerUser! > 0)) {
      return '${maxUsagePerDay}x sehari, max ${maxUsagePerUser}x total';
    } else if (usageLimitType == 'total_limit' || (maxUsagePerUser != null && maxUsagePerUser! > 0)) {
      return maxUsagePerUser == 1 ? '1x per pengguna' : 'Maks. ${maxUsagePerUser}x per pengguna';
    } else if (maxUsagePerDay != null && maxUsagePerDay! > 0) {
      return 'Maks. ${maxUsagePerDay}x sehari';
    }

    // Smart fallback checking description text
    final descLower = description.toLowerCase();
    if (descLower.contains('1x penggunaan') ||
        descLower.contains('1x per akun') ||
        descLower.contains('1x per pengguna') ||
        descLower.contains('1x per user') ||
        descLower.contains('hanya 1 kali')) {
      return '1x per pengguna';
    }

    return 'Tanpa batas';
  }

  bool get isSoldOut => remainingStock != null && remainingStock! <= 0;
  bool get isLimitedStock => remainingStock != null && remainingStock! > 0 && remainingStock! <= 10;
  String get remainingStockText => remainingStock != null ? '$remainingStock voucher' : 'Tanpa batas';

  bool get isExpired {
    if (endDate == null) return false;
    try {
      final expiryDate = DateTime.parse(endDate!);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return false;
    }
  }

  bool get isActive {
    if (isExpired) return false;
    if (startDate != null) {
      try {
        final start = DateTime.parse(startDate!);
        if (DateTime.now().isBefore(start)) return false;
      } catch (_) {
        // Ignore date parse errors
      }
    }
    return true;
  }

  String get formattedPeriod {
    if (startDate == null || endDate == null) return '';
    try {
      final start = DateTime.parse(startDate!);
      final end = DateTime.parse(endDate!);
      
      final startFormatted = '${start.day}/${start.month}/${start.year}';
      final endFormatted = '${end.day}/${end.month}/${end.year}';
      
      return '$startFormatted s/d $endFormatted';
    } catch (e) {
      return '$startDate s/d $endDate';
    }
  }
}

class DetailVoucher {
  final int id;
  final int userId;
  final int voucherId;
  final int? orderId;
  final String? claimCode;
  final String status; // 'inactive', 'active', 'used', 'expired'
  final String? purchaseDate;
  final String? activationDate;
  final String? expiryDate;
  final String? purchasedAt;
  final int pointsUsed;
  final double cashPaid;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? paymentReference;
  final String? purchaseType; // 'points', 'cash', 'distributed', 'birthday', 'promo'
  final String? lastUsedAt;
  final int usageCount;
  final Voucher? voucher;

  DetailVoucher({
    required this.id,
    required this.userId,
    required this.voucherId,
    this.orderId,
    this.claimCode,
    required this.status,
    this.purchaseDate,
    this.activationDate,
    this.expiryDate,
    this.purchasedAt,
    this.pointsUsed = 0,
    this.cashPaid = 0,
    this.paymentStatus,
    this.paymentMethod,
    this.paymentReference,
    this.purchaseType,
    this.lastUsedAt,
    this.usageCount = 0,
    this.voucher,
  });

  factory DetailVoucher.fromJson(Map<String, dynamic> json) {
    return DetailVoucher(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      voucherId: _parseInt(json['voucher_id']) ?? 0,
      orderId: _parseInt(json['order_id']),
      claimCode: json['claim_code']?.toString(),
      status: json['status']?.toString() ?? 'inactive',
      purchaseDate: json['purchase_date']?.toString(),
      activationDate: json['activation_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      purchasedAt: json['purchased_at']?.toString(),
      pointsUsed: _parseInt(json['points_used']) ?? 0,
      cashPaid: _parseDouble(json['cash_paid']) ?? 0,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      purchaseType: json['purchase_type']?.toString(),
      lastUsedAt: json['last_used_at']?.toString(),
      usageCount: _parseInt(json['usage_count']) ?? 0,
      voucher: json['voucher'] != null
          ? Voucher.fromJson(json['voucher'] as Map<String, dynamic>)
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'voucher_id': voucherId,
      if (orderId != null) 'order_id': orderId,
      if (claimCode != null) 'claim_code': claimCode,
      'status': status,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
      if (activationDate != null) 'activation_date': activationDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (purchasedAt != null) 'purchased_at': purchasedAt,
      'points_used': pointsUsed,
      'cash_paid': cashPaid,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentReference != null) 'payment_reference': paymentReference,
      if (purchaseType != null) 'purchase_type': purchaseType,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      'usage_count': usageCount,
      if (voucher != null) 'voucher': voucher!.toJson(),
    };
  }

  bool get isInactive => status == 'inactive';
  bool get isActive => status == 'active';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired';

  bool get canActivate => isInactive && !isExpired;
  bool get canUse => isActive && !isExpired;

  String get formattedExpiryDate {
    if (expiryDate == null) return '';
    try {
      final date = DateTime.parse(expiryDate!);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return expiryDate ?? '';
    }
  }

  String get statusText {
    switch (status) {
      case 'inactive':
        return 'Belum Aktif';
      case 'active':
        return 'Aktif';
      case 'used':
        return 'Terpakai';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }
}

class VoucherUsageValidation {
  final bool canUse;
  final String message;
  final String? nextAvailable;
  final int usageCount;
  final int? maxUsagePerUser;
  final int? maxUsagePerDay;

  VoucherUsageValidation({
    required this.canUse,
    required this.message,
    this.nextAvailable,
    required this.usageCount,
    this.maxUsagePerUser,
    this.maxUsagePerDay,
  });

  factory VoucherUsageValidation.fromJson(Map<String, dynamic> json) {
    return VoucherUsageValidation(
      canUse: json['can_use'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      nextAvailable: json['next_available']?.toString(),
      usageCount: _parseInt(json['usage_count']) ?? 0,
      maxUsagePerUser: _parseInt(json['max_usage_per_user']),
      maxUsagePerDay: _parseInt(json['max_usage_per_day']));
  }
}

class UserVoucher {
  final int id;
  final int userId;
  final int voucherId;
  final Voucher? voucher;
  final String? obtainedAt;
  final String? usedAt;
  final bool isUsed;

  UserVoucher({
    required this.id,
    required this.userId,
    required this.voucherId,
    this.voucher,
    this.obtainedAt,
    this.usedAt,
    this.isUsed = false,
  });

  factory UserVoucher.fromJson(Map<String, dynamic> json) {
    return UserVoucher(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      voucherId: _parseInt(json['voucher_id']) ?? 0,
      voucher: json['voucher'] != null
          ? Voucher.fromJson(json['voucher'] as Map<String, dynamic>)
          : null,
      obtainedAt: json['obtained_at']?.toString(),
      usedAt: json['used_at']?.toString(),
      isUsed: json['is_used'] == 1 || json['is_used'] == true);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'voucher_id': voucherId,
      'voucher': voucher?.toJson(),
      'obtained_at': obtainedAt,
      'used_at': usedAt,
      'is_used': isUsed,
    };
  }
}

class PointHistory {
  final int id;
  final int userId;
  final int points;
  final int signedPoints;
  final String type; // 'earned', 'used', 'expired'
  final String? description;
  final int? orderId;
  final String? createdAt;

  PointHistory({
    required this.id,
    required this.userId,
    required this.points,
    required this.signedPoints,
    required this.type,
    this.description,
    this.orderId,
    this.createdAt,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    final signed = _parseInt(json['signed_points']) ??
        _parseInt(json['point']) ??
        _parseInt(json['points']) ??
        0;

    return PointHistory(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']) ?? 0,
      points: signed.abs(),
      signedPoints: signed,
      type: json['type']?.toString() ?? 'earned',
      description: json['description']?.toString(),
      orderId: _parseInt(json['order_id']),
      createdAt: json['created_at']?.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'points': points,
      'signed_points': signedPoints,
      'type': type,
      'description': description,
      'order_id': orderId,
      'created_at': createdAt,
    };
  }

  bool get isEarned => signedPoints >= 0;
  bool get isUsed => signedPoints < 0 || ['used', 'redeemed', 'debit'].contains(type);
  bool get isExpired => type == 'expired';

  String get formattedPoints {
    final sign = signedPoints >= 0 ? '+' : '-';
    return '$sign${signedPoints.abs()}';
  }

  String get formattedDate {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt!);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return createdAt ?? '';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
