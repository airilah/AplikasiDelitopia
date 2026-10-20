import '../../core/utils/brand_name_formatter.dart';

// ── Alias mapper (keeps shared model self-contained) ─────────────────
String _normaliseStatus(String? raw) {
  switch ((raw ?? 'pending_payment').toLowerCase().trim()) {
    case 'pending':       return 'pending_payment';
    case 'delivering':
    case 'on_delivery':  return 'out_for_delivery';
    case 'delivered':
    case 'success':      return 'completed';
    default:             return (raw ?? 'pending_payment').toLowerCase().trim();
  }
}

class Order {
  final int? id;
  final String? orderId;
  final String date;
  final String orderType;
  final double grandTotal;
  final double finalTotal;
  final double service;
  final double tax;
  final double deliveryFee;
  final String? notes;
  final String? pickupTime;
  final String payment;
  final String? pgQrString;
  final DateTime? pgExpiredQr;
  /// Canonical order status (always normalised — see _normaliseStatus).
  final String status;
  final String paymentStatus;
  final int point;
  final int userId;
  final int branchId;
  final String? tableNumber;
  final int? promoId;
  final int? userVoucherId;
  final String? voucherName;
  final String? voucherType;
  final String? deliverAddress;
  final double? deliverLat;
  final double? deliverLong;
  final String? brandName;
  final String? brandLogo;
  final String? branchAddress;
  final String? trackUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderDetail>? details;

  Order({
    this.id,
    this.orderId,
    required this.date,
    required this.orderType,
    required this.grandTotal,
    required this.finalTotal,
    required this.service,
    required this.tax,
    this.deliveryFee = 0,
    this.notes,
    this.pickupTime,
    required this.payment,
    this.pgQrString,
    this.pgExpiredQr,
    this.status = 'pending_payment',
    this.paymentStatus = 'pending',
    this.point = 0,
    required this.userId,
    required this.branchId,
    this.tableNumber,
    this.promoId,
    this.userVoucherId,
    this.voucherName,
    this.voucherType,
    this.deliverAddress,
    this.deliverLat,
    this.deliverLong,
    this.brandName,
    this.brandLogo,
    this.branchAddress,
    this.trackUrl,
    this.createdAt,
    this.updatedAt,
    this.details,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      orderId: json['order_id']?.toString(),
      date: json['date']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? 'dine_in',
      grandTotal: (json['grand_total'] ?? 0).toDouble(),
      finalTotal: (json['final_total'] ?? 0).toDouble(),
      service: (json['service'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      notes: json['notes']?.toString(),
      pickupTime: json['pickup_time']?.toString(),
      payment: json['payment']?.toString() ?? '',
      pgQrString: json['pg_qr_string']?.toString(),
      pgExpiredQr: json['pg_expired_qr'] != null
          ? DateTime.tryParse(json['pg_expired_qr']?.toString() ?? '')
          : null,
      // Normalise status so old values map to the new lifecycle
      status: _normaliseStatus(json['status']?.toString()),
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      point: json['point'] is int ? json['point'] : int.tryParse(json['point']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      branchId: json['branch_id'] is int ? json['branch_id'] : int.tryParse(json['branch_id']?.toString() ?? '0') ?? 0,
      tableNumber: json['table_number']?.toString(),
      promoId: json['promo_id'] is int ? json['promo_id'] : int.tryParse(json['promo_id']?.toString() ?? ''),
      userVoucherId: json['user_voucher_id'] is int ? json['user_voucher_id'] : int.tryParse(json['user_voucher_id']?.toString() ?? ''),
      voucherName: json['voucher_name']?.toString(),
      voucherType: json['voucher_type']?.toString(),
      deliverAddress: json['deliver_address']?.toString(),
      deliverLat: json['deliver_lat'] != null ? (json['deliver_lat'] as num).toDouble() : null,
      deliverLong: json['deliver_long'] != null ? (json['deliver_long'] as num).toDouble() : null,
      brandName: json['brand_name'] != null ? formatBrandName(json['brand_name']) : null,
      brandLogo: json['brand_logo']?.toString(),
      branchAddress: json['branch_address']?.toString(),
      trackUrl: json['track_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '')
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
          : null,
      details: json['details'] != null
          ? (json['details'] as List)
              .map((d) => OrderDetail.fromJson(d as Map<String, dynamic>))
              .toList()
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'grand_total': grandTotal,
      'final_total': finalTotal,
      'discount': 0,
      'tax': tax,
      'service': service,
      'delivery_fee': deliveryFee,
      'order_type': orderType,
      'notes': notes,
      'pickup_time': pickupTime,
      'payment': payment,
      'user_id': userId,
      'branch_id': branchId,
      'table_number': tableNumber,
      'promo_id': promoId,
      'user_voucher_id': userVoucherId,
      'deliver_address': deliverAddress,
      'deliver_lat': deliverLat,
      'deliver_long': deliverLong,
      'details': details?.map((d) => d.toJson()).toList(),
    };
  }
}

class OrderDetail {
  final int? id;
  final int? orderId;
  final int menuId;
  final String? menuName;
  final String? menuCode;
  final String? notes;
  final int qty;
  final double total;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderDetail({
    this.id,
    this.orderId,
    required this.menuId,
    this.menuName,
    this.menuCode,
    this.notes,
    required this.qty,
    required this.total,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      id: json['id'],
      orderId: json['order_id'],
      menuId: json['menu_id'],
      menuName: json['menu_name'],
      menuCode: json['menu_code'],
      notes: json['notes'],
      qty: json['qty'],
      total: (json['total'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '')
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      'menu_code': menuCode,
      'notes': notes,
      'qty': qty,
      'total': total,
    };
  }
}

class QRISPaymentResponse {
  final String paymentMethod;
  final String qrString;
  final DateTime expiredTime;
  final String transactionId;
  final String externalId;
  final String orderId;

  QRISPaymentResponse({
    required this.paymentMethod,
    required this.qrString,
    required this.expiredTime,
    required this.transactionId,
    required this.externalId,
    required this.orderId,
  });

  factory QRISPaymentResponse.fromJson(Map<String, dynamic> json) {
    return QRISPaymentResponse(
      paymentMethod: json['payment_method'],
      qrString: json['qr_string'],
      expiredTime: DateTime.tryParse(json['expired_time']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 1)),
      transactionId: json['transaction_id'],
      externalId: json['external_id'],
      orderId: json['order_id']);
  }
}

class PointHistory {
  final String point;
  final DateTime expiredAt;

  PointHistory({
    required this.point,
    required this.expiredAt,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    return PointHistory(
      point: json['point'].toString(),
      expiredAt: DateTime.tryParse(json['expired_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 1)));
  }
}
