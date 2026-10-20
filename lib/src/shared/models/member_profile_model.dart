double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class UserLevel {
  final int? id;
  final String name;
  final String? icon;
  final String? color;
  final double minPurchase;
  final int minPoints;

  UserLevel({
    this.id,
    required this.name,
    this.icon,
    this.color,
    this.minPurchase = 0,
    this.minPoints = 0,
  });

  factory UserLevel.fromJson(Map<String, dynamic> json) {
    return UserLevel(
      id: json['id'] == null ? null : _parseInt(json['id']),
      name: json['name']?.toString() ?? 'Bronze',
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      minPurchase: _parseDouble(json['min_purchase']),
      minPoints: _parseInt(json['min_points']));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'min_purchase': minPurchase,
      'min_points': minPoints,
    };
  }
}

class MemberLevelProgress {
  final UserLevel currentLevel;
  final UserLevel? nextLevel;
  final double totalSpent;
  final double percentage;
  final double remainingAmount;
  final List<UserLevel> levels;

  MemberLevelProgress({
    required this.currentLevel,
    this.nextLevel,
    required this.totalSpent,
    required this.percentage,
    required this.remainingAmount,
    required this.levels,
  });

  factory MemberLevelProgress.fromJson(Map<String, dynamic> json) {
    return MemberLevelProgress(
      currentLevel: json['current_level'] is Map
          ? UserLevel.fromJson(json['current_level'] as Map<String, dynamic>)
          : UserLevel(name: json['current_level']?.toString() ?? 'Bronze'),
      nextLevel: json['next_level'] is Map
          ? UserLevel.fromJson(json['next_level'] as Map<String, dynamic>)
          : null,
      totalSpent: _parseDouble(json['total_spent']),
      percentage: _parseDouble(json['percentage']),
      remainingAmount: _parseDouble(json['remaining_amount']),
      levels: (json['levels'] as List?)
              ?.whereType<Map>()
              .map((level) => UserLevel.fromJson(level.cast<String, dynamic>()))
              .toList() ??
          const []);
  }
}

class MemberProfileUser {
  final int id;
  final String name;
  final String phoneNumber;
  final String email;
  final String memberCode;
  final int point;
  final UserLevel userLevel;
  final int totalOrders;
  final double totalSpent;
  final MemberLevelProgress? levelProgress;

  MemberProfileUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.memberCode,
    required this.point,
    required this.userLevel,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.levelProgress,
  });

  factory MemberProfileUser.fromJson(Map<String, dynamic> json) {
    // Handle user_level - can be String or Map
    UserLevel userLevel;
    if (json['user_level'] is String) {
      // Backend returns simple string like "Bronze"
      userLevel = UserLevel(name: json['user_level'] as String);
    } else if (json['user_level'] is Map) {
      // Backend returns full object with icon/color
      userLevel = UserLevel.fromJson(json['user_level'] as Map<String, dynamic>);
    } else if (json['level'] is Map) {
      userLevel = UserLevel.fromJson(json['level'] as Map<String, dynamic>);
    } else {
      // Fallback
      userLevel = UserLevel(name: 'Bronze');
    }
    
    return MemberProfileUser(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      memberCode: json['member_code']?.toString() ?? '',
      point: _parseInt(json['point']),
      userLevel: userLevel,
      totalOrders: _parseInt(json['total_orders']),
      totalSpent: _parseDouble(json['total_spent']),
      levelProgress: json['level_progress'] is Map
          ? MemberLevelProgress.fromJson(
              json['level_progress'] as Map<String, dynamic>)
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'member_code': memberCode,
      'point': point,
      'user_level': userLevel.toJson(),
      'total_orders': totalOrders,
      'total_spent': totalSpent,
    };
  }
}

class MemberProfile {
  final MemberProfileUser user;
  final String qrData;
  final MemberLevelProgress? levelProgress;

  MemberProfile({
    required this.user,
    required this.qrData,
    this.levelProgress,
  });

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    final user = MemberProfileUser.fromJson(json['user'] as Map<String, dynamic>);
    return MemberProfile(
      user: user,
      qrData: json['qr_data']?.toString() ?? '',
      levelProgress: json['level_progress'] is Map
          ? MemberLevelProgress.fromJson(
              json['level_progress'] as Map<String, dynamic>)
          : user.levelProgress);
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'qr_data': qrData,
    };
  }
}
