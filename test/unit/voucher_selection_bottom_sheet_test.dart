import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delitopia_v2/src/core/localization/app_language.dart';
import 'package:delitopia_v2/src/features/voucher/models/voucher_model.dart';
import 'package:delitopia_v2/src/features/cart/widgets/voucher_selection_bottom_sheet.dart';

void main() {
  group('VoucherSelectionBottomSheet Widget Tests', () {
    final eligibleVoucher = DetailVoucher(
      id: 101,
      userId: 1,
      voucherId: 1,
      status: 'active',
      voucher: Voucher(
        id: 1,
        voucherName: 'Diskon Spesial 20%',
        description: 'Diskon 20% untuk semua menu',
        voucherType: 'percentage',
        discountPercentage: 20,
        maxDiscountAmount: 20000,
        minSpend: 25000,
        point: 0,
        price: 0,
        isPurchasable: false,
        isAutoGranted: true,
        requiresActivation: false,
        acquisitionType: 'free',
        usageChannel: 'all',
      ),
    );

    final wrongBrandVoucher = DetailVoucher(
      id: 102,
      userId: 1,
      voucherId: 2,
      status: 'active',
      voucher: Voucher(
        id: 2,
        voucherName: 'Diskon Sushi Kun Rp 15.000',
        description: 'Hanya berlaku di Sushi Kun',
        brandId: 99,
        brandName: 'Sushi Kun',
        voucherType: 'amount',
        discountAmount: 15000,
        minSpend: 30000,
        point: 0,
        price: 0,
        isPurchasable: false,
        isAutoGranted: true,
        requiresActivation: false,
        acquisitionType: 'free',
        usageChannel: 'all',
      ),
    );

    final minSpendNotMetVoucher = DetailVoucher(
      id: 103,
      userId: 1,
      voucherId: 3,
      status: 'active',
      voucher: Voucher(
        id: 3,
        voucherName: 'Potongan Belanja Rp 25.000',
        description: 'Minimal belanja Rp 50.000',
        voucherType: 'amount',
        discountAmount: 25000,
        minSpend: 50000,
        point: 0,
        price: 0,
        isPurchasable: false,
        isAutoGranted: true,
        requiresActivation: false,
        acquisitionType: 'free',
        usageChannel: 'all',
      ),
    );

    final cashierOnlyVoucher = DetailVoucher(
      id: 104,
      userId: 1,
      voucherId: 4,
      status: 'active',
      voucher: Voucher(
        id: 4,
        voucherName: 'Voucher Kasir Fisik',
        description: 'Tukar di kasir langsung',
        voucherType: 'amount',
        discountAmount: 10000,
        minSpend: 20000,
        point: 0,
        price: 0,
        isPurchasable: false,
        isAutoGranted: true,
        requiresActivation: false,
        acquisitionType: 'free',
        usageChannel: 'cashier_only',
      ),
    );

    testWidgets('renders modal header, Tanpa Voucher, and categorizes eligible vs ineligible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoucherSelectionBottomSheet(
              userVouchers: [
                eligibleVoucher,
                wrongBrandVoucher,
                minSpendNotMetVoucher,
                cashierOnlyVoucher,
              ],
              currentBrandId: 1,
              currentBrandName: 'Tomoko',
              cartSubtotal: 30000,
              deliveryFee: 10000,
              orderType: 'dine_in',
              selectedVoucherId: 101,
              lang: AppLanguage.indonesia,
              onSelectVoucher: (_, __) {},
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Pilih Voucher'), findsOneWidget);
      expect(find.text('Gunakan voucher untuk hemat lebih banyak'), findsOneWidget);

      // Verify "Tanpa Voucher" option
      expect(find.text('Tanpa Voucher'), findsOneWidget);

      // Verify Eligible Section
      expect(find.text('VOUCHER DAPAT DIGUNAKAN (1)'), findsOneWidget);
      expect(find.text('Diskon Spesial 20%'), findsOneWidget);
      expect(find.text('Diskon 20% s.d. 20rb'), findsOneWidget);

      // Verify Ineligible Section
      expect(find.text('VOUCHER BELUM MEMENUHI SYARAT (3)'), findsOneWidget);
      expect(find.text('Diskon Sushi Kun Rp 15.000'), findsOneWidget);
      expect(find.text('Hanya berlaku di outlet Sushi Kun'), findsOneWidget);

      expect(find.text('Potongan Belanja Rp 25.000'), findsOneWidget);
      expect(
        find.textContaining('Kurang Rp 20.000 lagi untuk menggunakan voucher ini'),
        findsOneWidget,
      );

      // Scroll down to see remaining ineligible items in the list
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Voucher Kasir Fisik'), findsOneWidget);
      expect(
        find.text('Hanya berlaku untuk penukaran langsung di kasir outlet'),
        findsOneWidget,
      );
    });

    testWidgets('tapping an eligible voucher invokes onSelectVoucher callback',
        (WidgetTester tester) async {
      DetailVoucher? selected;
      double discount = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoucherSelectionBottomSheet(
              userVouchers: [eligibleVoucher],
              currentBrandId: 1,
              currentBrandName: 'Tomoko',
              cartSubtotal: 30000,
              deliveryFee: 10000,
              orderType: 'dine_in',
              selectedVoucherId: null,
              lang: AppLanguage.indonesia,
              onSelectVoucher: (dv, amt) {
                selected = dv;
                discount = amt;
              },
            ),
          ),
        ),
      );

      // Tap the eligible voucher
      await tester.tap(find.text('Diskon Spesial 20%'));
      await tester.pump();

      expect(selected?.id, 101);
      // 20% of 30.000 = 6.000
      expect(discount, 6000.0);
    });

    testWidgets('tapping Tanpa Voucher invokes onSelectVoucher with null',
        (WidgetTester tester) async {
      DetailVoucher? selected = eligibleVoucher;
      double discount = 6000.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoucherSelectionBottomSheet(
              userVouchers: [eligibleVoucher],
              currentBrandId: 1,
              currentBrandName: 'Tomoko',
              cartSubtotal: 30000,
              deliveryFee: 10000,
              orderType: 'dine_in',
              selectedVoucherId: 101,
              lang: AppLanguage.indonesia,
              onSelectVoucher: (dv, amt) {
                selected = dv;
                discount = amt;
              },
            ),
          ),
        ),
      );

      // Tap Tanpa Voucher
      await tester.tap(find.text('Tanpa Voucher'));
      await tester.pump();

      expect(selected, isNull);
      expect(discount, 0.0);
    });
  });
}
