import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/voucher_controller.dart';
import '../models/voucher_model.dart';
import '../../../shared/services/pos_service.dart' as pos_service;
import '../../../core/localization/app_language.dart';
import '../../../core/services/api_client.dart';
import '../../../core/widgets/feature_tour_wrapper.dart';
import '../../../core/widgets/feature_spotlight.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';

class VouchersView extends ConsumerStatefulWidget {
  final int initialTab;
  const VouchersView({super.key, this.initialTab = 0});

  @override
  ConsumerState<VouchersView> createState() => _VouchersViewState();
}

class _VouchersViewState extends ConsumerState<VouchersView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _allVouchersScrollController = ScrollController();
  late int _currentTabIndex;
  String _selectedTypeFilter = 'all';
  String _selectedSortOrder = 'newest';

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTab;
    _tabController =
        TabController(initialIndex: widget.initialTab, length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _allVouchersScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_currentTabIndex == _tabController.index) return;
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      child: FeatureTourWrapper(
        featureKey: 'vouchers',
        enabled: _currentTabIndex == 0,
        scrollController: _allVouchersScrollController,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            leading: const AppBackButton(color: Colors.white),
            title: Text(tr.get('voucher_points_title', lang),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: const Color(0xFFDD2222),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: _currentTabIndex == 0
                ? const [FeatureTourButton(featureKey: 'vouchers')]
                : const [],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: tr.get('all_vouchers_tab', lang)),
                Tab(text: tr.get('my_vouchers', lang)),
                Tab(text: tr.get('points_history_tab', lang)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAllVouchersTab(),
              _buildMyVouchersTab(),
              _buildPointsHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllVouchersTab() {
    final lang = ref.watch(appLanguageProvider);
    final categorizedVouchersAsync = ref.watch(categorizedVouchersProvider);
    final userPointsAsync = ref.watch(userPointsProvider);

    return RefreshIndicator(
      color: const Color(0xFFDD2222),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(categorizedVouchersProvider);
        ref.invalidate(userPointsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        controller: _allVouchersScrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Points Header
          SpotlightTarget(
            targetKey: 'vouchers_points_card',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: InkWell(
                onTap: () => _tabController.animateTo(2),
                child: userPointsAsync.when(
                  data: (points) => _buildPointsHeaderCard(points),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ),
          ),

          categorizedVouchersAsync.when(
            data: (categories) {
              final free = categories['auto_granted'] ?? [];
              final points = categories['point_redemption'] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoucherSection(tr.get('free_vouchers', lang), free,
                      userPointsAsync.value ?? 0, 'free',
                      spotlightKey: 'vouchers_free_section'),
                  _buildVoucherSection(tr.get('redeem_with_points', lang),
                      points, userPointsAsync.value ?? 0, 'point',
                      spotlightKey: 'vouchers_point_section'),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  _tabController.animateTo(2);
                },
                child: Center(
                    child: Text(tr.get('unable_to_load_vouchers', lang))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHeaderCard(int points) {
    final lang = ref.watch(appLanguageProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFE52D27), Color(0xFFB31217)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildGoldPointBadge(size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.get('my_points', lang),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  points.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherSection(
    String title,
    List<Voucher> vouchers,
    int userPoints,
    String type, {
    String? spotlightKey,
  }) {
    final titleWidget = Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spotlightKey != null)
          SpotlightTarget(
            targetKey: spotlightKey,
            child: titleWidget,
          )
        else
          titleWidget,
        if (vouchers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                type == 'free'
                    ? tr.get('no_free_vouchers', ref.watch(appLanguageProvider))
                    : type == 'point'
                        ? tr.get(
                            'no_point_vouchers', ref.watch(appLanguageProvider))
                        : tr.get(
                            'no_cash_vouchers', ref.watch(appLanguageProvider)),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vouchers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              final bool canAfford =
                  type != 'point' || userPoints >= voucher.point;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: _buildThematicVoucherLeading(voucher),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            voucher.voucherName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (voucher.isSoldOut) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Text(
                              ref.watch(appLanguageProvider) == AppLanguage.indonesia
                                  ? 'KUOTA HABIS'
                                  : 'SOLD OUT',
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${voucher.displayBrandName}${voucher.endDate != null && voucher.endDate!.isNotEmpty ? ' - ${tr.get('valid_until_short', ref.watch(appLanguageProvider))} ${_formatDateHeader(voucher.endDate, ref.watch(appLanguageProvider))}' : ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          voucher.getBenefitSummary(ref.watch(appLanguageProvider)),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (voucher.isLimitedStock && !voucher.isSoldOut) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: const Color(0xFFFFEDD5)),
                            ),
                            child: Text(
                              ref.watch(appLanguageProvider) ==
                                      AppLanguage.indonesia
                                  ? '🔥 Sisa ${voucher.remainingStock} Kuota'
                                  : '🔥 ${voucher.remainingStock} Left',
                              style: const TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: type == 'point' && !canAfford
                        ? const Icon(Icons.lock, color: Colors.grey, size: 18)
                        : Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[400], size: 22),
                    onTap: () {
                      _showUnclaimedVoucherDetailSheet(
                          voucher, type, canAfford);
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildThematicVoucherLeading(Voucher voucher, {double size = 52}) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;
    final type = voucher.voucherType.toLowerCase();
    IconData icon;
    String shortLabel = '';
    Color accentColor;

    if (type == 'birthday') {
      icon = Icons.cake_rounded;
      shortLabel = 'BDAY';
      accentColor = const Color(0xFFDB2777); // Rose
    } else if (type == 'buy_1_get_1') {
      icon = Icons.card_giftcard_rounded;
      shortLabel = 'B1G1';
      accentColor = const Color(0xFFD97706); // Amber Gold
    } else if (type == 'free_menu' || type == 'free_item') {
      icon = Icons.restaurant_rounded;
      shortLabel = 'FREE';
      accentColor = const Color(0xFF4F46E5); // Slate Indigo
    } else if (type == 'free_delivery') {
      icon = Icons.delivery_dining_rounded;
      shortLabel = isIndo ? 'ONGKIR' : 'SHIPPING';
      accentColor = const Color(0xFF0284C7); // Sky Ocean
    } else if (voucher.discountAmount != null && voucher.discountAmount! > 0) {
      icon = Icons.local_offer_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      final rb = (voucher.discountAmount! / 1000).round();
      shortLabel = '${rb}K';
    } else if (voucher.discountPercentage != null &&
        voucher.discountPercentage! > 0) {
      icon = Icons.percent_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      shortLabel = '${voucher.discountPercentage!.toInt()}%';
    } else if (voucher.point > 0) {
      icon = Icons.stars_rounded;
      shortLabel = '${voucher.point}P';
      accentColor = const Color(0xFFEA580C); // Warm Orange
    } else if (voucher.isPurchasable) {
      icon = Icons.payments_rounded;
      shortLabel = 'DEAL';
      accentColor = const Color(0xFF059669); // Emerald
    } else {
      icon = Icons.local_offer_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      shortLabel = 'PROMO';
    }

    // Determine corner ribbon text & color based on acquisition model
    String cornerText = '';
    Color cornerColor = accentColor;

    final isBirthday = type == 'birthday' || voucher.acquisitionType == 'birthday';
    final isOutletQr = voucher.acquisitionType == 'outlet_qr' || voucher.isOutletQrVoucher;
    final isPoint = voucher.acquisitionType == 'points' || (voucher.point > 0 && !isOutletQr);
    final isFree = voucher.acquisitionType == 'free' ||
        voucher.isFreeVoucher ||
        (voucher.price == 0 && voucher.point == 0 && !isOutletQr && !isBirthday);

    if (isBirthday) {
      cornerText = 'Birth';
      cornerColor = const Color(0xFFDB2777);
    } else if (isOutletQr) {
      cornerText = 'Scan';
      cornerColor = const Color(0xFF2563EB);
    } else if (isPoint) {
      cornerText = '${voucher.point}P';
      cornerColor = const Color(0xFFEA580C);
    } else if (isFree) {
      cornerText = 'Free';
      cornerColor = accentColor;
    } else if (voucher.isPurchasableWithMoney) {
      cornerText = 'Rp';
      cornerColor = const Color(0xFF059669);
    }

    // Frosted Neutral Glass (#F8FAFC) with soft accent-tinted border & icon
    const frostedNeutralBg = Color(0xFFF8FAFC);
    final borderRadius = BorderRadius.circular(size > 54 ? 16 : 12);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: frostedNeutralBg,
        borderRadius: borderRadius,
        border:
            Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center icon and short label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accentColor, size: size > 54 ? 24 : 19),
                const SizedBox(height: 2),
                Text(
                  shortLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: size > 54 ? 10.5 : 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),

            // Top-left diagonal ribbon (clipped inside border)
            if (cornerText.isNotEmpty)
              Positioned(
                top: size > 54 ? 5.5 : 4.6,
                left: size > 54 ? -25.0 : -20.2,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Container(
                    width: size > 54 ? 70.0 : 58.0,
                    height: size > 54 ? 14.5 : 12.5,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cornerColor,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      cornerText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size > 54 ? 8.2 : 6.9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.15,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  void _showUnclaimedVoucherDetailSheet(
      Voucher voucher, String type, bool canAfford) {
    final lang = ref.watch(appLanguageProvider);
    final bool isOutletQr = voucher.acquisitionType == 'outlet_qr';
    final bool isPaidCash = !isOutletQr &&
        (type == 'cash' || voucher.acquisitionType == 'cash' || (voucher.isPurchasable && voucher.price > 0));
    final bool isPoint =
        !isOutletQr && !isPaidCash && (type == 'point' || voucher.acquisitionType == 'points' || voucher.point > 0);
    final bool isFree = !isOutletQr && !isPaidCash && !isPoint;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThematicVoucherLeading(voucher, size: 64),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voucher.voucherName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                voucher.displayBrandName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDD2222),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (voucher.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        voucher.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],

                    // Paid Deal / Buy with Cash Highlight Card
                    if (isPaidCash) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Harga Spesial Deal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  voucher.formattedPrice,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF6EE7B7)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.qr_code_2_rounded,
                                      size: 16, color: Color(0xFF047857)),
                                  SizedBox(width: 4),
                                  Text(
                                    'QRIS / E-Wallet',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Outlet QR info card (Promo Meja Gerai)
                    if (isOutletQr) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                color: Color(0xFF2563EB), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.watch(appLanguageProvider) == AppLanguage.indonesia
                                        ? 'Promo Khusus Meja Gerai'
                                        : 'Dine-In Table Exclusive',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ref.watch(appLanguageProvider) == AppLanguage.indonesia
                                        ? 'Voucher ini khusus untuk pelanggan yang hadir di gerai ${voucher.displayBrandName}. Tekan tombol di bawah untuk membuka scanner dan pindai standing banner QR di meja Anda.'
                                        : 'This voucher is exclusively for guests dining at ${voucher.displayBrandName}. Tap the button below to open the scanner and scan the standing QR banner on your table.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF2563EB),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(tr.get('voucher_type', lang),
                              _getVoucherTypeText(voucher, lang)),
                          const Divider(height: 20),
                          _buildDetailRow(tr.get('valid_from', lang),
                              _formatDateString(voucher.startDate)),
                          const Divider(height: 20),
                          _buildDetailRow(tr.get('valid_until', lang),
                              _formatDateString(voucher.endDate)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (voucher.isSoldOut || (isPoint && !canAfford))
                        ? Colors.grey.shade400
                        : const Color(0xFFDD2222),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (voucher.isSoldOut || (isPoint && !canAfford))
                      ? null
                      : () {
                          if (isOutletQr) {
                            Navigator.pop(context);
                            if (AuthGuard.requireLogin(context, ref, redirectTo: AppRouter.qrScanner)) {
                              context.push(AppRouter.qrScanner);
                            }
                            return;
                          }
                          Navigator.pop(context);
                          if (!AuthGuard.requireLogin(context, ref)) {
                            return;
                          }
                          _showRedeemDialog(
                              voucher, isPoint ? 'point' : 'free');
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!voucher.isSoldOut && isOutletQr) ...[
                        const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        voucher.isSoldOut
                            ? tr.get('promo_sold_out', lang)
                            : (isPoint && !canAfford)
                                ? tr.get('not_enough_points_button', lang).replaceAll(' ({points})', '')
                                : isOutletQr
                                    ? tr.get('scan_table_qr', lang)
                                    : isFree
                                        ? tr.get('claim_free_voucher', lang)
                                        : isPoint
                                            ? tr.get('redeem_points', lang)
                                            : tr.get('claim_free_voucher', lang),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF202124),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getVoucherTypeText(Voucher voucher, AppLanguage lang) {
    switch (voucher.voucherType) {
      case 'percentage':
      case 'percentage_off':
      case 'discount_percentage':
        return tr
            .get('voucher_type_discount_percent', lang)
            .replaceAll('{percent}', voucher.formattedDiscount);
      case 'amount':
      case 'discount':
      case 'discount_amount':
        return tr
            .get('voucher_type_discount_amount', lang)
            .replaceAll('{amount}', voucher.formattedDiscount);
      case 'buy_1_get_1':
        return tr.get('voucher_type_b1g1', lang);
      case 'free_item':
      case 'free_menu':
        return tr.get('voucher_type_free_menu', lang);
      case 'birthday':
        return tr.get('voucher_type_birthday', lang);
      case 'free_delivery':
        return tr.get('voucher_type_free_delivery', lang);
      default:
        return tr.get('voucher_type_promo', lang);
    }
  }

  String _formatDateString(String? dateStr) {
    final lang = ref.read(appLanguageProvider);
    if (dateStr == null || dateStr.isEmpty) return tr.get('no_expiry', lang);
    try {
      final dt = DateTime.parse(dateStr);
      final months = lang == AppLanguage.english
          ? [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December'
            ]
          : [
              'Januari',
              'Februari',
              'Maret',
              'April',
              'Mei',
              'Juni',
              'Juli',
              'Agustus',
              'September',
              'Oktober',
              'November',
              'Desember'
            ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  bool _isVoucherExpired(DetailVoucher v) {
    if (v.status == 'expired') return true;
    if (v.status == 'used') return false;
    final now = DateTime.now();
    if (v.expiryDate != null && v.expiryDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(v.expiryDate!);
      if (parsed != null && now.isAfter(parsed)) return true;
    }
    if (v.voucher?.endDate != null && v.voucher!.endDate!.isNotEmpty) {
      final end = DateTime.tryParse(v.voucher!.endDate!);
      if (end != null) {
        final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (now.isAfter(endOfDay)) return true;
      }
    }
    return false;
  }

  Widget _buildMyVouchersTab() {
    final lang = ref.watch(appLanguageProvider);
    final myVouchersAsync = ref.watch(myVouchersProvider);

    return RefreshIndicator(
      color: const Color(0xFFDD2222),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(myVouchersProvider);
      },
      child: myVouchersAsync.when(
        data: (vouchers) {
          final used = vouchers.where((v) => v.status == 'used').toList();
          final expired = vouchers.where((v) => v.status != 'used' && _isVoucherExpired(v)).toList();
          final active = vouchers.where((v) {
            if (v.status == 'used') return false;
            if (_isVoucherExpired(v)) return false;
            if (v.purchaseType == 'cash' && v.paymentStatus == 'pending') {
              return false;
            }
            return true;
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Summary Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: _buildStatusSummary(active.length,
                            tr.get('active_now', lang), Colors.green)),
                    Expanded(
                        child: _buildStatusSummary(used.length,
                            tr.get('already_used', lang), Colors.grey)),
                    if (expired.isNotEmpty)
                      Expanded(
                          child: _buildStatusSummary(expired.length,
                              tr.get('expired_voucher', lang), Colors.red.shade400)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (active.isNotEmpty)
                _buildMyVoucherSection(
                    tr.get('active_now', lang), active.length, active),
              if (used.isNotEmpty)
                _buildMyVoucherSection(
                    tr.get('already_used', lang), used.length, used),
              if (expired.isNotEmpty)
                _buildMyVoucherSection(
                    tr.get('expired_voucher', lang), expired.length, expired),

              if (vouchers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(tr.get('no_my_vouchers', lang),
                        style: const TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
              '${tr.get('something_went_wrong', ref.read(appLanguageProvider))}: $err'),
        ),
      ),
    );
  }

  Widget _buildStatusSummary(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMyVoucherSection(
      String title, int count, List<DetailVoucher> vouchers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        ...vouchers.map((v) => _buildMyVoucherCard(v)),
      ],
    );
  }

  Widget _buildMyVoucherCard(DetailVoucher detailVoucher) {
    final voucher = detailVoucher.voucher!;
    final isExpired = _isVoucherExpired(detailVoucher);
    final isUsed = detailVoucher.status == 'used';
    final isPendingActivation = !isUsed &&
        !isExpired &&
        (detailVoucher.status == 'pending_activation' ||
            (voucher.requiresActivation && detailVoucher.status != 'active'));
    final isDimmed = isUsed || isExpired;

    return Opacity(
      opacity: isDimmed ? 0.45 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDimmed ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
        ),
        color: isDimmed ? const Color(0xFFF8FAFC) : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isExpired ? null : () => _showVoucherCodeSheet(detailVoucher),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildThematicVoucherLeading(voucher),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris 1: Nama Voucher (tanpa badge teks berwarna)
                      Text(
                        voucher.voucherName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDimmed
                              ? const Color(0xFF64748B)
                              : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Baris 2: Nama Brand - s.d End Date
                      Text(
                        '${voucher.displayBrandName}${voucher.endDate != null && voucher.endDate!.isNotEmpty ? ' - ${tr.get('valid_until_short', ref.watch(appLanguageProvider))} ${_formatDateHeader(voucher.endDate, ref.watch(appLanguageProvider))}' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDimmed ? Colors.grey[500] : const Color(0xFF1E293B),
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        voucher.getBenefitSummary(ref.watch(appLanguageProvider)),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDimmed ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isPendingActivation) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                size: 11.5, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              tr.get('scan_table_qr_activate', ref.watch(appLanguageProvider)),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDimmed ? Colors.grey[350] : Colors.grey[400],
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(String? dateStr, AppLanguage lang) {
    if (dateStr == null) return tr.get('no_expiry', lang);
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = lang == AppLanguage.english
          ? [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December'
            ]
          : [
              'Januari',
              'Februari',
              'Maret',
              'April',
              'Mei',
              'Juni',
              'Juli',
              'Agustus',
              'September',
              'Oktober',
              'November',
              'Desember'
            ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final minute = date.minute.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      return '$hour:$minute WIB';
    } catch (e) {
      return '';
    }
  }

  String _formatNumber(int number) {
    final s = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  Widget _buildGoldPointBadge({double size = 18}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFF1C40F), Color(0xFFF39C12)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Map<String, dynamic> _getItemDisplayDetails(
      PointHistory item, AppLanguage lang) {
    final desc = item.description?.toLowerCase() ?? '';
    final signedPoints = item.signedPoints;

    IconData iconData = Icons.stars;
    Color bgColor = const Color(0xFFE8F5E9);
    Color iconColor = const Color(0xFF2E7D32);
    String title = tr.get('tx_incoming_points', lang);
    String subtitle = item.description ?? '';

    if (signedPoints < 0) {
      title = tr.get('tx_redeem_voucher', lang);
      iconData = Icons.confirmation_number_outlined;
      bgColor = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFC62828);

      if (desc.contains('redeemed voucher:')) {
        final index =
            item.description!.toLowerCase().indexOf('redeemed voucher:');
        subtitle = item.description!
            .substring(index + 'redeemed voucher:'.length)
            .trim();
      }
    } else {
      if (desc.contains('order') || desc.contains('pembelian')) {
        title = tr.get('tx_purchase_success', lang);
        iconData = Icons.shopping_bag_outlined;
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);

        final orderRegExp =
            RegExp(r'(ord-[0-9a-zA-Z-]+)', caseSensitive: false);
        final match = orderRegExp.firstMatch(desc);
        if (match != null) {
          subtitle = 'Order ID: ${match.group(0)?.toUpperCase()}';
        }
      } else if (desc.contains('daily') ||
          desc.contains('harian') ||
          desc.contains('login')) {
        title = tr.get('tx_daily_bonus', lang);
        iconData = Icons.workspace_premium_outlined;
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        subtitle = tr.get('tx_daily_login', lang);
      } else if (desc.contains('game') ||
          desc.contains('spin') ||
          desc.contains('win')) {
        title = tr.get('tx_play_game', lang);
        iconData = Icons.sports_esports_outlined;
        bgColor = const Color(0xFFF3E5F5);
        iconColor = const Color(0xFF6A1B9A);
      } else if (desc.contains('misi') || desc.contains('mission')) {
        title = tr.get('tx_mission_completed', lang);
        iconData = Icons.card_giftcard_outlined;
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFE65100);
      } else if (desc.contains('manual bonus')) {
        title = tr.get('tx_bonus_points', lang);
        iconData = Icons.stars_outlined;
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        subtitle = tr.get('tx_admin_bonus', lang);
      }
    }

    return {
      'icon': iconData,
      'bgColor': bgColor,
      'iconColor': iconColor,
      'title': title,
      'subtitle': subtitle,
    };
  }

  Map<int, int> _getPointHistoryBalances(
      List<PointHistory> history, int currentPoints) {
    final Map<int, int> balancesMap = {};
    int balance = currentPoints;
    for (int i = 0; i < history.length; i++) {
      balancesMap[history[i].id] = balance;
      balance -= history[i].signedPoints;
    }
    return balancesMap;
  }

  int _calculateTotalEarned(List<PointHistory> history) {
    return history
        .where((item) => item.signedPoints > 0)
        .fold(0, (sum, item) => sum + item.signedPoints);
  }

  int _calculateTotalUsed(List<PointHistory> history) {
    return history
        .where((item) => item.signedPoints < 0)
        .fold(0, (sum, item) => sum + item.signedPoints.abs());
  }

  Widget _buildPointsHistoryTab() {
    final lang = ref.watch(appLanguageProvider);
    final pointsHistoryAsync = ref.watch(pointsHistoryProvider);
    final userPointsAsync = ref.watch(userPointsProvider);
    final points = userPointsAsync.value ?? 0;

    return RefreshIndicator(
      color: const Color(0xFFDD2222),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(pointsHistoryProvider);
        ref.invalidate(userPointsProvider);
      },
      child: pointsHistoryAsync.when(
        data: (history) {
          final totalEarned = _calculateTotalEarned(history);
          final totalUsed = _calculateTotalUsed(history);
          final balancesMap = _getPointHistoryBalances(history, points);

          // Apply filters and sorting
          List<PointHistory> filteredHistory = history;
          if (_selectedTypeFilter == 'earned' ||
              _selectedTypeFilter == 'Poin Didapat') {
            filteredHistory =
                filteredHistory.where((item) => item.signedPoints > 0).toList();
          } else if (_selectedTypeFilter == 'used' ||
              _selectedTypeFilter == 'Poin Digunakan') {
            filteredHistory =
                filteredHistory.where((item) => item.signedPoints < 0).toList();
          }

          // Sort copy
          filteredHistory = List.from(filteredHistory);
          filteredHistory.sort((a, b) {
            final dateA = a.createdAt != null
                ? DateTime.tryParse(a.createdAt!) ?? DateTime(1970)
                : DateTime(1970);
            final dateB = b.createdAt != null
                ? DateTime.tryParse(b.createdAt!) ?? DateTime(1970)
                : DateTime(1970);
            if (_selectedSortOrder == 'newest' ||
                _selectedSortOrder == 'Terbaru') {
              return dateB.compareTo(dateA);
            } else {
              return dateA.compareTo(dateB);
            }
          });

          // Group by Date for rendering
          final List<Widget> groupedWidgets = [];

          if (filteredHistory.isEmpty) {
            groupedWidgets.add(
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      tr.get('no_point_history', lang),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final Map<String, List<PointHistory>> grouped = {};
            for (final item in filteredHistory) {
              final dateStr = _formatDateHeader(item.createdAt, lang);
              if (!grouped.containsKey(dateStr)) {
                grouped[dateStr] = [];
              }
              grouped[dateStr]!.add(item);
            }

            grouped.forEach((dateStr, items) {
              groupedWidgets.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );

              for (final item in items) {
                final details = _getItemDisplayDetails(item, lang);
                final balance = balancesMap[item.id] ?? 0;
                final isPositive = item.signedPoints >= 0;

                groupedWidgets.add(
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: details['bgColor'] as Color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          details['icon'] as IconData,
                          color: details['iconColor'] as Color,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        details['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            details['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(item.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isPositive
                                        ? '+${_formatNumber(item.signedPoints)}'
                                        : '-${_formatNumber(item.signedPoints.abs())}',
                                    style: TextStyle(
                                      color: isPositive
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr.get('points_balance_label', lang).replaceAll(
                                    '{balance}', _formatNumber(balance)),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            });
          }

          final typeFilterItems = [
            {'key': 'all', 'label': tr.get('filter_all_transactions', lang)},
            {'key': 'earned', 'label': tr.get('filter_points_earned', lang)},
            {'key': 'used', 'label': tr.get('filter_points_used', lang)},
          ];

          final sortOrderItems = [
            {'key': 'newest', 'label': tr.get('sort_newest', lang)},
            {'key': 'oldest', 'label': tr.get('sort_oldest', lang)},
          ];

          final currentTypeKey = (_selectedTypeFilter == 'Poin Didapat' ||
                  _selectedTypeFilter == 'earned')
              ? 'earned'
              : (_selectedTypeFilter == 'Poin Digunakan' ||
                      _selectedTypeFilter == 'used')
                  ? 'used'
                  : 'all';

          final currentSortKey = (_selectedSortOrder == 'Terlama' ||
                  _selectedSortOrder == 'oldest')
              ? 'oldest'
              : 'newest';

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Red Header Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE52D27), Color(0xFFB31217)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB31217).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Total Poin Saya
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showPointTermsDialog,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tr.get('my_total_points', lang),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 13.5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  points.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildGoldPointBadge(size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right: White sub-card for Poin Didapat & Poin Digunakan (tanpa kata Total)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Poin Didapat
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr.get('filter_points_earned', lang),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '+${_formatNumber(totalEarned)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Vertical Divider
                          Container(
                            height: 26,
                            width: 1,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          // Poin Digunakan
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr.get('filter_points_used', lang),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '-${_formatNumber(totalUsed)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFC62828),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tips Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showPointTermsDialog,
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr.get('points_rate_note', lang),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filters and Sorting dropdowns
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentTypeKey,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: typeFilterItems.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['key']!,
                                child: Text(item['label']!),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTypeFilter = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentSortKey,
                            icon: const Icon(Icons.filter_list,
                                color: Colors.grey, size: 18),
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: sortOrderItems.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['key']!,
                                child: Text(item['label']!),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedSortOrder = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grouped transaction items
              ...groupedWidgets,

              // Bottom Policy Card
              _buildBottomPolicyCard(lang),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
              '${tr.get('something_went_wrong', ref.read(appLanguageProvider))}: $err'),
        ),
      ),
    );
  }

  Widget _buildBottomPolicyCard(AppLanguage lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr.get('points_expiry_policy', lang),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _showPointTermsDialog,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr.get('see_terms_and_conditions', lang),
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.red[700],
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPointTermsDialog() {
    final lang = ref.read(appLanguageProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          tr.get('point_terms_title', lang),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('- ${tr.get('point_terms_earned', lang)}'),
            const SizedBox(height: 8),
            Text('- ${tr.get('point_terms_subtotal', lang)}'),
            const SizedBox(height: 8),
            Text('- ${tr.get('point_terms_rate', lang)}'),
            const SizedBox(height: 8),
            Text('- ${tr.get('point_terms_redeem', lang)}'),
            const SizedBox(height: 8),
            Text('- ${tr.get('point_terms_expiry', lang)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr.get('understand', lang),
              style: const TextStyle(color: Color(0xFFDD2222)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(Voucher voucher, String type) {
    final lang = ref.read(appLanguageProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'free'
            ? tr.get('claim_free_voucher', lang)
            : tr.get('redeem_points', lang)),
        content: Text(type == 'free'
            ? tr
                .get('claim_voucher_confirm', lang)
                .replaceAll('{name}', voucher.voucherName)
            : tr
                .get('redeem_points_confirm', lang)
                .replaceAll('{points}', voucher.point.toString())
                .replaceAll('{name}', voucher.voucherName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr.get('cancel', lang),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222)),
            onPressed: () async {
              Navigator.pop(dialogContext); // close dialog
              try {
                await ref
                    .read(voucherActionsProvider.notifier)
                    .redeemVoucherWithPoints(voucher.id);
                ref.invalidate(categorizedVouchersProvider);
                ref.invalidate(myVouchersProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(type == 'free'
                          ? tr.get('free_voucher_claimed', lang)
                          : tr.get('voucher_redeemed_success', lang)),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                final errorMsg = e.toString().toLowerCase();
                String displayMsg;
                if (errorMsg.contains('unauthenticated')) {
                  displayMsg = lang == AppLanguage.english
                      ? 'Your login session has expired. Please log in again.'
                      : 'Sesi login Anda telah berakhir. Silakan login kembali.';
                } else if (errorMsg.contains('already redeemed') ||
                    errorMsg.contains('already claimed')) {
                  displayMsg = tr.get('voucher_duplicate_claimed', lang);
                } else {
                  displayMsg = '${tr.get('something_went_wrong', lang)}: $e';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(displayMsg),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: Text(tr.get('yes_continue', lang),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoucherCodeSheet(DetailVoucher detailVoucher) async {
    final lang = ref.read(appLanguageProvider);
    final voucher = detailVoucher.voucher!;
    final isPendingActivation = detailVoucher.status == 'pending_activation' ||
        (voucher.requiresActivation &&
            detailVoucher.status != 'active' &&
            detailVoucher.status != 'used');

    if (isPendingActivation) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Big Lock Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 44,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                voucher.voucherName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tr.get('brand_label', lang)}: ${voucher.displayBrandName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDD2222),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Text(
                          lang == AppLanguage.indonesia
                              ? 'Voucher Belum Aktif'
                              : 'Voucher Not Activated',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang == AppLanguage.indonesia
                          ? 'Voucher ini sudah tersimpan di akun Anda. Untuk menggunakannya, silakan kunjungi outlet ${voucher.displayBrandName} dan pindai standing banner QR yang diletakkan di meja / kasir gerai.'
                          : 'This voucher is saved in your account. To use it, please visit a ${voucher.displayBrandName} outlet and scan the standing QR banner placed on the table or cashier counter.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (AuthGuard.requireLogin(context, ref, redirectTo: AppRouter.qrScanner)) {
                        context.push(AppRouter.qrScanner);
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Scan QR Meja untuk Aktivasi',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final isUsed = detailVoucher.status == 'used' || detailVoucher.isUsed;
    if (isUsed) {
      // Build Benefit text
      final benefitText = voucher.getBenefitSummary(lang);

      // Format used time
      String usedTimeText = '';
      final rawDate = detailVoucher.lastUsedAt ??
          detailVoucher.purchasedAt ??
          detailVoucher.purchaseDate;
      if (rawDate != null && rawDate.isNotEmpty) {
        try {
          final dt = DateTime.parse(rawDate).toLocal();
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agu',
            'Sep',
            'Okt',
            'Nov',
            'Des'
          ];
          final hour = dt.hour.toString().padLeft(2, '0');
          final minute = dt.minute.toString().padLeft(2, '0');
          usedTimeText =
              '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute WIB';
        } catch (_) {
          usedTimeText = rawDate;
        }
      }
      if (usedTimeText.isEmpty) {
        final now = DateTime.now();
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des'
        ];
        usedTimeText = '${now.day} ${months[now.month - 1]} ${now.year}';
      }

      // Channel text
      final channelText = voucher.usageChannel == 'app_only'
          ? (lang == AppLanguage.indonesia
              ? 'Aplikasi Delitopia'
              : 'Delitopia App')
          : (lang == AppLanguage.indonesia
              ? 'Kasir Gerai ${voucher.displayBrandName}'
              : 'Outlet Cashier ${voucher.displayBrandName}');

      final codeText = detailVoucher.claimCode ?? voucher.code ?? '-';

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        voucher.voucherName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr.get('brand_label', lang)}: ${voucher.displayBrandName}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Receipt Card (DETAIL PENUKARAN)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded,
                                    size: 18, color: Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Text(
                                  lang == AppLanguage.indonesia
                                      ? 'DETAIL PENUKARAN'
                                      : 'REDEMPTION DETAILS',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFFE2E8F0)),
                            _buildReceiptRow(
                                lang == AppLanguage.indonesia ? 'Status' : 'Status',
                                lang == AppLanguage.indonesia ? 'Terpakai' : 'Used',
                                isStatus: true),
                            const SizedBox(height: 10),
                            _buildReceiptRow(
                                lang == AppLanguage.indonesia ? 'Waktu Penukaran' : 'Redeemed At',
                                usedTimeText),
                            const SizedBox(height: 10),
                            _buildReceiptRow(
                                lang == AppLanguage.indonesia ? 'Kode Klaim' : 'Claim Code',
                                codeText,
                                isStrikeThrough: true),
                            const SizedBox(height: 10),
                            _buildReceiptRow(
                                lang == AppLanguage.indonesia ? 'Benefit' : 'Benefit',
                                benefitText),
                            const SizedBox(height: 10),
                            _buildReceiptRow(
                                lang == AppLanguage.indonesia ? 'Saluran Klaim' : 'Channel',
                                channelText),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info Notice Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lang == AppLanguage.indonesia
                                    ? 'Voucher ini telah berhasil digunakan dan tidak dapat ditukarkan kembali.'
                                    : 'This voucher has been used and cannot be redeemed again.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr.get('close', lang),
                      style: const TextStyle(
                          fontWeight: FontWeight.normal, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final showQr = _voucherShouldShowQr(voucher, detailVoucher);
    String? claimCode = showQr ? detailVoucher.claimCode : null;

    if (showQr && (claimCode == null || claimCode.isEmpty)) {
      try {
        final generated = await ref
            .read(pos_service.posServiceProvider)
            .generateClaimCode(detailVoucher.id);
        claimCode = generated?['claim_code']?.toString();
        if (claimCode == null || claimCode.isEmpty) {
          throw Exception(lang == AppLanguage.indonesia
              ? 'Kode klaim tidak tersedia'
              : 'Claim code unavailable');
        }
        ref.invalidate(myVouchersProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${tr.get('voucher_prepare_code_failed', lang)}: $e'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    final displayCode = showQr
        ? (claimCode ?? '')
        : (voucher.code?.trim().isNotEmpty == true
            ? voucher.code!.trim()
            : (detailVoucher.claimCode ?? '-'));

    if (!mounted) return;
    final redeemed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VoucherQrRedemptionSheet(
        detailVoucher: detailVoucher,
        voucher: voucher,
        showQr: showQr,
        displayCode: displayCode,
        lang: lang,
      ),
    );

    if (redeemed == true && mounted) {
      ref.invalidate(pos_service.myVouchersProvider);
      ref.invalidate(myVouchersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang == AppLanguage.indonesia
                      ? 'Voucher telah digunakan & dipindahkan ke Riwayat.'
                      : 'Voucher has been used & moved to History.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  bool _voucherShouldShowQr(Voucher voucher, [DetailVoucher? detailVoucher]) {
    // 1. If voucher is explicitly configured for cashier only or all channels
    if (voucher.isCashierOnly) {
      return true;
    }

    // 2. Physical menu vouchers / redemption benefits (B1G1, Free Menu, Birthday)
    final type = voucher.voucherType.toLowerCase();
    if (type == 'birthday' ||
        type == 'buy_1_get_1' ||
        type == 'free_item' ||
        type == 'free_menu') {
      return true;
    }

    // 3. If usage channel is all, show QR so customer can redeem at cashier or use in app
    if (voucher.usageChannel == 'all') {
      return true;
    }

    return false;
  }

  Widget _buildReceiptRow(String label, String value,
      {bool isStrikeThrough = false,
      Color? valueColor,
      bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: isStatus
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? const Color(0xFF475569),
                    ),
                  ),
                )
              : isStrikeThrough
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFF94A3B8),
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '(Nonaktif)',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: valueColor ?? const Color(0xFF1E293B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _VoucherQrRedemptionSheet extends ConsumerStatefulWidget {
  final DetailVoucher detailVoucher;
  final Voucher voucher;
  final bool showQr;
  final String displayCode;
  final AppLanguage lang;

  const _VoucherQrRedemptionSheet({
    required this.detailVoucher,
    required this.voucher,
    required this.showQr,
    required this.displayCode,
    required this.lang,
  });

  @override
  ConsumerState<_VoucherQrRedemptionSheet> createState() =>
      _VoucherQrRedemptionSheetState();
}

class _VoucherQrRedemptionSheetState
    extends ConsumerState<_VoucherQrRedemptionSheet>
    with SingleTickerProviderStateMixin {
  bool _isRedeemed = false;
  Map<String, dynamic>? _redemptionData;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _countdownSeconds = 3;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    if (widget.showQr) {
      // Start polling every 2 seconds while modal is active
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _checkStatus();
      });
      // Initial check in microtask
      Future.microtask(() => _checkStatus());
    }
  }

  Future<void> _checkStatus() async {
    if (_isRedeemed || !mounted) return;
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(
        '/getData/check-voucher-status',
        queryParameters: {
          'detail_voucher_id': widget.detailVoucher.id,
          if (widget.displayCode.isNotEmpty && widget.displayCode != '-')
            'claim_code': widget.displayCode,
        },
      );
      if (res['status'] == 'success' && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        if (data['is_used'] == true) {
          _onRedeemedSuccess(data);
        }
      }
    } catch (e) {
      debugPrint('Silent voucher check: $e');
    }
  }

  void _onRedeemedSuccess(Map<String, dynamic> data) {
    if (_isRedeemed || !mounted) return;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    setState(() {
      _isRedeemed = true;
      _redemptionData = data;
      _countdownSeconds = 3;
    });

    _animController.forward(from: 0.0);

    // Invalidate providers so lists update in real-time
    ref.invalidate(pos_service.myVouchersProvider);
    ref.invalidate(myVouchersProvider);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final voucher = widget.voucher;
    final showQr = widget.showQr;
    final displayCode = widget.displayCode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isRedeemed
              ? _buildSuccessView(context, voucher)
              : _buildQrView(context, lang, voucher, showQr, displayCode),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, Voucher voucher) {
    final lang = widget.lang;
    final isIndo = lang == AppLanguage.indonesia;
    final outletName = _redemptionData?['outlet_name'] ?? voucher.displayBrandName;
    final benefitText = _redemptionData?['benefit_text'] ??
        (isIndo ? 'Diskon Berhasil Diterapkan' : 'Discount Applied Successfully');
    final usedAt = _redemptionData?['used_at'] ?? (isIndo ? 'Baru saja' : 'Just now');

    return Column(
      key: const ValueKey('success_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 58,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isIndo
                    ? 'Voucher Berhasil Digunakan! 🎟️'
                    : 'Voucher Successfully Used! 🎟️',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isIndo
                    ? "Voucher '${voucher.voucherName}' berhasil ditukarkan di $outletName."
                    : "Voucher '${voucher.voucherName}' successfully redeemed at $outletName.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              // Highlight Benefit / Savings Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎉 ', style: TextStyle(fontSize: 18)),
                    Flexible(
                      child: Text(
                        benefitText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Detail Penukaran Info Box - Waktu Penukaran text removed to prevent overflow
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      usedAt,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Auto-dismiss countdown hint
              Text(
                isIndo
                    ? 'Menutup otomatis dalam $_countdownSeconds detik...'
                    : 'Closing automatically in $_countdownSeconds seconds...',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              // Button Selesai
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      tr.get('done', lang),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrView(
    BuildContext context,
    AppLanguage lang,
    Voucher voucher,
    bool showQr,
    String displayCode,
  ) {
    return Column(
      key: const ValueKey('qr_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    voucher.voucherName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${tr.get('brand_label', lang)}: ${voucher.displayBrandName}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (voucher.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        voucher.description,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                if (showQr) ...[
                  // QR Code Box - Bigger (210px) and clean
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: displayCode,
                      version: QrVersions.auto,
                      size: 210.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  showQr ? tr.get('claim_code', lang) : tr.get('voucher_code', lang),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    displayCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showQr
                      ? '(${tr.get('instruction_show_code', lang)})'
                      : '(${tr.get('use_voucher_at_app', lang)})',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),

                // Instructions (Disesuaikan berdasarkan Saluran Penggunaan Voucher)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (voucher.isCashierOnly) ...[
                        const Row(
                          children: [
                            Icon(Icons.store_mall_directory_rounded,
                                size: 18, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Text(
                              'Cara Penukaran di Kasir Gerai:',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInstructionRow(
                            '1',
                            lang == AppLanguage.indonesia
                                ? 'Kunjungi gerai resmi brand ${voucher.displayBrandName}.'
                                : 'Visit an official ${voucher.displayBrandName} outlet.'),
                        _buildInstructionRow('2', tr.get('instruction_show_code', lang)),
                        _buildInstructionRow('3', tr.get('instruction_cashier_scan', lang)),
                        _buildInstructionRow('4', tr.get('instruction_discount_applied', lang)),
                      ] else if (voucher.isAppOnly) ...[
                        Row(
                          children: [
                            const Icon(Icons.smartphone_rounded,
                                size: 18, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 8),
                            Text(
                              lang == AppLanguage.indonesia
                                  ? 'Cara Penggunaan di Aplikasi:'
                                  : 'How to Use in App:',
                              style: const TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInstructionRow('1', tr.get('instruction_open_cart', lang)),
                        _buildInstructionRow('2', tr.get('instruction_go_checkout', lang)),
                        _buildInstructionRow(
                            '3', tr.get('instruction_choose_checkout_voucher', lang)),
                        _buildInstructionRow(
                            '4',
                            lang == AppLanguage.indonesia
                                ? 'Total pembayaran pesanan Anda otomatis terpotong.'
                                : 'Your order total will automatically be discounted.'),
                      ] else ...[
                        // Semua Saluran (Aplikasi & Kasir Gerai)
                        Row(
                          children: [
                            const Icon(Icons.swap_horiz_rounded,
                                size: 18, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 8),
                            Text(
                              lang == AppLanguage.indonesia
                                  ? 'Saluran Penukaran (Aplikasi & Kasir):'
                                  : 'Redemption Channel (App & Cashier):',
                              style: const TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDualChannelOption(
                          icon: Icons.store_rounded,
                          title: lang == AppLanguage.indonesia
                              ? 'Di Kasir Gerai:'
                              : 'At Store Cashier:',
                          description: lang == AppLanguage.indonesia
                              ? 'Tunjukkan kode QR atau sebutkan kode klaim ke kasir saat memesan di toko.'
                              : 'Show the QR code or provide the claim code to the cashier when ordering in-store.',
                        ),
                        const SizedBox(height: 8),
                        _buildDualChannelOption(
                          icon: Icons.shopping_bag_outlined,
                          title: lang == AppLanguage.indonesia
                              ? 'Di Aplikasi Delitopia:'
                              : 'In Delitopia App:',
                          description: lang == AppLanguage.indonesia
                              ? 'Pilih voucher ini pada halaman Checkout saat memesan di aplikasi'
                              : 'Select this voucher on the Checkout page when ordering in the app',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDD2222),
                      side: const BorderSide(color: Color(0xFFDD2222)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: displayCode == '-'
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: displayCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr.get('voucher_code_copied', lang)),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                    child: Text(
                      tr.get('copy_code', lang),
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr.get('close', lang),
                      style: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: TextStyle(color: Colors.blue[900], fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDualChannelOption({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.blue[900],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
