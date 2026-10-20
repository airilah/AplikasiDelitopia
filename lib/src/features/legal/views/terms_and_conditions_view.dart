import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/widgets/back_button_wrapper.dart';

class TermsAndConditionsView extends ConsumerWidget {
  const TermsAndConditionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;
    final sections = isId ? _termsId : _termsEn;
    final title = isId ? 'Syarat & Ketentuan' : 'Terms & Conditions';

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(title.toUpperCase()),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isId
                  ? 'Terakhir diperbarui: 1 Desember 2025'
                  : 'Last updated: December 1, 2025',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              _buildSection(section.title, section.body),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

const _termsId = [
  _LegalSection(
    '1. Penggunaan Aplikasi',
    'Dengan menggunakan aplikasi Delitopia, pengguna setuju untuk memakai layanan secara wajar, memberikan data yang benar, dan menjaga keamanan akun masing-masing.',
  ),
  _LegalSection(
    '2. Akun Pengguna',
    'Beberapa fitur seperti checkout, voucher, poin, profil, dan riwayat pesanan memerlukan akun aktif. Pengguna bertanggung jawab atas aktivitas yang terjadi pada akunnya.',
  ),
  _LegalSection(
    '3. Pesanan dan Pembayaran',
    'Pesanan bergantung pada ketersediaan menu dan outlet. Pembayaran QRIS harus diselesaikan sebelum batas waktu yang ditentukan. Pesanan tunai mengikuti proses pembayaran di kasir.',
  ),
  _LegalSection(
    '4. Voucher dan Poin',
    'Voucher dan poin mengikuti syarat masing-masing promo, termasuk masa berlaku, minimum transaksi, brand, outlet, dan batas penggunaan. Poin dapat berubah sesuai transaksi yang valid.',
  ),
  _LegalSection(
    '5. Perubahan Layanan',
    'Delitopia dapat memperbarui fitur, kebijakan, promo, atau ketentuan layanan untuk menyesuaikan operasional dan kebutuhan bisnis.',
  ),
];

const _termsEn = [
  _LegalSection(
    '1. App Usage',
    'By using the Delitopia app, users agree to use the service responsibly, provide accurate information, and keep their account secure.',
  ),
  _LegalSection(
    '2. User Account',
    'Some features such as checkout, vouchers, points, profile, and order history require an active account. Users are responsible for activities performed through their account.',
  ),
  _LegalSection(
    '3. Orders and Payments',
    'Orders depend on menu and outlet availability. QRIS payments must be completed before the configured expiry time. Cash orders follow the cashier payment process.',
  ),
  _LegalSection(
    '4. Vouchers and Points',
    'Vouchers and points follow each promotion rule, including validity period, minimum transaction, brand, outlet, and usage limits. Points may change based on valid transactions.',
  ),
  _LegalSection(
    '5. Service Changes',
    'Delitopia may update features, policies, promotions, or service terms to support operational and business needs.',
  ),
];
