import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../help/views/help_center_view.dart';
import '../../legal/views/privacy_policy_view.dart';
import '../../legal/views/terms_and_conditions_view.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/widgets/app_update_dialog.dart';

class AboutUsView extends ConsumerWidget {
  const AboutUsView({super.key});

  static const _partnershipEmail = 'delitopiamarketing4@gmail.com';
  static const _websiteUrl = 'https://delitopiaindonesia.com';
  static const _instagramUrl = 'https://www.instagram.com/sushikun.id';
  static const _tiktokUrl = 'https://www.tiktok.com/@sushikun.id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isId = lang == AppLanguage.indonesia;

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(
            isId ? 'TENTANG DELITOPIA' : 'ABOUT DELITOPIA',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHero(context, isId),
            const SizedBox(height: 28),
            _buildAboutCard(isId),
            const SizedBox(height: 16),
            _buildFeaturesCard(isId),
            const SizedBox(height: 16),
            _buildHelpCenterBanner(context, isId),
            const SizedBox(height: 16),
            _buildCompanyInfoCard(isId),
            const SizedBox(height: 16),
            _buildFollowUsCard(isId),
            const SizedBox(height: 16),
            _buildLegalCard(context, isId),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '(c) 2026 Delitopia. ${isId ? 'Hak cipta dilindungi.' : 'All rights reserved.'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isId) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDD2222), Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDD2222).withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_menu_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Delitopia',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDD2222),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Version ${AppConstants.appVersion}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    isId ? 'Memeriksa pembaruan...' : 'Checking for updates...'),
                duration: const Duration(seconds: 1),
              ),
            );
            final updateResult = await AppUpdateService().checkUpdate();
            if (!context.mounted) return;
            if (updateResult.hasUpdate) {
              await AppUpdateDialog.show(context, updateResult: updateResult);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF2E7D32),
                  content: Text(
                    isId
                        ? 'Aplikasi sudah versi terbaru (v${updateResult.currentVersion})'
                        : 'App is already up to date (v${updateResult.currentVersion})',
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded,
                    size: 14, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  isId ? 'Periksa Pembaruan' : 'Check for Updates',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard(bool isId) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(isId ? 'Tentang Delitopia' : 'About Delitopia'),
          const SizedBox(height: 12),
          Text(
            isId
                ? 'Delitopia adalah aplikasi pemesanan makanan yang membantu pelanggan menjelajahi brand, outlet, dan menu yang tersedia dalam satu tempat. Pelanggan dapat memilih outlet, mencari menu, melakukan checkout, membayar dengan QRIS atau tunai, serta memantau riwayat pesanan langsung dari aplikasi.'
                : 'Delitopia is a food ordering app that helps customers browse available brands, outlets, and menus in one place. Customers can select an outlet, search menus, checkout, pay with QRIS or cash, and review their order history directly from the app.',
            style: TextStyle(color: Colors.grey[700], height: 1.6),
          ),
          const SizedBox(height: 14),
          Text(
            isId
                ? 'Aplikasi ini juga mendukung poin dan voucher agar pelanggan mendapatkan manfaat lebih dari transaksi yang sudah selesai.'
                : 'The app also supports points and vouchers so customers can receive more value from completed transactions.',
            style: TextStyle(color: Colors.grey[700], height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard(bool isId) {
    final features = isId ? _featuresId : _featuresEn;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(isId ? 'Fitur Utama' : 'Key Features'),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => _buildFeatureItem(
              icon: feature.icon,
              title: feature.title,
              description: feature.description,
            ),
          ),
        ],
      ),
    );
  }

  List<_FeatureInfo> get _featuresId => const [
        _FeatureInfo(
          Icons.storefront_rounded,
          'Brand & Outlet',
          'Lihat daftar brand dan outlet yang tersedia, lalu pilih outlet sebelum mencari menu.',
        ),
        _FeatureInfo(
          Icons.search_rounded,
          'Cari Menu',
          'Temukan menu berdasarkan outlet atau brand yang dipilih.',
        ),
        _FeatureInfo(
          Icons.shopping_cart_checkout_rounded,
          'Keranjang & Checkout',
          'Tambahkan menu ke keranjang dan lanjutkan pesanan dengan tipe dine in, take away, atau delivery jika tersedia.',
        ),
        _FeatureInfo(
          Icons.qr_code_2_rounded,
          'Pembayaran QRIS & Tunai',
          'Bayar pesanan menggunakan QRIS atau tunai sesuai metode pembayaran yang tersedia.',
        ),
        _FeatureInfo(
          Icons.receipt_long_rounded,
          'Pesanan Saya',
          'Pantau pesanan aktif, lihat riwayat, detail pembayaran, status pesanan, dan pesan ulang.',
        ),
        _FeatureInfo(
          Icons.stars_rounded,
          'Poin & Voucher',
          'Dapatkan poin dari transaksi selesai dan gunakan voucher sesuai syarat yang berlaku.',
        ),
        _FeatureInfo(
          Icons.person_rounded,
          'Profil Pelanggan',
          'Kelola data akun, nomor ponsel, email, alamat, dan pengaturan aplikasi.',
        ),
        _FeatureInfo(
          Icons.visibility_rounded,
          'Mode Guest',
          'Pengguna guest dapat melihat brand, outlet, mencari menu, dan melihat menu populer sebelum login.',
        ),
      ];

  List<_FeatureInfo> get _featuresEn => const [
        _FeatureInfo(
          Icons.storefront_rounded,
          'Brands & Outlets',
          'View available brands and outlets, then select an outlet before searching menus.',
        ),
        _FeatureInfo(
          Icons.search_rounded,
          'Menu Search',
          'Find menus based on the selected outlet or brand.',
        ),
        _FeatureInfo(
          Icons.shopping_cart_checkout_rounded,
          'Cart & Checkout',
          'Add menus to your cart and continue with dine in, take away, or delivery when available.',
        ),
        _FeatureInfo(
          Icons.qr_code_2_rounded,
          'QRIS & Cash Payment',
          'Pay orders using QRIS or cash based on the available payment methods.',
        ),
        _FeatureInfo(
          Icons.receipt_long_rounded,
          'My Orders',
          'Track active orders, view history, payment details, order status, and reorder.',
        ),
        _FeatureInfo(
          Icons.stars_rounded,
          'Points & Vouchers',
          'Earn points from completed transactions and use vouchers based on their terms.',
        ),
        _FeatureInfo(
          Icons.person_rounded,
          'Customer Profile',
          'Manage account data, phone number, email, addresses, and app settings.',
        ),
        _FeatureInfo(
          Icons.visibility_rounded,
          'Guest Mode',
          'Guest users can view brands, outlets, search menus, and browse popular menus before logging in.',
        ),
      ];

  Widget _buildHelpCenterBanner(BuildContext context, bool isId) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDD2222).withValues(alpha: 0.08),
            const Color(0xFFFF6B35).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDD2222).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Butuh Bantuan atau Ada Kendala?' : 'Need Help or Have an Issue?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isId
                          ? 'Cek solusi instan di Pusat Bantuan & FAQ'
                          : 'Find instant solutions in Help Center & FAQ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isId
                ? 'Punya pertanyaan tentang pesanan, pembayaran QRIS, poin, voucher, atau kendala lainnya? Temukan jawaban dan bantuan di Pusat Bantuan.'
                : 'Have questions regarding orders, QRIS payments, points, vouchers, or other issues? Find answers and support in the Help Center.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpCenterView(),
                  ),
                );
              },
              icon: const Icon(Icons.help_outline_rounded, size: 20),
              label: Text(
                isId ? 'Buka Pusat Bantuan & FAQ' : 'Open Help Center & FAQ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoCard(bool isId) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(isId ? 'Kantor & Kemitraan' : 'Office & Partnership'),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            title: isId ? 'Kantor Operasional' : 'Operations Office',
            value: 'Surabaya, Jawa Timur, Indonesia',
            onTap: null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          _buildInfoRow(
            icon: Icons.business_center_outlined,
            title: isId ? 'Kemitraan & Kerjasama Bisnis' : 'Business & Partnership Inquiries',
            value: _partnershipEmail,
            onTap: () => _launchEmail(
              _partnershipEmail,
              subject: isId
                  ? 'Kemitraan & Kerjasama Bisnis - Delitopia'
                  : 'Business & Partnership - Delitopia',
            ),
            isAction: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUsCard(bool isId) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(isId ? 'Ikuti Kami' : 'Follow Us'),
          const SizedBox(height: 6),
          Text(
            isId
                ? 'Dapatkan promo terkini, menu baru, dan kabar seru lainnya melalui media sosial resmi kami:'
                : 'Get the latest promotions, new menus, and exciting updates on our official social media:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                icon: Icons.language_rounded,
                label: 'Website',
                onTap: () => _launchUrl(_websiteUrl),
              ),
              _buildSocialButton(
                icon: FontAwesomeIcons.instagram,
                label: 'Instagram',
                onTap: () => _launchUrl(_instagramUrl),
              ),
              _buildSocialButton(
                icon: FontAwesomeIcons.tiktok,
                label: 'TikTok',
                onTap: () => _launchUrl(_tiktokUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context, bool isId) {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined, color: Color(0xFFDD2222)),
            title: Text(isId ? 'Syarat & Ketentuan' : 'Terms & Conditions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsAndConditionsView(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFDD2222)),
            title: Text(isId ? 'Kebijakan Privasi' : 'Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyView(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDD2222).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFDD2222), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback? onTap,
    bool isAction = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFDD2222)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isAction && onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.open_in_new, size: 16, color: Color(0xFFDD2222)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: icon is IconData
                  ? Icon(icon, color: const Color(0xFFDD2222), size: 28)
                  : FaIcon(icon, color: const Color(0xFFDD2222), size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email, {required String subject}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject},
    );
    await _openUri(emailUri);
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    await _openUri(uri, external: true);
  }

  Future<void> _openUri(Uri uri, {bool external = false}) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: external ? LaunchMode.externalApplication : LaunchMode.platformDefault,
      );
      if (!launched && external) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (external) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    }
  }
}

class _FeatureInfo {
  const _FeatureInfo(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}
