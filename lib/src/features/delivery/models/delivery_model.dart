import '../../../core/localization/app_language.dart';

// Safe parsing helpers
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

class GrabQuoteRequest {
  final String originAddress;
  final double originLatitude;
  final double originLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;

  const GrabQuoteRequest({
    required this.originAddress,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'origin_address': originAddress,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination_address': destinationAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
    };
  }
}

class GrabQuote {
  final double amount;
  final String currency;
  final int estimatedTimeline; // in minutes
  final String serviceType;
  final double distance; // in kilometers

  const GrabQuote({
    required this.amount,
    required this.currency,
    required this.estimatedTimeline,
    required this.serviceType,
    required this.distance,
  });

  factory GrabQuote.fromJson(Map<String, dynamic> json) {
    return GrabQuote(
      amount: _parseDouble(json['amount']) ?? 0.0,
      currency: json['currency']?.toString() ?? 'IDR',
      estimatedTimeline: _parseInt(json['estimated_timeline']) ?? 0,
      serviceType: json['service_type']?.toString() ?? 'Instant',
      distance: _parseDouble(json['distance']) ?? 0.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'estimated_timeline': estimatedTimeline,
      'service_type': serviceType,
      'distance': distance,
    };
  }

  // Helper getters
  String get formattedAmount {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.');
  }

  String get estimatedTimeDisplay {
    if (estimatedTimeline < 60) {
      return '$estimatedTimeline minutes';
    } else {
      final hours = estimatedTimeline ~/ 60;
      final mins = estimatedTimeline % 60;
      if (mins == 0) {
        return '$hours ${hours > 1 ? 'hours' : 'hour'}';
      }
      return '$hours ${hours > 1 ? 'hours' : 'hour'} $mins minutes';
    }
  }

  String get distanceDisplay {
    return '${distance.toStringAsFixed(1)} km';
  }
}

class DeliveryOrder {
  final String orderId;
  final String grabOrderId;
  final String status; // 'pending', 'accepted', 'picking_up', 'delivering', 'delivered', 'cancelled'
  final GrabQuote quote;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final double? currentLatitude;
  final double? currentLongitude;

  const DeliveryOrder({
    required this.orderId,
    required this.grabOrderId,
    required this.status,
    required this.quote,
    required this.createdAt,
    this.deliveredAt,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.currentLatitude,
    this.currentLongitude,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      orderId: json['order_id']?.toString() ?? '',
      grabOrderId: json['grab_order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      quote: GrabQuote.fromJson(json['quote'] as Map<String, dynamic>),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.tryParse(json['delivered_at']?.toString() ?? '')
          : null,
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
      currentLatitude: _parseDouble(json['current_latitude']),
      currentLongitude: _parseDouble(json['current_longitude']));
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'grab_order_id': grabOrderId,
      'status': status,
      'quote': quote.toJson(),
      'created_at': createdAt.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (driverName != null) 'driver_name': driverName,
      if (driverPhone != null) 'driver_phone': driverPhone,
      if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
      if (currentLatitude != null) 'current_latitude': currentLatitude,
      if (currentLongitude != null) 'current_longitude': currentLongitude,
    };
  }

  // Status helpers
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isPickingUp => status == 'picking_up';
  bool get isDelivering => status == 'delivering';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isPending || isAccepted || isPickingUp || isDelivering;

  String statusDisplayFor([AppLanguage lang = AppLanguage.indonesia]) {
    final isIndo = lang == AppLanguage.indonesia;
    switch (status) {
      case 'pending':
        return isIndo ? 'Mencari Driver' : 'Finding Driver';
      case 'accepted':
        return isIndo ? 'Driver Diterima' : 'Driver Accepted';
      case 'picking_up':
        return isIndo ? 'Driver Menuju Restoran' : 'Driver Heading to Restaurant';
      case 'delivering':
        return isIndo ? 'Sedang Dikirim' : 'On Delivery';
      case 'delivered':
        return isIndo ? 'Terkirim' : 'Delivered';
      case 'cancelled':
        return isIndo ? 'Dibatalkan' : 'Cancelled';
      default:
        return status;
    }
  }

  String get statusDisplay => statusDisplayFor(AppLanguage.indonesia);

  bool get hasDriverInfo => driverName != null && driverPhone != null;
  bool get hasLocation => currentLatitude != null && currentLongitude != null;
}
