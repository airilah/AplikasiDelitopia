import '../../core/localization/app_language.dart';
import '../../core/utils/brand_name_formatter.dart';

class Voucher {
  final int id;
  final String name;
  final String code;
  final String
      type; // 'discount_percentage', 'discount_amount', 'free_delivery', 'birthday'
  final double? discountPercentage;
  final double? discountAmount;
  final double minPurchase;
  final double? maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;
  final String? image;
  final String? brandName;
  final int? brandId;
  final bool isActive;
  final int? usageLimit;
  final int? usageCount;
  final int? userUsageLimit;

  Voucher({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.brandName,
    this.brandId,
    this.discountPercentage,
    this.discountAmount,
    this.minPurchase = 0,
    this.maxDiscount,
    this.startDate,
    this.endDate,
    this.description,
    this.image,
    this.isActive = true,
    this.usageLimit,
    this.usageCount,
    this.userUsageLimit,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    String? parsedBrandName;
    if (json['brand_name'] != null && json['brand_name'].toString().isNotEmpty) {
      parsedBrandName = formatBrandName(json['brand_name'].toString());
    } else if (json['brand'] != null && json['brand'] is Map) {
      final brandMap = json['brand'] as Map;
      if (brandMap['name'] != null) {
        parsedBrandName = formatBrandName(brandMap['name'].toString());
      }
    }

    final parsedBrandId = (json['brand_id'] as num?)?.toInt() ??
        ((json['brand'] is Map) ? (json['brand']['id'] as num?)?.toInt() : null);

    if (parsedBrandName == null || parsedBrandName.isEmpty) {
      parsedBrandName = 'Semua Brand';
    } else if ((parsedBrandName.toLowerCase() == 'delitopia' ||
            parsedBrandName.toLowerCase() == 'all' ||
            parsedBrandName.toLowerCase() == 'semua' ||
            parsedBrandName.toLowerCase() == 'semua brand') &&
        (parsedBrandId == null || parsedBrandId == 0)) {
      parsedBrandName = 'Semua Brand';
    }

    return Voucher(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['voucher_name']?.toString() ?? json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? 'VOUCHER${json['id']}',
      type: json['voucher_type']?.toString() ??
          json['type']?.toString() ??
          'discount',
      brandName: parsedBrandName,
      brandId: parsedBrandId,
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      minPurchase: (json['min_spend'] as num?)?.toDouble() ??
          (json['min_purchase'] as num?)?.toDouble() ??
          0,
      maxDiscount: (json['max_discount'] as num?)?.toDouble() ??
          (json['max_discount_amount'] as num?)?.toDouble(),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date']?.toString() ?? '')
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date']?.toString() ?? '')
          : null,
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['active'] == true ||
          json['active'] == 1,
      usageLimit: (json['usage_limit'] as num?)?.toInt(),
      usageCount: (json['usage_count'] as num?)?.toInt(),
      userUsageLimit: (json['user_usage_limit'] as num?)?.toInt());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'min_purchase': minPurchase,
      'max_discount': maxDiscount,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'description': description,
      'image': image,
      'is_active': isActive,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'user_usage_limit': userUsageLimit,
    };
  }

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  bool get isStarted {
    if (startDate == null) return true;
    return DateTime.now().isAfter(startDate!);
  }

  bool get isValid => isActive && !isExpired && isStarted;

  String get discountText {
    if (type == 'discount_percentage' && discountPercentage != null) {
      if (maxDiscount != null && maxDiscount! > 0) {
        final cap = maxDiscount!;
        final capText = cap >= 1000
            ? '${(cap / 1000).toInt()}rb'
            : cap.toInt().toString();
        return '${discountPercentage!.toInt()}% s.d. Rp $capText';
      }
      return '${discountPercentage!.toInt()}% OFF';
    } else if (type == 'discount_amount' && discountAmount != null) {
      return 'Rp ${discountAmount!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} OFF';
    } else if (type == 'free_delivery') {
      return 'FREE DELIVERY';
    } else if (type == 'birthday') {
      return 'BIRTHDAY SPECIAL';
    }
    return 'VOUCHER';
  }

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

  String get expiryText {
    return expiryTextFor(AppLanguage.english);
  }

  String expiryTextFor(AppLanguage lang) {
    if (endDate == null) return tr.get('no_expiry', lang);
    final difference = endDate!.difference(DateTime.now());
    if (difference.inDays > 30) {
      return '${tr.get('expires_on', lang)} ${endDate!.day}/${endDate!.month}/${endDate!.year}';
    } else if (difference.inDays > 0) {
      return tr
          .get('expires_in_days', lang)
          .replaceFirst('{count}', difference.inDays.toString());
    } else if (difference.inHours > 0) {
      return tr
          .get('expires_in_hours', lang)
          .replaceFirst('{count}', difference.inHours.toString());
    } else {
      return tr.get('expired', lang);
    }
  }
}

class UserVoucher {
  final int id;
  final int userId;
  final int voucherId;
  final Voucher? voucher;
  final String status; // 'available', 'used', 'expired'
  final DateTime? usedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  UserVoucher({
    required this.id,
    required this.userId,
    required this.voucherId,
    this.voucher,
    required this.status,
    this.usedAt,
    this.expiresAt,
    required this.createdAt,
  });

  factory UserVoucher.fromJson(Map<String, dynamic> json) {
    return UserVoucher(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      voucherId: (json['voucher_id'] as num?)?.toInt() ?? 0,
      voucher: json['voucher'] != null
          ? Voucher.fromJson(json['voucher'] as Map<String, dynamic>)
          : null,
      status: json['status']?.toString() ?? 'available',
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at']?.toString() ?? '')
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at']?.toString() ?? '')
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'voucher_id': voucherId,
      'voucher': voucher?.toJson(),
      'status': status,
      'used_at': usedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAvailable => status == 'available' && !isExpired;
  bool get isUsed => status == 'used';
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
