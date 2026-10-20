class DeliveryQuote {
  final String serviceType;
  final double amount;
  final String currency;
  final int estimatedTimeMinutes;
  final String vehicleType;
  final String quoteId;
  final double? distanceInKm;

  DeliveryQuote({
    required this.serviceType,
    required this.amount,
    required this.currency,
    required this.estimatedTimeMinutes,
    required this.vehicleType,
    required this.quoteId,
    this.distanceInKm,
  });

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    double? parsedDistance;
    if (json['distance'] != null) {
      final rawDist = (json['distance'] as num).toDouble();
      parsedDistance = rawDist > 100 ? rawDist / 1000 : rawDist;
    } else if (json['route'] != null && json['route'] is Map && json['route']['distance'] != null) {
      final rawDist = (json['route']['distance'] as num).toDouble();
      parsedDistance = rawDist > 100 ? rawDist / 1000 : rawDist;
    }

    final serviceMap = json['service'] is Map ? (json['service'] as Map) : null;

    return DeliveryQuote(
      serviceType: serviceMap?['name']?.toString() ?? json['serviceType']?.toString() ?? 'Standard',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? 'IDR',
      estimatedTimeMinutes: (json['estimatedTimeline'] as num?)?.toInt() ?? (json['estimatedTimeMinutes'] as num?)?.toInt() ?? 30,
      vehicleType: serviceMap?['id']?.toString() ?? json['vehicleType']?.toString() ?? 'MOTORCYCLE',
      quoteId: json['quoteId']?.toString() ?? '',
      distanceInKm: parsedDistance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceType': serviceType,
      'amount': amount,
      'currency': currency,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'vehicleType': vehicleType,
      'quoteId': quoteId,
      if (distanceInKm != null) 'distanceInKm': distanceInKm,
    };
  }

  String get formattedAmount {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String get estimatedTime {
    if (estimatedTimeMinutes < 60) {
      return '$estimatedTimeMinutes mins';
    } else {
      final hours = estimatedTimeMinutes ~/ 60;
      final mins = estimatedTimeMinutes % 60;
      return mins > 0 ? '$hours hr $mins mins' : '$hours hr';
    }
  }
}

class DeliveryAddress {
  final double latitude;
  final double longitude;
  final String address;
  final String? landmark;
  final String? contactName;
  final String? contactPhone;

  DeliveryAddress({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.landmark,
    this.contactName,
    this.contactPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'coordinates': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'address': address,
      if (landmark != null) 'landmark': landmark,
      if (contactName != null) 'contactName': contactName,
      if (contactPhone != null) 'contactPhone': contactPhone,
    };
  }
}
