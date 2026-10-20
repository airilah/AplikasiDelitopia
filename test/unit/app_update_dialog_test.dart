import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delitopia_v2/src/core/services/app_update_service.dart';
import 'package:delitopia_v2/src/core/widgets/app_update_dialog.dart';

void main() {
  group('AppUpdateDialog Widget Tests (Desain 2: Simple & Professional)', () {
    testWidgets('renders clean mandatory update dialog correctly', (WidgetTester tester) async {
      const updateResult = AppUpdateCheckResult(
        hasUpdate: true,
        isForceUpdate: true,
        currentVersion: '2.1.7',
        currentBuildNumber: 30,
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        title: 'Pembaruan Aplikasi',
        message: 'Aplikasi Delitopia membutuhkan pembaruan ke versi terbaru di Google Play Store untuk dapat digunakan.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(updateResult: updateResult),
          ),
        ),
      );

      expect(find.text('Pembaruan Aplikasi'), findsOneWidget);
      expect(find.text('Aplikasi Delitopia membutuhkan pembaruan ke versi terbaru di Google Play Store untuk dapat digunakan.'), findsOneWidget);
      expect(find.text('Versi Saat Ini'), findsOneWidget);
      expect(find.text('Versi Terbaru'), findsOneWidget);
      expect(find.text('v2.1.7'), findsOneWidget);
      expect(find.text('v2.1.8'), findsOneWidget);
      expect(find.text('Perbarui'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });

    testWidgets('renders optional update dialog with Nanti', (WidgetTester tester) async {
      const updateResult = AppUpdateCheckResult(
        hasUpdate: true,
        isForceUpdate: false,
        currentVersion: '2.1.7',
        currentBuildNumber: 30,
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        title: 'Pembaruan Aplikasi',
        message: 'Aplikasi Delitopia membutuhkan pembaruan.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(updateResult: updateResult),
          ),
        ),
      );

      expect(find.text('Pembaruan Aplikasi'), findsOneWidget);
      expect(find.text('Perbarui'), findsOneWidget);
      expect(find.text('Nanti'), findsOneWidget);
      expect(find.text('Keluar'), findsNothing);
    });
  });
}
