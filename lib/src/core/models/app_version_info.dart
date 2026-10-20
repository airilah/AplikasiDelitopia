/// App version information retrieved from backend
class AppVersionInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String minVersion;
  final int minBuildNumber;
  final bool forceUpdate;
  final String title;
  final String message;
  final String playStoreUrl;
  final String? appStoreUrl;
  final List<String> whatsNew;
  final bool? isUpdateAvailableFromServer;
  final AppMaintenanceInfo? maintenance;

  const AppVersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minVersion,
    required this.minBuildNumber,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.playStoreUrl,
    this.appStoreUrl,
    this.whatsNew = const [],
    this.isUpdateAvailableFromServer,
    this.maintenance,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    List<String> parseWhatsNew(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      } else if (value is String && value.isNotEmpty) {
        return [value];
      }
      return const [];
    }

    AppMaintenanceInfo? parseMaintenance(dynamic m) {
      if (m is Map<String, dynamic>) {
        return AppMaintenanceInfo.fromJson(m);
      } else if (json['is_maintenance'] == true || json['is_maintenance'] == 1) {
        return const AppMaintenanceInfo(isActive: true);
      }
      return null;
    }

    return AppVersionInfo(
      latestVersion: json['latest_version']?.toString() ?? '2.1.8',
      latestBuildNumber: (json['latest_build_number'] as num?)?.toInt() ?? 31,
      minVersion: json['min_version']?.toString() ?? '2.1.8',
      minBuildNumber: (json['min_build_number'] as num?)?.toInt() ?? 31,
      forceUpdate: json['is_force_update'] == true ||
          json['force_update'] == true ||
          json['force_update'] == 1,
      title: json['title']?.toString() ?? 'Pembaruan Aplikasi Tersedia',
      message: json['message']?.toString() ??
          'Versi terbaru Delitopia telah tersedia di Google Play Store. Silakan perbarui aplikasi untuk terus menikmati kemudahan pemesanan.',
      playStoreUrl: json['play_store_url']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      appStoreUrl: json['app_store_url']?.toString(),
      whatsNew: parseWhatsNew(json['whats_new']),
      isUpdateAvailableFromServer: json['is_update_available'] as bool?,
      maintenance: parseMaintenance(json['maintenance']),
    );
  }

  /// Compares two semver strings: returns negative if v1 < v2, 0 if equal, positive if v1 > v2
  static int compareVersions(String v1, String v2) {
    final cleanV1 = _cleanVersion(v1);
    final cleanV2 = _cleanVersion(v2);

    final parts1 = cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }
    return 0;
  }

  static String _cleanVersion(String v) {
    final withoutBuild = v.split('+')[0];
    return withoutBuild.replaceAll(RegExp(r'[^0-9\.]'), '');
  }

  /// Determines if current app installation is outdated
  bool isOutdated({
    required String currentVersion,
    int currentBuild = 0,
  }) {
    if (isUpdateAvailableFromServer != null) {
      return isUpdateAvailableFromServer!;
    }

    final comp = compareVersions(currentVersion, latestVersion);
    if (comp < 0) return true;
    if (comp == 0 && currentBuild > 0 && currentBuild < latestBuildNumber) {
      return true;
    }
    return false;
  }

  /// Determines if a mandatory (force) update is required
  bool isMandatoryUpdate({
    required String currentVersion,
    int currentBuild = 0,
  }) {
    // If not outdated at all, no update is required
    if (!isOutdated(currentVersion: currentVersion, currentBuild: currentBuild)) {
      return false;
    }

    if (forceUpdate) return true;

    final compMin = compareVersions(currentVersion, minVersion);
    if (compMin < 0) return true;
    if (compMin == 0 && currentBuild > 0 && currentBuild < minBuildNumber) {
      return true;
    }
    return false;
  }
}

/// Informasi Pemeliharaan / Persiapan Rilis Aplikasi (Pre-Launch Maintenance)
class AppMaintenanceInfo {
  final bool isActive;
  final String title;
  final String message;
  final String launchDate;
  final bool allowBrowsing;
  final String contactWhatsapp;

  const AppMaintenanceInfo({
    required this.isActive,
    this.title = 'Maintenance Aplikasi',
    this.message =
        'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.',
    this.launchDate = 'Desember 2026',
    this.allowBrowsing = true,
    this.contactWhatsapp = '6281234567890',
  });

  factory AppMaintenanceInfo.fromJson(Map<String, dynamic> json) {
    return AppMaintenanceInfo(
      isActive: json['is_active'] == true || json['is_active'] == 1,
      title: json['title']?.toString() ?? 'Maintenance Aplikasi',
      message: json['message']?.toString() ??
          'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.',
      launchDate: json['launch_date']?.toString() ?? 'Desember 2026',
      allowBrowsing: json['allow_browsing'] != false,
      contactWhatsapp: json['contact_whatsapp']?.toString() ?? '6281234567890',
    );
  }
}
