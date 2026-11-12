import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delitopia_v2/src/core/models/app_version_info.dart';
import 'package:delitopia_v2/src/core/services/api_client.dart';
import 'package:delitopia_v2/src/core/services/app_update_service.dart';
import 'package:delitopia_v2/src/core/services/error_reporting_service.dart';
import 'package:delitopia_v2/src/core/services/storage_service.dart';

class _FakeAppUpdateService extends AppUpdateService {
  int checkCount = 0;
  bool maintenanceActive = false;

  @override
  Future<AppUpdateCheckResult> checkUpdate({bool forceRefresh = false}) async {
    checkCount++;
    return AppUpdateCheckResult(
      hasUpdate: false,
      isForceUpdate: false,
      currentVersion: '2.1.7',
      currentBuildNumber: 30,
      latestVersion: '2.1.7',
      latestBuildNumber: 30,
      title: '',
      message: '',
      playStoreUrl: '',
      maintenance: AppMaintenanceInfo(
        isActive: maintenanceActive,
        title: maintenanceActive ? 'Maintenance' : '',
        message: maintenanceActive ? 'Temporarily paused' : '',
      ),
    );
  }
}

class _InMemoryStorageService extends StorageService {
  String? _memToken;

  _InMemoryStorageService(super.prefs, super.secureStorage, [this._memToken]);

  @override
  String? getAuthToken() => _memToken;

  @override
  Future<void> saveAuthToken(String token) async {
    _memToken = token;
  }

  @override
  Future<void> deleteAuthToken() async {
    _memToken = null;
  }
}

class _StubAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) onFetch;

  _StubAdapter(this.onFetch);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return onFetch(options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 2 Stability & Auth Resilience Tests', () {
    test('AppMaintenanceNotifier does not poll when inactive and pauses outside active state', () async {
      final service = _FakeAppUpdateService()..maintenanceActive = false;
      final notifier = AppMaintenanceNotifier(service);
      await Future<void>.delayed(Duration.zero);

      expect(service.checkCount, 1);
      expect(notifier.isPollingActive, isFalse);

      // Resume within 60s cooldown should not trigger an extra network check
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCount, 1);

      // When maintenance becomes active, recovery polling activates
      service.maintenanceActive = true;
      await notifier.fetchMaintenance(force: true);
      expect(notifier.state?.isActive, isTrue);
      expect(notifier.isPollingActive, isTrue);

      // Backgrounding cancels active polling
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(notifier.isPollingActive, isFalse);

      // Deactivating maintenance stops polling
      service.maintenanceActive = false;
      await notifier.fetchMaintenance(force: true);
      expect(notifier.state?.isActive, isFalse);
      expect(notifier.isPollingActive, isFalse);

      notifier.dispose();
    });

    test('AuthInterceptor performs single-flight 401 refresh and retries concurrent requests once', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = _InMemoryStorageService(
        prefs,
        const FlutterSecureStorage(),
        'expired-token',
      );

      int refreshCalls = 0;
      int resourceCalls = 0;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final testDioProvider = Provider<Dio>((ref) {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
        dio.httpClientAdapter = _StubAdapter((options) {
          resourceCalls++;
          final auth = options.headers['Authorization'];
          if (auth == 'Bearer fresh-token') {
            return ResponseBody.fromString(
              jsonEncode({'ok': true}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'message': 'Token expired'}),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
        dio.interceptors.add(
          AuthInterceptor(
            ref,
            dio,
            refreshTokenOverride: (_) async {
              refreshCalls++;
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return 'fresh-token';
            },
          ),
        );
        return dio;
      });

      final dio = container.read(testDioProvider);
      final responses = await Future.wait([
        dio.get<Map<String, dynamic>>('/orders'),
        dio.get<Map<String, dynamic>>('/vouchers'),
      ]);

      expect(responses[0].statusCode, 200);
      expect(responses[1].statusCode, 200);
      expect(refreshCalls, 1);
      expect(resourceCalls, 4);
      expect(storage.getAuthToken(), 'fresh-token');
    });

    test('AuthInterceptor clears token on failed 401 refresh and skips auth lifecycle routes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = _InMemoryStorageService(
        prefs,
        const FlutterSecureStorage(),
        'expired-token',
      );

      int refreshCalls = 0;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final testDioProvider = Provider<Dio>((ref) {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
        dio.httpClientAdapter = _StubAdapter((_) {
          return ResponseBody.fromString(
            jsonEncode({'message': 'Unauthorized'}),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
        dio.interceptors.add(
          AuthInterceptor(
            ref,
            dio,
            refreshTokenOverride: (_) async {
              refreshCalls++;
              return null;
            },
          ),
        );
        return dio;
      });

      final dio = container.read(testDioProvider);

      // Login endpoint 401 must never trigger token refresh
      await expectLater(
        () => dio.post<dynamic>('/v2/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
      expect(storage.getAuthToken(), 'expired-token');

      // Protected endpoint 401 triggers refresh, fails, and clears stored token cleanly
      await expectLater(
        () => dio.get<dynamic>('/user/profile'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 1);
      expect(storage.getAuthToken(), isNull);
    });

    test('ErrorReportingService forwards recorded errors to configured sink safely', () {
      String? capturedReason;
      Object? capturedError;
      bool capturedFatal = false;

      ErrorReportingService.setRecorder((error, stackTrace, {reason, fatal = false}) {
        capturedError = error;
        capturedReason = reason;
        capturedFatal = fatal;
      });
      addTearDown(() => ErrorReportingService.setRecorder(null));

      ErrorReportingService.recordError(
        StateError('boom'),
        StackTrace.current,
        reason: 'unit_test',
        fatal: true,
      );

      expect(capturedError, isA<StateError>());
      expect(capturedReason, 'unit_test');
      expect(capturedFatal, isTrue);
    });
  });
}
