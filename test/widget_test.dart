import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delitopia_v2/main.dart';
import 'package:delitopia_v2/src/core/services/app_update_service.dart';
import 'package:delitopia_v2/src/core/services/storage_service.dart';

class _IdleAppUpdateService extends AppUpdateService {
  @override
  Future<AppUpdateCheckResult> checkUpdate({bool forceRefresh = false}) async {
    return AppUpdateCheckResult.upToDate(
      currentVersion: '2.1.7',
      currentBuildNumber: 30,
    );
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs, const FlutterSecureStorage());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storageServiceProvider.overrideWithValue(storageService),
          appUpdateServiceProvider.overrideWithValue(_IdleAppUpdateService()),
        ],
        child: const DelitopiaApp(),
      ),
    );

    expect(find.byType(DelitopiaApp), findsOneWidget);

    // Unmount cleanly so splash timers are cancelled before test invariants run
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
