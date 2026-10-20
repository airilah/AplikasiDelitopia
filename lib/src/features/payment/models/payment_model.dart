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

class PaymentChannel {
  final int id;
  final String name;
  final String type; // 'gateway' or 'manual'
  final List<PaymentMethod>? methods;

  PaymentChannel({
    required this.id,
    required this.name,
    required this.type,
    this.methods,
  });

  factory PaymentChannel.fromJson(Map<String, dynamic> json) {
    return PaymentChannel(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      methods: json['methods'] != null
          ? (json['methods'] as List)
              .map((m) => PaymentMethod.fromJson(m as Map<String, dynamic>))
              .toList()
          : null);
  }
}

class PaymentMethod {
  final String code;
  final String name;
  final double fee;

  PaymentMethod({
    required this.code,
    required this.name,
    this.fee = 0,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fee: _parseDouble(json['fee']) ?? 0.0);
  }
}

class CreatePaymentRequest {
  final String orderId;
  final double amount;
  final String paymentMethod;
  final String customerName;
  final String customerEmail;
  final String customerPhone;

  CreatePaymentRequest({
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
    };
  }
}

class PaymentResponse {
  final String transactionId;
  final String? vaNumber;
  final String? paymentUrl;
  final String? qrString;
  final DateTime expiredAt;

  PaymentResponse({
    required this.transactionId,
    this.vaNumber,
    this.paymentUrl,
    this.qrString,
    required this.expiredAt,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      transactionId: json['transaction_id']?.toString() ?? '',
      vaNumber: json['va_number']?.toString(),
      paymentUrl: json['payment_url']?.toString(),
      qrString: json['qr_string']?.toString(),
      expiredAt: DateTime.tryParse(json['expired_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 24)));
  }
}

class PaymentInquiry {
  final String orderId;
  final String paymentMethod;
  final String paymentStatus; // 'paid', 'pending', 'failed', 'expired'
  final int amount;
  final String? qrString;
  final DateTime? expiredTime;
  final DateTime? paidAt;

  PaymentInquiry({
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amount,
    this.qrString,
    this.expiredTime,
    this.paidAt,
  });

  factory PaymentInquiry.fromJson(Map<String, dynamic> json) {
    String? resolvedQr = json['qr_string']?.toString() ??
        json['pg_qr_string']?.toString() ??
        json['qr_code']?.toString();
    if (resolvedQr == null && json['qr_response'] is Map) {
      resolvedQr = json['qr_response']['qr_string']?.toString();
    }
    if (resolvedQr == null && json['payment_details'] is Map) {
      resolvedQr = json['payment_details']['qr_string']?.toString() ??
          json['payment_details']['qr_code']?.toString();
    }

    final expiredStr = json['expired_time']?.toString() ??
        json['pg_expired_qr']?.toString() ??
        (json['payment_details'] is Map
            ? json['payment_details']['expired_time']?.toString()
            : null);

    return PaymentInquiry(
      orderId: json['order_id']?.toString() ??
          json['transaction_id']?.toString() ??
          '',
      paymentMethod: json['payment_method']?.toString() ?? 'QRIS',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      amount: json['amount'] is int
          ? json['amount']
          : int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      qrString: resolvedQr,
      expiredTime: expiredStr != null ? DateTime.tryParse(expiredStr) : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at']?.toString() ?? '')
          : null,
    );
  }

  // Backwards compatibility
  String get transactionId => orderId;

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isPending => paymentStatus.toLowerCase() == 'pending';
  bool get isFailed => paymentStatus.toLowerCase() == 'failed';
  bool get isExpired => paymentStatus.toLowerCase() == 'expired';
  
  String get formattedAmount {
    return 'Rp ${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
}
