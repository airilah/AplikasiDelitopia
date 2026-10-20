import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delitopia_v2/src/core/models/app_version_info.dart';
import 'package:delitopia_v2/src/core/widgets/app_maintenance_dialog.dart';

void main() {
  group('AppMaintenanceDialog Widget Tests (Desain 2: Compact & Minimalist)', () {
    testWidgets('renders maintenance dialog matching Desain 2 template correctly',
        (WidgetTester tester) async {
      const maintenanceInfo = AppMaintenanceInfo(
        isActive: true,
        title: 'Maintenance Aplikasi',
        message:
            'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.',
        launchDate: 'Desember 2026',
        allowBrowsing: true,
        contactWhatsapp: '6281234567890',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppMaintenanceDialog(
                maintenance: maintenanceInfo,
              ),
            ),
          ),
        ),
      );

      // Verify title & message
      expect(find.text('Maintenance Aplikasi'), findsOneWidget);
      expect(
        find.text(
            'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.'),
        findsOneWidget,
      );

      // Verify status & launch date
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Sampai'), findsOneWidget);
      expect(find.text('Desember 2026'), findsOneWidget);

      // Verify single Mengerti button (Hubungi Kami removed)
      expect(find.text('Mengerti'), findsOneWidget);
      expect(find.text('Hubungi Kami'), findsNothing);
    });

    testWidgets('tapping Mengerti triggers onDismiss callback',
        (WidgetTester tester) async {
      bool dismissed = false;

      const maintenanceInfo = AppMaintenanceInfo(
        isActive: true,
        title: 'Maintenance Aplikasi',
        message: 'Layanan pemesanan sedang dalam pemeliharaan sistem.',
        launchDate: 'Desember 2026',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppMaintenanceDialog(
                maintenance: maintenanceInfo,
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mengerti'));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });
}
