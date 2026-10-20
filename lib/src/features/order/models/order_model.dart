import 'package:flutter/material.dart';
import '../../../core/localization/app_language.dart';

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final numericPart = value.trim();
    if (numericPart.isEmpty) return null;
    if (RegExp(r'^-?\d+$').hasMatch(numericPart)) {
      return int.tryParse(numericPart);
    }
    return null;
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// ─────────────────────────────────────────────
// OrderStatus — canonical constants + aliases
// ─────────────────────────────────────────────
class OrderStatus {
  // ── Official statuses ──────────────────
  static const String pendingPayment  = 'pending_payment';
  static const String paymentFailed   = 'payment_failed';
  static const String expired         = 'expired';
  static const String paid            = 'paid';
  static const String confirmed       = 'confirmed';
  static const String rejected        = 'rejected';
  static const String preparing       = 'preparing';
  static const String ready           = 'ready';           // Dine-in only
  static const String readyForPickup  = 'ready_for_pickup'; // Take Away / Delivery ready
  static const String pickingUp       = 'picking_up';      // Delivery Grab heading to outlet
  static const String pickedUp        = 'picked_up';       // Delivery Grab picked up food
  static const String inDelivery      = 'in_delivery';      // Delivery Grab delivering
  static const String outForDelivery  = 'out_for_delivery'; // Delivery alias
  static const String completed       = 'completed';
  static const String cancelled       = 'cancelled';

  /// Normalise any backend value to a canonical status.
  static String normalise(String raw, {String orderType = 'dine_in'}) {
    final status = raw.toLowerCase().trim();
    final type = orderType.toLowerCase().trim();

    switch (status) {
      case 'pending':
      case 'pending_payment':
      case 'awaiting_payment':
      case 'menunggu':
      case 'menunggu_pembayaran':
        return pendingPayment;
      case 'paid_waiting_confirmation':
      case 'paid':
      case 'sudah_bayar':
      case 'lunas':
        return paid;
      case 'expired':
      case 'expire':
      case 'kadaluarsa':
      case 'kedaluwarsa':
        return expired;
      case 'confirmed':
      case 'accepted':
      case 'diterima':
      case 'dikonfirmasi':
        return confirmed;
      case 'preparing':
      case 'diproses':
      case 'dimasak':
      case 'disiapkan':
        return preparing;
      case 'ready':
        if (type == 'delivery') return readyForPickup;
        if (type.contains('take') || type == 'pickup') return readyForPickup;
        return ready;
      case 'ready_for_pickup':
      case 'siap_diambil':
      case 'siap':
        return readyForPickup;
      case 'picking_up':
      case 'picking_up_driver':
        return pickingUp;
      case 'picked_up':
      case 'driver_picked_up':
      case 'diambil_kurir':
      case 'sudah_diambil':
        return pickedUp;
      case 'in_delivery':
      case 'out_for_delivery':
      case 'delivering':
      case 'on_delivery':
      case 'dikirim':
      case 'dalam_pengiriman':
        return inDelivery;
      case 'completed':
      case 'delivered':
      case 'success':
      case 'selesai':
      case 'done':
      case 'finish':
      case 'finished':
      case 'closed':
      case 'terkirim':
        return completed;
      case 'rejected':
      case 'failed':
      case 'payment_failed':
      case 'cancelled':
      case 'canceled':
      case 'cancel':
      case 'batal':
      case 'dibatalkan':
      case 'gagal':
        return cancelled;
      default:
        return status;
    }
  }

  /// Returns true if the status is one of the active/in-progress states.
  static bool isActiveStatus(String status, {String orderType = 'dine_in'}) {
    const active = {
      pendingPayment,
      paid,
      confirmed,
      preparing,
      ready,
      readyForPickup,
      pickingUp,
      pickedUp,
      inDelivery,
      outForDelivery,
    };
    return active.contains(normalise(status, orderType: orderType));
  }

  /// Returns true if the order is in a terminal state.
  static bool isTerminalStatus(String status, {String orderType = 'dine_in'}) {
    const terminal = {paymentFailed, expired, rejected, completed, cancelled};
    final norm = normalise(status, orderType: orderType);
    if (terminal.contains(norm)) return true;
    return !isActiveStatus(status, orderType: orderType);
  }

  // ── UI helpers ────────────────────────────

  static Color color(String raw, {String orderType = 'dine_in'}) {
    switch (normalise(raw, orderType: orderType)) {
      case pendingPayment:   return const Color(0xFFF59E0B); // amber
      case paymentFailed:    return const Color(0xFFEF4444); // red
      case expired:          return const Color(0xFF6B7280); // gray
      case paid:             return const Color(0xFF10B981); // emerald
      case confirmed:        return const Color(0xFF3B82F6); // blue
      case rejected:         return const Color(0xFFEF4444); // red
      case preparing:        return const Color(0xFF8B5CF6); // violet
      case ready:            return const Color(0xFF06B6D4); // cyan
      case readyForPickup:   return const Color(0xFF06B6D4); // cyan
      case pickingUp:        return const Color(0xFF0284C7); // sky blue
      case pickedUp:         return const Color(0xFF6366F1); // indigo
      case inDelivery:
      case outForDelivery:   return const Color(0xFF6366F1); // indigo
      case completed:        return const Color(0xFF22C55E); // green
      case cancelled:        return const Color(0xFF6B7280); // gray
      default:               return const Color(0xFF6B7280);
    }
  }

  static IconData icon(String raw, {String orderType = 'dine_in'}) {
    switch (normalise(raw, orderType: orderType)) {
      case pendingPayment:   return Icons.payment_outlined;
      case paymentFailed:    return Icons.payment_rounded;
      case expired:          return Icons.hourglass_disabled_rounded;
      case paid:             return Icons.check_circle_outline_rounded;
      case confirmed:        return Icons.thumb_up_alt_outlined;
      case rejected:         return Icons.cancel_outlined;
      case preparing:        return Icons.restaurant_rounded;
      case ready:            return Icons.dinner_dining_rounded;
      case readyForPickup:   return Icons.shopping_bag_outlined;
      case pickingUp:        return Icons.moped_rounded;
      case pickedUp:         return Icons.inventory_2_rounded;
      case inDelivery:
      case outForDelivery:   return Icons.delivery_dining_rounded;
      case completed:        return Icons.check_circle_rounded;
      case cancelled:        return Icons.block_rounded;
      default:               return Icons.receipt_long_rounded;
    }
  }

  static String label(String raw, {String orderType = 'dine_in', AppLanguage lang = AppLanguage.indonesia}) {
    final s = normalise(raw, orderType: orderType);
    final type = orderType.toLowerCase();
    final isEn = lang == AppLanguage.english;

    switch (s) {
      case pendingPayment:   return isEn ? 'Awaiting Payment' : 'Menunggu Pembayaran';
      case paymentFailed:    return isEn ? 'Payment Failed' : 'Pembayaran Gagal';
      case expired:          return isEn ? 'Expired' : 'Kedaluwarsa';
      case paid:             return isEn ? 'Awaiting Confirmation' : 'Menunggu Konfirmasi';
      case confirmed:        return isEn ? 'Order Accepted' : 'Pesanan Diterima';
      case rejected:         return isEn ? 'Order Rejected' : 'Pesanan Ditolak';
      case preparing:        return isEn ? 'Preparing Order' : 'Sedang Disiapkan';
      case ready:            return isEn ? 'Ready to Serve' : 'Siap Disajikan';
      case readyForPickup:   return type == 'delivery' ? (isEn ? 'Ready for Driver' : 'Siap Diambil Kurir') : (isEn ? 'Ready for Pickup' : 'Siap Diambil');
      case pickingUp:        return isEn ? 'Driver Heading to Restaurant' : 'Kurir Menuju Restoran';
      case pickedUp:         return isEn ? 'Picked Up by Driver' : 'Pesanan Diambil Kurir';
      case inDelivery:
      case outForDelivery:   return isEn ? 'Out for Delivery' : 'Dalam Pengiriman';
      case completed:
        if (type == 'delivery')   return isEn ? 'Order Delivered' : 'Pesanan Terkirim';
        if (type == 'takeaway' || type == 'take_away' || type == 'pickup') return isEn ? 'Picked Up' : 'Sudah Diambil';
        return isEn ? 'Completed' : 'Selesai';
      case cancelled:        return isEn ? 'Cancelled' : 'Dibatalkan';
      default:
        return raw.replaceAll('_', ' ').split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
    }
  }
}

// ─────────────────────────────────────────────
// Order model
// ─────────────────────────────────────────────
class Order {
  final int id;
  final String orderNumber;
  final int userId;
  final int branchId;
  final String branchName;
  final String? brandLogo;
  final String? branchAddress;
  final String? branchPhone;
  final double? branchLat;
  final double? branchLong;

  /// Values: 'dine_in' | 'takeaway' | 'take_away' | 'delivery'
  final String deliveryType;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final double? deliverLat;
  final double? deliverLong;
  final double deliveryFee;

  final double totalPrice;
  final double taxAmount;
  final double serviceAmount;
  final double discount;
  final double finalPrice;

  /// Canonical status — always normalised through [OrderStatus.normalise].
  final String status;

  /// Raw payment method string from backend.
  final String paymentMethod;

  /// 'pending' | 'paid' | 'failed'
  final String paymentStatus;

  final int point;

  /// Optional cancellation reason stored by backend.
  final String? cancelReason;
  final String? tableNumber;
  final String? trackUrl;
  final Map<String, dynamic>? grabDriver;
  final String? pickupPin;
  final String? pgQrString;
  final DateTime? pgExpiredQr;

  final int? voucherId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? customerName;
  final String? customerPhone;
  final List<OrderDetail> items;

  // ── Estimation fields ─────────────────────
  final int? estimatedPrepTime;
  final int? estimatedDeliveryDuration;
  final int? estimatedTotalTime;
  final DateTime? estimatedReadyAt;
  final DateTime? estimatedDeliveryAt;
  final String? targetTimeFormatted;
  final String? rangeText;

  Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.branchId,
    required this.branchName,
    this.customerName,
    this.customerPhone,
    this.brandLogo,
    this.branchAddress,
    this.branchPhone,
    this.branchLat,
    this.branchLong,
    required this.deliveryType,
    this.deliveryAddress,
    this.deliveryNotes,
    this.deliverLat,
    this.deliverLong,
    this.deliveryFee = 0,
    required this.totalPrice,
    this.taxAmount = 0,
    this.serviceAmount = 0,
    this.discount = 0,
    required this.finalPrice,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.point = 0,
    this.cancelReason,
    this.tableNumber,
    this.trackUrl,
    this.grabDriver,
    this.pickupPin,
    this.pgQrString,
    this.pgExpiredQr,
    this.voucherId,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.estimatedPrepTime,
    this.estimatedDeliveryDuration,
    this.estimatedTotalTime,
    this.estimatedReadyAt,
    this.estimatedDeliveryAt,
    this.targetTimeFormatted,
    this.rangeText,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      final grandTotal = _parseDouble(json['grand_total']) ??
          _parseDouble(json['total_price']) ??
          0.0;
      final taxVal = _parseDouble(json['tax']) ?? (grandTotal * 0.10);
      final serviceVal = _parseDouble(json['service']) ?? (grandTotal * 0.05);
      final rawStatus = json['status']?.toString() ?? 'pending_payment';

      return Order(
        id: _parseInt(json['id']) ?? 0,
        orderNumber: json['order_id']?.toString() ??
            json['order_number']?.toString() ??
            '',
        userId: _parseInt(json['user_id']) ?? 0,
        branchId: _parseInt(json['branch_id']) ?? 0,
        branchName: json['brand_name']?.toString() ??
            json['branch_name']?.toString() ??
            '',
        customerName: json['customer_name']?.toString() ??
            json['user_name']?.toString() ??
            json['user']?['name']?.toString() ??
            json['customer']?['name']?.toString(),
        customerPhone: json['customer_phone']?.toString() ??
            json['phone_number']?.toString() ??
            json['user_phone']?.toString() ??
            json['user']?['phone_number']?.toString() ??
            json['user']?['phone']?.toString() ??
            json['customer']?['phone_number']?.toString(),
        brandLogo:
            json['brand_logo']?.toString() ?? json['logo']?.toString(),
        branchAddress: json['branch_address']?.toString() ??
            json['address']?.toString(),
        branchPhone: json['branch_phone']?.toString() ??
            json['branch_phone_number']?.toString() ??
            json['branch']?['phone_number']?.toString() ??
            json['branch']?['phone']?.toString() ??
            json['phone_number']?.toString(),
        branchLat: _parseDouble(json['branch_latitude']) ??
            _parseDouble(json['branch']?['latitude']),
        branchLong: _parseDouble(json['branch_longitude']) ??
            _parseDouble(json['branch']?['longitude']),
        deliveryType: json['order_type']?.toString() ??
            json['delivery_type']?.toString() ??
            'dine_in',
        deliveryAddress: json['deliver_address']?.toString() ??
            json['delivery_address']?.toString(),
        deliveryNotes: json['delivery_notes']?.toString() ??
            json['deliver_notes']?.toString() ??
            json['address_notes']?.toString() ??
            json['notes']?.toString(),
        deliverLat: _parseDouble(json['deliver_lat']) ??
            _parseDouble(json['destination_lat']) ??
            _parseDouble(json['destination']?['lat']),
        deliverLong: _parseDouble(json['deliver_long']) ??
            _parseDouble(json['destination_long']) ??
            _parseDouble(json['destination']?['long']),
        deliveryFee: _parseDouble(json['delivery_fee']) ?? 0.0,
        totalPrice: grandTotal,
        taxAmount: taxVal,
        serviceAmount: serviceVal,
        discount: _parseDouble(json['discount']) ?? 0.0,
        finalPrice: _parseDouble(json['final_total']) ??
            _parseDouble(json['final_price']) ??
            (grandTotal + taxVal + serviceVal -
                (_parseDouble(json['discount']) ?? 0.0)),
        status: OrderStatus.normalise(
          rawStatus,
          orderType: json['order_type']?.toString() ??
              json['delivery_type']?.toString() ??
              'dine_in',
        ),
        paymentMethod: json['payment']?.toString() ??
            json['payment_method']?.toString() ??
            '',
        paymentStatus: (json['payment_status']?.toString() ?? 'pending')
            .toLowerCase()
            .trim(),
        point: _parseInt(json['point']) ?? 0,
        cancelReason: json['cancel_reason']?.toString() ??
            json['cancellation_reason']?.toString(),
        tableNumber: json['table_number']?.toString() ??
            json['tableNumber']?.toString(),
        trackUrl: json['track_url']?.toString() ??
            (json['latest_grab_express'] is Map ? json['latest_grab_express']['track_url']?.toString() : null) ??
            (json['latestGrabExpress'] is Map ? json['latestGrabExpress']['track_url']?.toString() : null),
        grabDriver: json['grab_driver'] is Map
            ? Map<String, dynamic>.from(json['grab_driver'] as Map)
            : (json['latest_grab_express'] is Map && json['latest_grab_express']['driver'] is Map
                ? Map<String, dynamic>.from(json['latest_grab_express']['driver'] as Map)
                : (json['latestGrabExpress'] is Map && json['latestGrabExpress']['driver'] is Map
                    ? Map<String, dynamic>.from(json['latestGrabExpress']['driver'] as Map)
                    : null)),
        pickupPin: json['pickup_pin']?.toString() ??
            (json['latest_grab_express'] is Map ? json['latest_grab_express']['pickup_pin']?.toString() : null) ??
            (json['latestGrabExpress'] is Map ? json['latestGrabExpress']['pickup_pin']?.toString() : null),
        pgQrString: json['pg_qr_string']?.toString() ??
            json['qr_string']?.toString() ??
            json['qr_code']?.toString(),
        pgExpiredQr: json['pg_expired_qr'] != null
            ? DateTime.tryParse(json['pg_expired_qr']?.toString() ?? '')
            : (json['expired_time'] != null
                ? DateTime.tryParse(json['expired_time']?.toString() ?? '')
                : null),
        voucherId: _parseInt(json['voucher_id']) ??
            _parseInt(json['user_voucher_id']),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                DateTime.tryParse(json['date']?.toString() ?? '') ??
                DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
            : null,
        items: json['details'] != null && json['details'] is List
            ? (json['details'] as List)
                .map((item) =>
                    OrderDetail.fromJson(item as Map<String, dynamic>))
                .toList()
            : json['items'] != null && json['items'] is List
                ? (json['items'] as List)
                    .map((item) =>
                        OrderDetail.fromJson(item as Map<String, dynamic>))
                    .toList()
                : [],
        estimatedPrepTime: _parseInt(json['estimated_prep_time']),
        estimatedDeliveryDuration: _parseInt(json['estimated_delivery_duration']),
        estimatedTotalTime: _parseInt(json['estimated_total_time']),
        estimatedReadyAt: json['estimated_ready_at'] != null
            ? DateTime.tryParse(json['estimated_ready_at'].toString())
            : null,
        estimatedDeliveryAt: json['estimated_delivery_at'] != null
            ? DateTime.tryParse(json['estimated_delivery_at'].toString())
            : null,
        targetTimeFormatted: json['target_time_formatted']?.toString(),
        rangeText: json['range_text']?.toString(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'user_id': userId,
      'branch_id': branchId,
      'branch_name': branchName,
      if (branchLat != null) 'branch_latitude': branchLat,
      if (branchLong != null) 'branch_longitude': branchLong,
      'delivery_type': deliveryType,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliverLat != null) 'deliver_lat': deliverLat,
      if (deliverLong != null) 'deliver_long': deliverLong,
      'delivery_fee': deliveryFee,
      'total_price': totalPrice,
      'discount': discount,
      'final_price': finalPrice,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'point': point,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      if (voucherId != null) 'voucher_id': voucherId,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      if (estimatedPrepTime != null) 'estimated_prep_time': estimatedPrepTime,
      if (estimatedDeliveryDuration != null) 'estimated_delivery_duration': estimatedDeliveryDuration,
      if (estimatedTotalTime != null) 'estimated_total_time': estimatedTotalTime,
      if (estimatedReadyAt != null) 'estimated_ready_at': estimatedReadyAt!.toIso8601String(),
      if (estimatedDeliveryAt != null) 'estimated_delivery_at': estimatedDeliveryAt!.toIso8601String(),
      if (targetTimeFormatted != null) 'target_time_formatted': targetTimeFormatted,
      if (rangeText != null) 'range_text': rangeText,
    };
  }

  /// Formatted target ready/arrival time (e.g. "12:45" or "12:45 WIB")
  String get displayTargetTime {
    if (targetTimeFormatted != null && targetTimeFormatted!.isNotEmpty) {
      if (targetTimeFormatted!.startsWith('00:') && createdAt.toLocal().hour != 0) {
        final totalMins = estimatedTotalTime ?? (estimatedPrepTime ?? 20);
        final fallback = createdAt.toLocal().add(Duration(minutes: totalMins));
        final hh = fallback.hour.toString().padLeft(2, '0');
        final mm = fallback.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
      return targetTimeFormatted!;
    }
    final target = estimatedDeliveryAt ?? estimatedReadyAt;
    if (target != null) {
      final localTarget = target.toLocal();
      if (localTarget.hour == 0 && createdAt.toLocal().hour != 0) {
        final totalMins = estimatedTotalTime ?? (estimatedPrepTime ?? 20);
        final fallback = createdAt.toLocal().add(Duration(minutes: totalMins));
        final hh = fallback.hour.toString().padLeft(2, '0');
        final mm = fallback.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
      final hour = localTarget.hour.toString().padLeft(2, '0');
      final minute = localTarget.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    // Fallback based on creation time + default 25/35 mins
    final fallbackTarget = createdAt.toLocal().add(Duration(minutes: isDelivery ? 35 : 20));
    final hour = fallbackTarget.hour.toString().padLeft(2, '0');
    final minute = fallbackTarget.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formatted finish / pickup time for completed or ready orders (e.g. "16:01")
  String get displayReadyTime {
    final refTime = updatedAt ?? estimatedReadyAt ?? createdAt;
    final local = refTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formatted range duration with language support (e.g. "25 - 35 Menit" or "25 - 35 Mins")
  String displayRangeTextLang([AppLanguage lang = AppLanguage.indonesia]) {
    final isEn = lang == AppLanguage.english;
    final unit = isEn ? 'Mins' : 'Menit';
    if (rangeText != null && rangeText!.isNotEmpty) {
      if (isEn) {
        return rangeText!
            .replaceAll('Menit', 'Mins')
            .replaceAll('menit', 'mins');
      }
      return rangeText!;
    }
    final total = estimatedTotalTime ?? (isDelivery ? 35 : 20);
    final min = (total - 5).clamp(10, 180);
    final max = total + 5;
    return '$min - $max $unit';
  }

  /// Formatted range duration (e.g. "25 - 35 Menit")
  String get displayRangeText => displayRangeTextLang(AppLanguage.indonesia);

  // ── Status boolean getters ────────────────

  bool get isExpiredStatus =>
      status == OrderStatus.expired || paymentStatus == 'expired';

  bool get isExpiredByTime {
    if (status != OrderStatus.pendingPayment && paymentStatus != 'pending') {
      return false;
    }
    final methodUpper = paymentMethod.toUpperCase();
    final isQris = methodUpper.contains('QRIS') || methodUpper.contains('QR');
    final expiryMinutes = isQris ? 15 : 30;
    return DateTime.now().difference(createdAt).inMinutes >= expiryMinutes;
  }
  bool get isExpired => isExpiredStatus || isExpiredByTime;

  bool get isPendingPayment => status == OrderStatus.pendingPayment && !isExpired;
  bool get isPaymentFailed  => status == OrderStatus.paymentFailed;
  bool get isPaid           => status == OrderStatus.paid;
  bool get isConfirmed      => status == OrderStatus.confirmed;
  bool get isAccepted       => status == OrderStatus.confirmed;
  bool get isRejected       => status == OrderStatus.rejected;
  bool get isPreparing      => status == OrderStatus.preparing;
  bool get isReady          => status == OrderStatus.ready;
  bool get isReadyForPickup => status == OrderStatus.readyForPickup;
  bool get isOutForDelivery => status == OrderStatus.outForDelivery;
  bool get isCompleted      => status == OrderStatus.completed;
  bool get isCancelled      => status == OrderStatus.cancelled || isExpired;

  /// Backward compat: old code used isPending for "waiting" orders
  bool get isPending => isPendingPayment || isPaid;

  /// True while the kitchen / delivery is still processing
  bool get isActive => OrderStatus.isActiveStatus(status) && !isExpired;

  /// True once the order is in a terminal state
  bool get isTerminal =>
      OrderStatus.isTerminalStatus(status, orderType: deliveryType) ||
      isExpired ||
      !isActive;

  // ── Payment status getters ────────────────

  bool get isPaymentPaid    => paymentStatus == 'paid';
  bool get isPaymentPending => paymentStatus == 'pending';
  String? get cancellationReason => cancelReason;

  // ── Delivery-type helpers ─────────────────

  bool get isDineIn   => deliveryType.contains('dine');
  bool get isTakeAway => deliveryType.contains('take') || deliveryType == 'pickup';
  bool get isDelivery => deliveryType == 'delivery';

  /// True while the courier is on the way (for Delivery orders)
  bool get isDelivering => isDelivery && isOutForDelivery;

  String get orderType => deliveryType;

  // ── UI helpers ────────────────────────────

  Color get statusColor => OrderStatus.color(status, orderType: deliveryType);

  IconData get statusIcon => OrderStatus.icon(status, orderType: deliveryType);

  String statusDisplayFor([AppLanguage lang = AppLanguage.indonesia]) =>
      OrderStatus.label(status, orderType: deliveryType, lang: lang);

  String get statusDisplay => statusDisplayFor(AppLanguage.indonesia);

  /// Localized order type string ("Di Tempat", "Bawa Pulang", "Pesan Antar")
  String orderTypeDisplayFor([AppLanguage lang = AppLanguage.indonesia]) {
    final isEn = lang == AppLanguage.english;
    if (isDelivery) {
      return isEn ? 'Delivery' : 'Pesan Antar';
    } else if (isTakeAway) {
      return isEn ? 'Take Away' : 'Bawa Pulang';
    } else {
      return isEn ? 'Dine In' : 'Di Tempat';
    }
  }

  String get orderTypeDisplay => orderTypeDisplayFor(AppLanguage.indonesia);

  String paymentStatusDisplayFor([AppLanguage lang = AppLanguage.indonesia]) {
    final isEn = lang == AppLanguage.english;
    if (isExpired) return isEn ? 'Expired' : 'Kedaluwarsa';

    switch (paymentStatus.toLowerCase()) {
      case 'pending': return isEn ? 'Unpaid' : 'Menunggu Pembayaran';
      case 'paid':    return isEn ? 'Paid' : 'Lunas';
      case 'failed':  return isEn ? 'Payment Failed' : 'Pembayaran Gagal';
      default:        return paymentStatus;
    }
  }

  String get paymentStatusDisplay => paymentStatusDisplayFor(AppLanguage.indonesia);

  // ── Counts / amounts ─────────────────────

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      finalPrice > 0
          ? finalPrice
          : (totalPrice + taxAmount + serviceAmount - discount);

  double get subtotal {
    if (items.isNotEmpty) {
      final t = items.fold(0.0, (s, i) => s + (i.price * i.quantity));
      if (t > 0) return t;
    }
    if (taxAmount > 0 && finalPrice > 0) {
      return (finalPrice - taxAmount - serviceAmount + discount - deliveryFee)
          .clamp(0.0, double.infinity);
    }
    return (totalPrice - deliveryFee).clamp(0.0, double.infinity);
  }

  double get tax     => taxAmount     > 0 ? taxAmount     : subtotal * 0.10;
  double get service => serviceAmount > 0 ? serviceAmount : (subtotal + tax) * 0.05;

  double get totalPromoSavings => items.fold(
      0.0,
      (sum, item) =>
          sum +
          (item.hasPromo && item.originalPrice != null
              ? (item.originalPrice! - item.price) * item.quantity
              : 0.0));

  bool get hasAnyPromoItems => items.any((item) => item.hasPromo);

  // ── Formatted strings ─────────────────────

  String get formattedDate {
    final local = createdAt.toLocal();
    final day = local.day;
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthName = months[local.month - 1];
    final year = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$day $monthName $year, $hh:$mm WIB';
  }

  String get formattedTotalAmount => totalAmount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.');
}

// ─────────────────────────────────────────────
// OrderDetail
// ─────────────────────────────────────────────
class OrderDetail {
  final int id;
  final int orderId;
  final int menuId;
  final int? menuTemplateId;
  final String menuName;
  final int quantity;
  final double price;
  final double? originalPrice;
  final bool hasPromo;
  final int? discountPercentage;
  final double savedAmount;
  final String? notes;
  final String? menuImage;

  OrderDetail({
    required this.id,
    required this.orderId,
    required this.menuId,
    this.menuTemplateId,
    required this.menuName,
    required this.quantity,
    required this.price,
    this.originalPrice,
    this.hasPromo = false,
    this.discountPercentage,
    this.savedAmount = 0.0,
    this.notes,
    this.menuImage,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    int parsedOrderId = 0;
    if (json['order_id'] != null) {
      parsedOrderId = _parseInt(json['order_id']) ?? 0;
    }

    final rawName = json['menu_name']?.toString() ??
        json['product_name']?.toString() ??
        json['name']?.toString() ??
        json['menu']?['name']?.toString() ??
        json['branch_menu_item']?['menu_template']?['name']?.toString() ??
        json['menu_template']?['name']?.toString() ??
        (json['menu_code'] != null && json['menu_code'].toString().isNotEmpty
            ? 'Item (${json['menu_code']})'
            : '');

    String? rawImage;
    if (json.containsKey('menu_image')) {
      final img = json['menu_image']?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    } else if (json.containsKey('product_image')) {
      final img = json['product_image']?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    } else if (json.containsKey('photo')) {
      final img = json['photo']?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    } else if (json.containsKey('image')) {
      final img = json['image']?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    } else if (json['branch_menu_item']?['menu_template'] != null) {
      final mt = json['branch_menu_item']['menu_template'];
      final img = (mt['photo'] ?? mt['image'])?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    } else if (json['menu_template'] != null) {
      final mt = json['menu_template'];
      final img = (mt['photo'] ?? mt['image'])?.toString().trim();
      rawImage = (img != null && img.isNotEmpty) ? img : null;
    }

    final parsedQty = _parseInt(json['qty']) ?? _parseInt(json['quantity']) ?? 0;
    final double parsedPrice = _parseDouble(json['price']) ??
        (_parseDouble(json['total']) != null
            ? (_parseDouble(json['total'])! /
                (parsedQty > 0 ? parsedQty : 1))
            : 0.0);

    final double? parsedOriginalPrice = _parseDouble(json['original_price']) ??
        _parseDouble(json['base_price']) ??
        _parseDouble(json['menu']?['base_price']) ??
        _parseDouble(json['branch_menu_item']?['menu_template']?['base_price']);

    final bool parsedHasPromo = json['has_promo'] == true ||
        (parsedOriginalPrice != null && parsedOriginalPrice > (parsedPrice + 1));

    final int? parsedDiscount = _parseInt(json['discount_percentage']) ??
        (parsedHasPromo && parsedOriginalPrice != null && parsedOriginalPrice > 0
            ? (((parsedOriginalPrice - parsedPrice) / parsedOriginalPrice) * 100).round()
            : null);

    final double parsedSavedAmount = _parseDouble(json['saved_amount']) ??
        (parsedHasPromo && parsedOriginalPrice != null
            ? (parsedOriginalPrice - parsedPrice) * parsedQty
            : 0.0);

    return OrderDetail(
      id: _parseInt(json['id']) ?? 0,
      orderId: parsedOrderId,
      menuId: _parseInt(json['menu_id']) ??
          _parseInt(json['branch_menu_item_id']) ??
          0,
      menuTemplateId: _parseInt(json['menu_template_id']) ??
          _parseInt(json['branch_menu_item']?['menu_template_id']) ??
          _parseInt(json['menu_template']?['id']),
      menuName: rawName.isNotEmpty ? rawName : 'Item Pesanan',
      quantity: parsedQty,
      price: parsedPrice,
      originalPrice: parsedOriginalPrice,
      hasPromo: parsedHasPromo,
      discountPercentage: parsedDiscount,
      savedAmount: parsedSavedAmount,
      notes: json['notes']?.toString(),
      menuImage: rawImage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'menu_id': menuId,
        if (menuTemplateId != null) 'menu_template_id': menuTemplateId,
        'menu_name': menuName,
        'quantity': quantity,
        'price': price,
        if (originalPrice != null) 'original_price': originalPrice,
        'has_promo': hasPromo,
        if (discountPercentage != null) 'discount_percentage': discountPercentage,
        'saved_amount': savedAmount,
        if (notes != null) 'notes': notes,
        if (menuImage != null) 'menu_image': menuImage,
      };

  int get targetMenuId =>
      (menuTemplateId != null && menuTemplateId! > 0) ? menuTemplateId! : menuId;

  double get subtotal => price * quantity;

  String get productName  => menuName;
  String? get productImage => menuImage;

  String get formattedPrice => price
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.');

  String? get formattedOriginalPrice => originalPrice
      ?.toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.');
}

// ─────────────────────────────────────────────
// CreateOrderRequest / OrderDetailRequest
// ─────────────────────────────────────────────
class CreateOrderRequest {
  final String date;
  final double grandTotal;
  final double finalTotal;
  final double discount;
  final double tax;
  final double service;
  final String orderType;   // "dine_in" | "takeaway" | "delivery"
  final String payment;     // "QRIS" | "CASH"
  final int userId;
  final int branchId;
  final String? tableNumber;
  final int? userVoucherId;
  final List<OrderDetailRequest> details;
  final String? notes;
  final String? deliverAddress;
  final double? deliverLat;
  final double? deliverLong;
  final int? grabDurationMinutes;
  final double? deliveryFee;

  CreateOrderRequest({
    required this.date,
    required this.grandTotal,
    required this.finalTotal,
    required this.discount,
    required this.tax,
    required this.service,
    required this.orderType,
    required this.payment,
    required this.userId,
    required this.branchId,
    this.tableNumber,
    this.userVoucherId,
    required this.details,
    this.notes,
    this.deliverAddress,
    this.deliverLat,
    this.deliverLong,
    this.grabDurationMinutes,
    this.deliveryFee,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'grand_total': grandTotal,
        'final_total': finalTotal,
        'discount': discount,
        'tax': tax,
        'service': service,
        'order_type': orderType,
        'payment': payment,
        'user_id': userId,
        'branch_id': branchId,
        // Always send table_number — backend now nullable, but still expected.
        // Take away / delivery orders use '0' as a sentinel value.
        'table_number': tableNumber ?? '0',
        if (userVoucherId != null) 'user_voucher_id': userVoucherId,
        'details': details.map((d) => d.toJson()).toList(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (deliverAddress != null) 'deliver_address': deliverAddress,
        if (deliverLat != null) 'deliver_lat': deliverLat,
        if (deliverLong != null) 'deliver_long': deliverLong,
        if (grabDurationMinutes != null) 'grab_duration_minutes': grabDurationMinutes,
        if (deliveryFee != null) 'delivery_fee': deliveryFee,
      };
}

class OrderDetailRequest {
  final int? menuId;
  final String? menuCode;
  final String? templateCode;
  final int? branchMenuItemId;
  final String? notes;
  final int qty;
  final double total;

  OrderDetailRequest({
    this.menuId,
    this.menuCode,
    this.templateCode,
    this.branchMenuItemId,
    this.notes,
    required this.qty,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        if (menuId != null && menuId! > 0) 'menu_id': menuId,
        if (branchMenuItemId != null && branchMenuItemId! > 0)
          'branch_menu_item_id': branchMenuItemId,
        if (menuCode != null && menuCode!.isNotEmpty) 'menu_code': menuCode,
        if (templateCode != null && templateCode!.isNotEmpty)
          'menu_template_id': templateCode,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'qty': qty,
        'total': total,
      };
}

// ─────────────────────────────────────────────
// Payment helpers
// ─────────────────────────────────────────────
class PaymentInfo {
  final String transactionId;
  final String? vaNumber;
  final String? qrString;
  final double amount;
  final DateTime expiredDate;

  PaymentInfo({
    required this.transactionId,
    this.vaNumber,
    this.qrString,
    required this.amount,
    required this.expiredDate,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
        transactionId: json['transaction_id']?.toString() ?? '',
        vaNumber: json['va_number']?.toString(),
        qrString: json['qr_string']?.toString(),
        amount: _parseDouble(json['amount']) ?? 0.0,
        expiredDate:
            DateTime.tryParse(json['expired_date']?.toString() ?? '') ??
                DateTime.now());
}

class CreateOrderResponse {
  final String orderId;
  final String? qrString;
  final int? estimatedTotalTime;
  final String? targetTimeFormatted;
  final String? rangeText;

  CreateOrderResponse({
    required this.orderId,
    this.qrString,
    this.estimatedTotalTime,
    this.targetTimeFormatted,
    this.rangeText,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return CreateOrderResponse(
      orderId: data['order_id']?.toString() ?? '',
      qrString: data['qr_string']?.toString(),
      estimatedTotalTime: _parseInt(data['estimated_total_time']),
      targetTimeFormatted: data['target_time_formatted']?.toString(),
      rangeText: data['range_text']?.toString(),
    );
  }
}
