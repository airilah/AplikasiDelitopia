import 'dart:convert';
import 'package:flutter/foundation.dart';

class MenuReviewItem {
  final int id;
  final int? userId;
  final String userName;
  final String? userPhoto;
  final int rating;
  final String? comment;
  final List<String> tags;
  final DateTime? createdAt;

  MenuReviewItem({
    required this.id,
    this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    this.comment,
    this.tags = const [],
    this.createdAt,
  });

  factory MenuReviewItem.fromJson(Map<String, dynamic> json) {
    String name = 'Pelanggan';
    String? photo;
    if (json['user'] is Map) {
      final userMap = json['user'] as Map;
      name = userMap['name']?.toString() ?? 'Pelanggan';
      photo = userMap['photo']?.toString();
    } else if (json['user_name'] != null) {
      name = json['user_name'].toString();
    }

    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String && (json['tags'] as String).trim().isNotEmpty) {
      final tagStr = (json['tags'] as String).trim();
      if (tagStr.startsWith('[')) {
        try {
          final decoded = jsonDecode(tagStr);
          if (decoded is List) {
            parsedTags = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      } else {
        parsedTags = tagStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    return MenuReviewItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? ''),
      userName: name,
      userPhoto: photo,
      rating: json['rating'] is int
          ? json['rating'] as int
          : int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      comment: json['comment']?.toString(),
      tags: parsedTags,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Masks user name preserving only first and last character of each word, e.g. "Budi Santoso" -> "B**i S*****o"
  String get maskedName {
    if (userName.trim().isEmpty) return 'P*******n';
    final parts = userName.trim().split(RegExp(r'\s+'));
    return parts.map((part) {
      if (part.length <= 2) return part;
      final first = part[0];
      final last = part[part.length - 1];
      final stars = '*' * (part.length - 2);
      return '$first$stars$last';
    }).join(' ');
  }

  String formattedDate(bool isIndo) {
    if (createdAt == null) return '';
    final d = createdAt!.toLocal();
    final monthsId = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final mList = isIndo ? monthsId : monthsEn;
    return '${d.day} ${mList[d.month - 1]} ${d.year}';
  }
}

class MenuReviewsResponse {
  final List<MenuReviewItem> reviews;
  final double averageRating;
  final int totalReviews;
  final int totalWithComment;
  final Map<int, int>? _ratingBreakdown;

  Map<int, int> get ratingBreakdown =>
      _ratingBreakdown ?? const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  MenuReviewsResponse({
    required this.reviews,
    required this.averageRating,
    required this.totalReviews,
    required this.totalWithComment,
    Map<int, int>? ratingBreakdown,
  }) : _ratingBreakdown = ratingBreakdown;

  factory MenuReviewsResponse.fromJson(Map<String, dynamic> json) {
    List<MenuReviewItem> list = [];
    final data = json['data'];
    List rawList = [];
    if (data is Map && data['data'] is List) {
      rawList = data['data'] as List;
    } else if (data is List) {
      rawList = data;
    }

    for (final item in rawList) {
      try {
        if (item is Map) {
          list.add(MenuReviewItem.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        debugPrint('⚠️ [MenuReviewItem] Parsing error on item: $e');
      }
    }

    double avg = 5.0;
    int total = list.length;
    int withComment = 0;
    Map<int, int> breakdown = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    if (json['summary'] is Map) {
      final s = json['summary'] as Map;
      avg = (s['average_rating'] as num?)?.toDouble() ?? 5.0;
      total = (s['total_reviews'] as num?)?.toInt() ?? list.length;
      withComment = (s['total_with_comment'] as num?)?.toInt() ?? 0;

      if (s['rating_breakdown'] is Map) {
        final b = s['rating_breakdown'] as Map;
        b.forEach((k, v) {
          final star = int.tryParse(k.toString());
          if (star != null) {
            breakdown[star] = (v as num?)?.toInt() ?? 0;
          }
        });
      }
    }

    return MenuReviewsResponse(
      reviews: list,
      averageRating: avg,
      totalReviews: total,
      totalWithComment: withComment,
      ratingBreakdown: breakdown,
    );
  }
}

