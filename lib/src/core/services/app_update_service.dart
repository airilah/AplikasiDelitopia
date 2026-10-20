import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../models/app_version_info.dart';

/// Result from checking app version against backend
class AppUpdateCheckResult {
  final bool hasUpdate;
  final bool isForceUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String title;
  final String message;
  final String playStoreUrl;
  final List<String> whatsNew;
  final AppVersionInfo? versionInfo;
  final AppMaintenanceInfo? maintenance;

  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.title,
    required this.message,
    required this.playStoreUrl,
    this.whatsNew = const [],
    this.versionInfo,
    this.maintenance,
  });

  factory AppUpdateCheckResult.upToDate({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    return AppUpdateCheckResult(
      hasUpdate: false,
      isForceUpdate: false,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      latestVersion: currentVersion,
      latestBuildNumber: currentBuildNumber,
      title: 'Aplikasi Sudah Versi Terbaru',
      message: 'Anda sudah menggunakan versi terbaru Delitopia.',
      playStoreUrl: AppConstants.playStoreUrl,
      whatsNew: const [],
    );
  }
}

/// Service that checks app updates and handles redirecting to Play Store
class AppUpdateService {
  final Dio _dio;

  AppUpdateService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            );

  /// Get installed app version and build number
  Future<Map<String, dynamic>> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber) ??
          AppConstants.appBuildNumber;
      return {
        'version': packageInfo.version.isNotEmpty
            ? packageInfo.version
            : AppConstants.appVersion,
        'build_number': buildNumber,
      };
    } catch (e) {
      debugPrint('⚠️ Error retrieving PackageInfo: $e');
      return {
        'version': AppConstants.appVersion,
        'build_number': AppConstants.appBuildNumber,
      };
    }
  }

  /// Check if an update is available from the backend
  Future<AppUpdateCheckResult> checkUpdate() async {
    final current = await getCurrentAppVersion();
    final currentVersion = current['version'] as String;
    final currentBuild = current['build_number'] as int;

    try {
      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

      final response = await _dio.get(
        ApiConstants.appVersion,
        queryParameters: {
          'platform': platform,
          'current_version': currentVersion,
          'build_number': currentBuild,
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data;
        final data = body is Map<String, dynamic> && body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : (body is Map<String, dynamic> ? body : null);

        if (data != null) {
          final versionInfo = AppVersionInfo.fromJson(data);
          final hasUpdate = versionInfo.isOutdated(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
          );
          final isForce = versionInfo.isMandatoryUpdate(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
          );

          return AppUpdateCheckResult(
            hasUpdate: hasUpdate,
            isForceUpdate: isForce,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuild,
            latestVersion: versionInfo.latestVersion,
            latestBuildNumber: versionInfo.latestBuildNumber,
            title: versionInfo.title,
            message: versionInfo.message,
            playStoreUrl: versionInfo.playStoreUrl,
            whatsNew: versionInfo.whatsNew,
            versionInfo: versionInfo,
            maintenance: versionInfo.maintenance,
          );
        }
      }

      return AppUpdateCheckResult.upToDate(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuild,
      );
    } catch (e) {
      debugPrint('⚠️ App update check skipped or failed: $e');
      // Graceful fallback: do not block user if network is down or API unavailable
      return AppUpdateCheckResult.upToDate(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuild,
      );
    }
  }

  /// Launch Google Play Store or web link
  static Future<bool> launchPlayStore({String? customUrl}) async {
    final targetUrl = (customUrl != null && customUrl.isNotEmpty)
        ? customUrl
        : AppConstants.playStoreUrl;

    try {
      // On Android, first attempt to launch via market:// scheme for direct Play Store app opening
      if (!kIsWeb && Platform.isAndroid) {
        final marketUri = Uri.parse(AppConstants.marketUrl);
        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(
            marketUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      }

      // Fallback to web link
      final webUri = Uri.parse(targetUrl);
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('❌ Error launching Play Store: $e');
      return false;
    }
  }

  /// Launch WhatsApp for customer support
  static Future<bool> launchWhatsApp(String phoneNumber, [String? text]) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final targetPhone = cleanPhone.startsWith('0')
        ? '62${cleanPhone.substring(1)}'
        : (cleanPhone.startsWith('62') ? cleanPhone : '62$cleanPhone');
    final message = text ??
        'Halo Admin Delitopia, saya ingin bertanya seputar layanan pemesanan aplikasi.';
    final waUri = Uri.parse(
        'https://wa.me/$targetPhone?text=${Uri.encodeComponent(message)}');

    try {
      return await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Error launching WhatsApp: $e');
      return false;
    }
  }
}

/// Riverpod provider for AppUpdateService
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// StateNotifier that manages, auto-fetches, and auto-polls AppMaintenanceInfo in real time
class AppMaintenanceNotifier extends StateNotifier<AppMaintenanceInfo?>
    with WidgetsBindingObserver {
  final AppUpdateService _service;
  Timer? _pollingTimer;

  AppMaintenanceNotifier(this._service) : super(null) {
    WidgetsBinding.instance.addObserver(this);
    fetchMaintenance();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll every 6 detik agar perubahan dari website admin langsung sinkron di layar HP
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      fetchMaintenance();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Saat admin berpindah dari browser web ke aplikasi HP/emulator
      fetchMaintenance();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  set state(AppMaintenanceInfo? value) {
    super.state = value;
  }

  void setMaintenance(AppMaintenanceInfo? info) {
    super.state = info;
  }

  Future<void> fetchMaintenance() async {
    try {
      final result = await _service.checkUpdate();
      final fresh = result.maintenance ?? const AppMaintenanceInfo(isActive: false);

      // Hanya trigger rebuild jika ada nilai yang benar-benar berubah
      if (state == null ||
          state!.isActive != fresh.isActive ||
          state!.title != fresh.title ||
          state!.message != fresh.message ||
          state!.launchDate != fresh.launchDate) {
        super.state = fresh;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching maintenance status: $e');
    }
  }
}

/// Riverpod provider for app maintenance status with auto-fetch
final appMaintenanceProvider =
    StateNotifierProvider<AppMaintenanceNotifier, AppMaintenanceInfo?>((ref) {
  final service = ref.watch(appUpdateServiceProvider);
  return AppMaintenanceNotifier(service);
});

