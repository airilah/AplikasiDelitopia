class VoucherBrand {
  final String name;
  final String? logo;

  VoucherBrand({
    required this.name,
    this.logo,
  });

  factory VoucherBrand.fromJson(Map<String, dynamic> json) {
    return VoucherBrand(
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logo': logo,
    };
  }
}

class VoucherDetail {
  final int id;
  final String voucherName;
  final String voucherType;
  final String? description;
  final double? discountPercentage;
  final double? discountAmount;
  final double? maxDiscountAmount;
  final double minSpend;
  final String? image;
  final VoucherBrand? brand;

  VoucherDetail({
    required this.id,
    required this.voucherName,
    required this.voucherType,
    this.description,
    this.discountPercentage,
    this.discountAmount,
    this.maxDiscountAmount,
    this.minSpend = 0,
    this.image,
    this.brand,
  });

  factory VoucherDetail.fromJson(Map<String, dynamic> json) {
    return VoucherDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      voucherName: json['voucher_name']?.toString() ?? '',
      voucherType: json['voucher_type']?.toString() ?? 'discount',
      description: json['description']?.toString(),
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble() ??
          (json['max_discount'] as num?)?.toDouble(),
      minSpend: (json['min_spend'] as num?)?.toDouble() ?? 0,
      image: json['image']?.toString(),
      brand: json['brand'] != null 
          ? (json['brand'] is Map 
              ? VoucherBrand.fromJson(json['brand'] as Map<String, dynamic>)
              : VoucherBrand(name: json['brand'].toString()))
          : (json['brand_name'] != null 
              ? VoucherBrand(name: json['brand_name'].toString())
              : null));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_name': voucherName,
      'voucher_type': voucherType,
      'description': description,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      if (maxDiscountAmount != null) 'max_discount_amount': maxDiscountAmount,
      'min_spend': minSpend,
      'image': image,
      'brand': brand?.toJson(),
    };
  }

  String get displayBrandName {
    if (brand?.name != null && brand!.name.trim().isNotEmpty) {
      final bnLower = brand!.name.trim().toLowerCase();
      if (bnLower == 'all' || bnLower == 'semua' || bnLower == 'semua brand') {
        return 'Semua Brand';
      }
      return brand!.name;
    }
    return 'Semua Brand';
  }

  String get discountText {
    if (voucherType == 'discount_percentage' && discountPercentage != null) {
      if (maxDiscountAmount != null && maxDiscountAmount! > 0) {
        final cap = maxDiscountAmount!;
        final capText = cap >= 1000
            ? '${(cap / 1000).toInt()}rb'
            : _formatNumber(cap.toInt());
        return '${discountPercentage!.toInt()}% s.d. Rp $capText';
      }
      return '${discountPercentage!.toInt()}% OFF';
    } else if (voucherType == 'discount_amount' && discountAmount != null) {
      return 'Rp ${_formatNumber(discountAmount!.toInt())} OFF';
    } else if (voucherType == 'free_menu') {
      return 'FREE MENU';
    } else if (voucherType == 'free_delivery') {
      return 'FREE DELIVERY';
    }
    return 'VOUCHER';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.');
  }
}

class UserVoucher {
  final int id;
  final String? claimCode;
  final String status;
  final DateTime? expiryDate;
  final DateTime? activationDate;
  final int usageCount;
  final VoucherDetail voucher;

  UserVoucher({
    required this.id,
    this.claimCode,
    required this.status,
    this.expiryDate,
    this.activationDate,
    this.usageCount = 0,
    required this.voucher,
  });

  factory UserVoucher.fromJson(Map<String, dynamic> json) {
    return UserVoucher(
      id: (json['id'] as num?)?.toInt() ?? 0,
      claimCode: json['claim_code']?.toString(),
      status: json['status']?.toString() ?? 'inactive',
      expiryDate: json['expiry_date'] != null 
          ? DateTime.tryParse(json['expiry_date']?.toString() ?? '')
          : null,
      activationDate: json['activation_date'] != null
          ? DateTime.tryParse(json['activation_date']?.toString() ?? '')
          : null,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      voucher: VoucherDetail.fromJson(json['voucher'] as Map<String, dynamic>));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claim_code': claimCode,
      'status': status,
      'expiry_date': expiryDate?.toIso8601String(),
      'activation_date': activationDate?.toIso8601String(),
      'usage_count': usageCount,
      'voucher': voucher.toJson(),
    };
  }

  bool get isExpired => status == 'expired' || (expiryDate != null && DateTime.now().isAfter(expiryDate!));
  bool get isActive => status == 'active' && !isExpired;
  bool get isInactive => status == 'inactive' && !isExpired;
  bool get isUsed => status == 'used';
  bool get hasClaimCode => claimCode != null && claimCode!.isNotEmpty;
}

class MyVouchersResponse {
  final List<UserVoucher> vouchers;
  final int totalActive;
  final int totalInactive;
  final int totalUsed;

  MyVouchersResponse({
    required this.vouchers,
    required this.totalActive,
    required this.totalInactive,
    required this.totalUsed,
  });

  factory MyVouchersResponse.fromJson(Map<String, dynamic> json) {
    return MyVouchersResponse(
      vouchers: (json['vouchers'] as List<dynamic>?)
              ?.map((v) => UserVoucher.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      totalActive: (json['total_active'] as num?)?.toInt() ?? 0,
      totalInactive: (json['total_inactive'] as num?)?.toInt() ?? 0,
      totalUsed: (json['total_used'] as num?)?.toInt() ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'vouchers': vouchers.map((v) => v.toJson()).toList(),
      'total_active': totalActive,
      'total_inactive': totalInactive,
      'total_used': totalUsed,
    };
  }
}
