import '../../core/localization/app_language.dart';

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class NotificationModel {
  final int id;
  final int? userId;
  final String title;
  final String body;
  final String? image;
  final String type;
  final String? typeData;
  final String? titlePromo;
  final String? category;
  final String? actionUrl;
  final String? eventId;
  final String? templateKey;
  final bool isRead;
  final String? idOrder;
  final String? statusOrder;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    this.image,
    required this.type,
    this.typeData,
    this.titlePromo,
    this.category,
    this.actionUrl,
    this.eventId,
    this.templateKey,
    this.isRead = false,
    this.idOrder,
    this.statusOrder,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['user_id']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      image: json['image']?.toString(),
      type: json['type']?.toString() ?? '',
      typeData: json['type_data']?.toString(),
      titlePromo: json['title_promo']?.toString(),
      category: json['category']?.toString(),
      actionUrl: _cleanActionUrl(json['action_url']),
      eventId: json['event_id']?.toString(),
      templateKey: json['template_key']?.toString(),
      isRead: json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read'] == '1',
      idOrder: json['id_order']?.toString(),
      statusOrder: json['status_order']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'body': body,
      if (image != null) 'image': image,
      'type': type,
      if (typeData != null) 'type_data': typeData,
      if (titlePromo != null) 'title_promo': titlePromo,
      if (category != null) 'category': category,
      if (actionUrl != null) 'action_url': actionUrl,
      if (eventId != null) 'event_id': eventId,
      if (templateKey != null) 'template_key': templateKey,
      'is_read': isRead,
      if (idOrder != null) 'id_order': idOrder,
      if (statusOrder != null) 'status_order': statusOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isOrderNotification => type == 'order';
  bool get isPromoNotification => type == 'promo';
  bool get isVoucherNotification =>
      type == 'voucher' ||
      type.contains('voucher') ||
      (typeData != null && typeData!.toLowerCase().contains('voucher'));
  bool get isBroadcast => userId == null || userId == 0;

  String formattedTime([AppLanguage lang = AppLanguage.indonesia]) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final localTime = createdAt.toLocal();

    if (difference.inHours >= 24 || difference.inDays >= 1) {
      const idMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      const enMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = localTime.day.toString().padLeft(2, '0');
      final month = lang == AppLanguage.indonesia
          ? idMonths[localTime.month - 1]
          : enMonths[localTime.month - 1];
      final year = localTime.year;
      return '$day $month $year';
    }

    if (lang == AppLanguage.indonesia) {
      if (difference.inHours > 0) {
        return '${difference.inHours} jam lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} menit lalu';
      } else {
        return 'Baru saja';
      }
    } else {
      if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    }
  }

  String get timeAgo => formattedTime(AppLanguage.english);
}

String? _cleanActionUrl(dynamic value) {
  if (value == null) return null;
  var result = value.toString().trim();
  if (result.startsWith('"') && result.endsWith('"') && result.length > 1) {
    result = result.substring(1, result.length - 1).replaceAll(r'\/', '/');
  }
  return result.isEmpty ? null : result;
}
