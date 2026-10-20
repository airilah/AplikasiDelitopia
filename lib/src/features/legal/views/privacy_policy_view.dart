import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/widgets/back_button_wrapper.dart';

class PrivacyPolicyView extends ConsumerWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;
    final sections = isId ? _privacyId : _privacyEn;

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(tr.get('privacy_policy', lang).toUpperCase()),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr.get('privacy_policy', lang),
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

const _privacyId = [
  _LegalSection(
    '1. Informasi yang Kami Kumpulkan',
    'Kami mengumpulkan informasi yang diperlukan untuk menjalankan aplikasi, termasuk nama, email, nomor ponsel, alamat pengiriman, riwayat pesanan, preferensi voucher dan poin, serta data lokasi jika izin lokasi diaktifkan.',
  ),
  _LegalSection(
    '2. Penggunaan Informasi',
    'Informasi digunakan untuk memproses pesanan, mengirim pembaruan status, mengelola pembayaran, memberi layanan pelanggan, menampilkan voucher dan poin, meningkatkan pengalaman aplikasi, serta menjaga keamanan akun.',
  ),
  _LegalSection(
    '3. Pembagian Data',
    'Kami dapat membagikan data yang relevan kepada outlet, penyedia pembayaran, penyedia pengiriman, layanan notifikasi, atau pihak lain yang diperlukan untuk menjalankan layanan. Data tidak dijual kepada pihak ketiga.',
  ),
  _LegalSection(
    '4. Keamanan Data',
    'Kami menerapkan perlindungan teknis dan operasional untuk menjaga data pengguna. Namun, tidak ada sistem digital yang sepenuhnya bebas risiko, sehingga pengguna tetap perlu menjaga keamanan akun dan perangkatnya.',
  ),
  _LegalSection(
    '5. Hak Pengguna',
    'Pengguna dapat memperbarui informasi profil, mengelola alamat, mengubah preferensi notifikasi, dan menghubungi customer support untuk pertanyaan terkait data pribadi.',
  ),
];

const _privacyEn = [
  _LegalSection(
    '1. Information We Collect',
    'We collect information required to operate the app, including name, email, phone number, delivery addresses, order history, voucher and point preferences, and location data when location permission is enabled.',
  ),
  _LegalSection(
    '2. How We Use Information',
    'Information is used to process orders, send status updates, manage payments, provide customer support, show vouchers and points, improve the app experience, and protect account security.',
  ),
  _LegalSection(
    '3. Data Sharing',
    'We may share relevant data with outlets, payment providers, delivery providers, notification services, or other parties required to operate the service. We do not sell user data to third parties.',
  ),
  _LegalSection(
    '4. Data Security',
    'We apply technical and operational safeguards to protect user data. However, no digital system is completely risk-free, so users should also protect their account and device.',
  ),
  _LegalSection(
    '5. User Rights',
    'Users can update profile information, manage addresses, change notification preferences, and contact customer support for questions about personal data.',
  ),
];
