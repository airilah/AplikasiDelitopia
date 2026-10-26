import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model representing an active dine-in table session acquired from scanning a QR code
class TableSession {
  final int branchId;
  final int? brandId;
  final String tableNumber;
  final String? zone;
  final String? branchName;
  final String? brandName;
  final bool isLockedFromQr;

  const TableSession({
    required this.branchId,
    this.brandId,
    required this.tableNumber,
    this.zone,
    this.branchName,
    this.brandName,
    this.isLockedFromQr = true,
  });

  TableSession copyWith({
    int? branchId,
    int? brandId,
    String? tableNumber,
    String? zone,
    String? branchName,
    String? brandName,
    bool? isLockedFromQr,
  }) {
    return TableSession(
      branchId: branchId ?? this.branchId,
      brandId: brandId ?? this.brandId,
      tableNumber: tableNumber ?? this.tableNumber,
      zone: zone ?? this.zone,
      branchName: branchName ?? this.branchName,
      brandName: brandName ?? this.brandName,
      isLockedFromQr: isLockedFromQr ?? this.isLockedFromQr,
    );
  }
}

/// Global StateProvider for currently active table session
final tableSessionProvider = StateProvider<TableSession?>((ref) => null);

/// Smart parser that decodes any table barcode / QR format (Universal Link, Base64 JSON, raw JSON, etc.)
class TableQRParser {
  TableQRParser._();

  static TableSession? parse(String rawCode) {
    final text = rawCode.trim();
    if (text.isEmpty) return null;

    // 1. Check if it's a URL (http/https/delitopia scheme)
    if (text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('delitopia://')) {
      try {
        final uri = Uri.parse(text);
        final qp = uri.queryParameters;

        // Check for table & branch query params
        final table = qp['table'] ??
            qp['table_number'] ??
            qp['tableNumber'] ??
            qp['meja'];
        final branchStr =
            qp['branchId'] ?? qp['branch_id'] ?? qp['branch'] ?? qp['cabang'];
        final brandStr = qp['brandId'] ?? qp['brand_id'] ?? qp['brand'];
        final zone = qp['zone'] ?? qp['area'] ?? qp['lantai'];

        if (table != null && branchStr != null) {
          final branchId = int.tryParse(branchStr);
          final brandId = brandStr != null ? int.tryParse(brandStr) : null;
          if (branchId != null) {
            return TableSession(
              branchId: branchId,
              brandId: brandId,
              tableNumber: table.trim(),
              zone: zone?.trim(),
              isLockedFromQr: true,
            );
          }
        }

        // Also check path segments, e.g. /dine-in/122/08 or /table/122/08
        final segments = uri.pathSegments;
        if (segments.length >= 3 &&
            (segments[0] == 'dine-in' || segments[0] == 'table')) {
          final branchId = int.tryParse(segments[1]);
          final tableNum = segments[2];
          if (branchId != null && tableNum.isNotEmpty) {
            return TableSession(
              branchId: branchId,
              tableNumber: tableNum.trim(),
              isLockedFromQr: true,
            );
          }
        }
      } catch (_) {}
    }

    // 2. Check if it's a Base64-encoded string (Delitopia QRController output)
    try {
      final decodedBytes = base64Decode(text);
      final decodedJsonStr = utf8.decode(decodedBytes);
      final dynamic decoded = jsonDecode(decodedJsonStr);
      if (decoded is Map<String, dynamic>) {
        final branchId = (decoded['branch'] as num?)?.toInt() ??
            (decoded['branch_id'] as num?)?.toInt();
        final brandId = (decoded['brand'] as num?)?.toInt() ??
            (decoded['brand_id'] as num?)?.toInt();
        final tableNum = decoded['table_number']?.toString() ??
            decoded['table']?.toString();
        final zone = decoded['zone']?.toString();

        if (branchId != null && tableNum != null && tableNum.isNotEmpty) {
          return TableSession(
            branchId: branchId,
            brandId: brandId,
            tableNumber: tableNum.trim(),
            zone: zone,
            isLockedFromQr: true,
          );
        }
      }
    } catch (_) {}

    // 3. Check if it's raw JSON string
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          final branchId = (decoded['branch'] as num?)?.toInt() ??
              (decoded['branch_id'] as num?)?.toInt();
          final brandId = (decoded['brand'] as num?)?.toInt() ??
              (decoded['brand_id'] as num?)?.toInt();
          final tableNum = decoded['table_number']?.toString() ??
              decoded['table']?.toString();
          final zone = decoded['zone']?.toString();

          if (branchId != null && tableNum != null && tableNum.isNotEmpty) {
            return TableSession(
              branchId: branchId,
              brandId: brandId,
              tableNumber: tableNum.trim(),
              zone: zone,
              isLockedFromQr: true,
            );
          }
        }
      } catch (_) {}
    }

    // 4. Custom formatted token: "DELITOPIA:122:08" or "TABLE:122:08"
    if (text.toUpperCase().startsWith('DELITOPIA:') ||
        text.toUpperCase().startsWith('TABLE:')) {
      final parts = text.split(':');
      if (parts.length >= 3) {
        final branchId = int.tryParse(parts[1]);
        final tableNum = parts[2];
        if (branchId != null && tableNum.isNotEmpty) {
          return TableSession(
            branchId: branchId,
            tableNumber: tableNum.trim(),
            isLockedFromQr: true,
          );
        }
      }
    }

    return null;
  }
}
