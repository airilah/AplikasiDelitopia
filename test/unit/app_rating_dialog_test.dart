import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delitopia_v2/src/core/widgets/app_rating_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('AppRatingDialog Widget Tests (Post-Delivery Success)', () {
    testWidgets('renders rate dialog matching Desain 2 template correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppRatingDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Beri Nilai Aplikasi'), findsOneWidget);
      expect(
        find.text('Pesananmu telah selesai diterima. Bantu Delitopia menjadi lebih baik dengan memberikan ulasan di Google Play Store.'),
        findsOneWidget,
      );
      expect(find.text('Sangat Puas ⭐⭐⭐⭐⭐'), findsOneWidget);
      expect(find.text('Nanti Saja'), findsOneWidget);
      expect(find.text('Beri Nilai'), findsOneWidget);
    });

    testWidgets('allows tapping stars to change rating feedback', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppRatingDialog(),
            ),
          ),
        ),
      );

      // Tap 3rd star
      await tester.tap(find.byKey(const ValueKey('star_3')));
      await tester.pump();

      expect(find.text('Baik ⭐⭐⭐'), findsOneWidget);
    });

    test('shouldShowPrompt throttles prompts correctly', () async {
      // 1. Initial state -> should show
      final initial = await AppRatingDialog.shouldShowPrompt();
      expect(initial, isTrue);

      // 2. Dismiss prompt -> within 30 days should NOT show
      await AppRatingDialog.recordPromptDismissed();
      final afterDismiss = await AppRatingDialog.shouldShowPrompt();
      expect(afterDismiss, isFalse);

      // 3. Mark rated -> never show again
      await AppRatingDialog.recordRated();
      final afterRated = await AppRatingDialog.shouldShowPrompt();
      expect(afterRated, isFalse);
    });
  });
}
