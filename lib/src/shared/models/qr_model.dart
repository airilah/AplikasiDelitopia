class QRCode {
  final int id;
  final int brandId;
  final int branchId;
  final String tableNumber;
  final String qrCode;
  final String qrText;

  QRCode({
    required this.id,
    required this.brandId,
    required this.branchId,
    required this.tableNumber,
    required this.qrCode,
    required this.qrText,
  });

  factory QRCode.fromJson(Map<String, dynamic> json) {
    return QRCode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      brandId: (json['brand_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      tableNumber: json['table_number']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      qrText: json['qr_text']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'branch_id': branchId,
      'table_number': tableNumber,
      'qr_code': qrCode,
      'qr_text': qrText,
    };
  }
}

class QRDecoded {
  final int brand;
  final int branch;
  final String tableNumber;

  QRDecoded({
    required this.brand,
    required this.branch,
    required this.tableNumber,
  });

  factory QRDecoded.fromJson(Map<String, dynamic> json) {
    return QRDecoded(
      brand: (json['brand'] as num?)?.toInt() ?? 0,
      branch: (json['branch'] as num?)?.toInt() ?? 0,
      tableNumber: json['table_number']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'branch': branch,
      'table_number': tableNumber,
    };
  }
}
