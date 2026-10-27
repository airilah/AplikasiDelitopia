import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delitopia_v2/src/core/localization/app_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_model.dart';
import '../../profile/controllers/address_controller.dart';
import '../../profile/views/address_list_view.dart';
import '../../profile/models/address_model.dart';
import '../../voucher/controllers/voucher_controller.dart'
    as voucher_controller;
import '../../order/controllers/order_controller.dart';
import '../../order/models/order_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import '../../payment/views/cash_payment_view.dart';
import '../../../shared/models/branch_model.dart';
import '../../../shared/services/service_providers.dart';
import '../services/grab_delivery_service.dart';
import '../models/delivery_quote.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/models/app_version_info.dart';
import '../../../core/widgets/app_maintenance_dialog.dart';
import '../widgets/voucher_selection_bottom_sheet.dart';
import '../../voucher/models/voucher_model.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../shared/models/table_session_model.dart';

class CheckoutView extends ConsumerStatefulWidget {
  const CheckoutView({super.key});

  @override
  ConsumerState<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends ConsumerState<CheckoutView> {
  String _orderType = 'dine_in';
  String _paymentMethod = 'qris';
  final _tableNumberController = TextEditingController(text: '');
  final _notesController = TextEditingController();
  int? _selectedAddressId;
  int? _selectedVoucherId;
  double? _selectedVoucherDiscount;
  bool _userManuallyDeselectedVoucher = false;
  bool _isPlacingOrder = false;
  bool _isOrderItemsExpanded = false;

  String? _tempDeliveryAddress;
  String? _tempDeliveryLabel;
  String? _tempDeliveryNotes;
  double? _tempDeliveryLat;
  double? _tempDeliveryLong;

  DeliveryQuote? _selectedDeliveryQuote;
  bool _isLoadingQuote = false;
  double? _deliveryDistance;
  final _grabService = GrabDeliveryService();

  @override
  void initState() {
    super.initState();
    final tableSession = ref.read(tableSessionProvider);
    if (tableSession != null && tableSession.tableNumber.isNotEmpty) {
      _orderType = 'dine_in';
      _tableNumberController.text = tableSession.tableNumber;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appMaintenanceProvider.notifier).fetchMaintenance();
    });
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _changeDeliveryAddress() async {
    final selected = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (ctx) => const AddressListView(selectionMode: true)));
    if (selected != null && mounted) {
      setState(() {
        _selectedAddressId = selected.id;
        _tempDeliveryAddress = selected.address;
        _tempDeliveryLabel = selected.label;
        _tempDeliveryNotes = selected.notes;
        _tempDeliveryLat = selected.latitude;
        _tempDeliveryLong = selected.longitude;
        _selectedDeliveryQuote = null;
        _deliveryDistance = null;
      });
      await _fetchDeliveryQuote();
    }
  }

  Future<void> _fetchDeliveryQuote() async {
    if (_tempDeliveryLat == null || _tempDeliveryLong == null) return;
    setState(() => _isLoadingQuote = true);
    try {
      final lang = ref.read(appLanguageProvider);
      final branch = ref.read(selectedBranchProvider);
      if (branch == null) throw Exception(tr.get('select_branch_first', lang));
      final origin = DeliveryAddress(
        latitude: branch.latitude,
        longitude: branch.longitude,
        address: branch.address ?? 'Restaurant');
      final destination = DeliveryAddress(
        latitude: _tempDeliveryLat!,
        longitude: _tempDeliveryLong!,
        address: _tempDeliveryAddress ?? tr.get('delivery_location', lang));
      final distance = _grabService.calculateDistance(
        lat1: branch.latitude, lon1: branch.longitude,
        lat2: _tempDeliveryLat!, lon2: _tempDeliveryLong!);
      final quotes = await _grabService.getDeliveryQuote(
        origin: origin, destination: destination, branchId: branch.id);
      if (quotes.isNotEmpty && mounted) {
        setState(() {
          final quote = quotes.first;
          _selectedDeliveryQuote = quote;
          // Gunakan jarak jalan raya dari Grab jika ada; jika tidak, gunakan estimasi rute jalan (faktor 1.55x dari garis lurus)
          _deliveryDistance = quote.distanceInKm ?? (distance * 1.55);

          // Recalculate delivery voucher discount if one is selected
          if (_selectedVoucherId != null) {
            final activeVouchersVal = ref.read(voucher_controller.myVouchersByStatusProvider('active'));
            activeVouchersVal.whenData((vouchers) {
              try {
                final dv = vouchers.firstWhere((v) => v.id == _selectedVoucherId);
                final voucher = dv.voucher;
                if (voucher != null && voucher.voucherType.toLowerCase() == 'free_delivery') {
                  final deliveryFee = _selectedDeliveryQuote?.amount ?? 0.0;
                  if (voucher.discountAmount != null && voucher.discountAmount! > 0) {
                    _selectedVoucherDiscount = voucher.discountAmount! > deliveryFee ? deliveryFee : voucher.discountAmount!;
                  } else {
                    _selectedVoucherDiscount = deliveryFee;
                  }
                }
              } catch (_) {}
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final lang = ref.read(appLanguageProvider);
        Helpers.showSnackbar(
          context,
          '${tr.get('delivery_rate_failed', lang)}: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingQuote = false);
    }
  }

  Widget _buildDeliveryQuoteCard(AppLanguage lang) {
    if (_isLoadingQuote) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD2222))),
          const SizedBox(width: 10),
          Text(tr.get('calculating_grab_fee', lang),
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]));
    }
    if (_selectedDeliveryQuote != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B14F).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF00B14F), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Grab Delivery',
                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      tr.get('available', lang),
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.get('service_type', lang),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDeliveryQuote!.serviceType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_deliveryDistance != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.get('distance', lang),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_deliveryDistance!.toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.get('eta', lang),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedDeliveryQuote!.estimatedTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang == AppLanguage.indonesia ? 'Biaya Pengiriman' : 'Delivery Fee',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _selectedDeliveryQuote!.formattedAmount,
                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          tr.get('grab_rate_unavailable', lang),
          style: TextStyle(color: Colors.orange[800], fontSize: 11.5))),
        TextButton(
          onPressed: _fetchDeliveryQuote,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(lang == AppLanguage.indonesia ? 'Coba' : 'Retry',
            style: const TextStyle(fontSize: 11.5))),
      ]));
  }

  Widget _buildNoAddressCard(AppLanguage lang) {
    return GestureDetector(
      onTap: _changeDeliveryAddress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDD2222).withValues(alpha: 0.35), width: 1.2)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_location_alt_outlined, color: Color(0xFFDD2222), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.get('select_delivery_address', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDD2222), fontSize: 13)),
            const SizedBox(height: 2),
            Text(tr.get('tap_select_saved_address', lang),
              style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
          ])),
          const Icon(Icons.chevron_right, color: Color(0xFFDD2222), size: 18),
        ])));
  }

  Widget _buildSectionHeader(String title, {String? optionalBadge, Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.1,
          ),
        ),
        if (optionalBadge != null) ...[
          const SizedBox(width: 5),
          Text(
            optionalBadge,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
            ),
          ),
        ],
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildOrderItemsPreviewCard(Cart cart, AppLanguage lang) {
    if (cart.items.isEmpty) return const SizedBox.shrink();

    final isEn = lang == AppLanguage.english;
    final displayItems = _isOrderItemsExpanded || cart.items.length <= 2
        ? cart.items
        : cart.items.take(2).toList();
    final remainingCount = cart.items.length - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isEn ? 'Order Items' : 'Item Pesanan',
          optionalBadge: '(${cart.itemCount} ${isEn ? 'items' : 'item'})',
          trailing: TextButton.icon(
            onPressed: () => context.go('/navigation?index=2'),
            icon: const Icon(Icons.edit_outlined, size: 13),
            label: Text(
              isEn ? 'Edit' : 'Ubah',
              style: const TextStyle(fontSize: 11.5),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDD2222),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...displayItems.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedImage(
                    imageUrl: item.menuImage ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fastfood_rounded,
                        size: 24,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.menuName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatRupiah(item.price * item.quantity),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDD2222),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (cart.items.length > 2)
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isOrderItemsExpanded = !_isOrderItemsExpanded;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isOrderItemsExpanded
                          ? (isEn ? 'Show less' : 'Tampilkan lebih sedikit')
                          : (isEn ? 'See $remainingCount more items' : 'Lihat $remainingCount menu lainnya'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isOrderItemsExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: const Color(0xFFDD2222),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedVoucherCard({
    required DetailVoucher detailVoucher,
    required double discountAmount,
    required AppLanguage lang,
    required VoidCallback onTap,
  }) {
    final v = detailVoucher.voucher;
    final isId = lang == AppLanguage.indonesia;
    final voucherName =
        v?.voucherName ?? (isId ? 'Voucher Diskon' : 'Discount Voucher');
    final minSpend = v?.minSpend ?? 0.0;
    final minSpendText = minSpend > 0
        ? '${isId ? "Min. belanja " : "Min. spend "}${_formatRupiah(minSpend)}'
        : '';
    final discountFormatted = _formatRupiah(discountAmount);
    final benefitText = isId ? 'Hemat $discountFormatted' : 'Save $discountFormatted';
    final subtitle = minSpendText.isNotEmpty
        ? '$benefitText • $minSpendText'
        : benefitText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFCCCC), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                v?.voucherType.toLowerCase() == 'free_delivery'
                    ? Icons.delivery_dining_rounded
                    : Icons.confirmation_number_outlined,
                color: const Color(0xFFDD2222),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDD2222),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isId ? 'Ubah' : 'Change',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDD2222),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: Color(0xFFDD2222),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVoucherCard(AppLanguage lang, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFF94A3B8),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == AppLanguage.indonesia
                        ? 'Tidak Ada Voucher Terpakai'
                        : 'No Vouchers Applied',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang == AppLanguage.indonesia
                        ? 'Belum ada voucher yang dapat digunakan untuk pesanan ini'
                        : 'No vouchers applicable for this order',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang == AppLanguage.indonesia ? 'Cari' : 'Browse',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDD2222),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: Color(0xFFDD2222),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _checkAndAutoApplyBestVoucher({
    required List<DetailVoucher> vouchers,
    required double cartSubtotal,
    required double deliveryFee,
    required int? currentBrandId,
  }) {
    if (_userManuallyDeselectedVoucher) return;
    if (_selectedVoucherId != null) return;

    DetailVoucher? bestVoucher;
    double bestDiscount = 0.0;

    for (final dv in vouchers) {
      final v = dv.voucher;
      if (v == null || v.isExpired) continue;

      final channel = v.usageChannel.toLowerCase();
      final type = v.voucherType.toLowerCase();
      if (channel == 'cashier_only' ||
          type == 'buy_1_get_1' ||
          type == 'free_menu' ||
          type == 'free_item') {
        continue;
      }

      final brandMatches = (v.brandId == null || v.brandId == 0) ||
          (currentBrandId != null && v.brandId == currentBrandId);
      if (!brandMatches) continue;

      if (type == 'free_delivery' && _orderType != 'delivery') continue;

      if (cartSubtotal < (v.minSpend ?? 0.0)) continue;

      double discount = 0.0;
      if (type == 'free_delivery') {
        if (v.discountAmount != null && v.discountAmount! > 0) {
          discount = v.discountAmount! > deliveryFee ? deliveryFee : v.discountAmount!;
        } else {
          discount = deliveryFee;
        }
      } else if (v.discountAmount != null && v.discountAmount! > 0) {
        discount = v.discountAmount!;
      } else if (v.discountPercentage != null && v.discountPercentage! > 0) {
        final raw = cartSubtotal * (v.discountPercentage! / 100);
        final maxCap = v.maxDiscountAmount;
        if (maxCap != null && maxCap > 0) {
          discount = raw > maxCap ? maxCap : raw;
        } else {
          discount = raw;
        }
      }

      if (discount > bestDiscount) {
        bestDiscount = discount;
        bestVoucher = dv;
      }
    }

    if (bestVoucher != null && bestDiscount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedVoucherId == null && !_userManuallyDeselectedVoucher) {
          setState(() {
            _selectedVoucherId = bestVoucher!.id;
            _selectedVoucherDiscount = bestDiscount;
          });
        }
      });
    }
  }

  void _openVoucherBottomSheet({
    required List<DetailVoucher> userVouchers,
    required int? currentBrandId,
    String? currentBrandName,
    required double cartSubtotal,
    required double deliveryFee,
    required AppLanguage lang,
  }) {
    VoucherSelectionBottomSheet.show(
      context: context,
      userVouchers: userVouchers,
      currentBrandId: currentBrandId,
      currentBrandName: currentBrandName,
      cartSubtotal: cartSubtotal,
      deliveryFee: deliveryFee,
      orderType: _orderType,
      selectedVoucherId: _selectedVoucherId,
      lang: lang,
      onSelectVoucher: (selectedDv, discount) {
        setState(() {
          if (selectedDv == null) {
            _userManuallyDeselectedVoucher = true;
            _selectedVoucherId = null;
            _selectedVoucherDiscount = null;
          } else {
            _userManuallyDeselectedVoucher = false;
            _selectedVoucherId = selectedDv.id;
            _selectedVoucherDiscount = discount;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);
    final vouchersAsync = ref.watch(voucher_controller.myVouchersByStatusProvider('active'));
    final currentUserAsync = ref.watch(currentUserProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=2',
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(backRoute: '/navigation?index=2', color: Colors.white),
              title: Text(tr.get('checkout', lang), style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFFDD2222),
              foregroundColor: Colors.white),
            body: cartAsync.when(
          skipLoadingOnRefresh: true,
          data: (cart) {
            if (cart.items.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(tr.get('cart_empty', lang)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/navigation?index=1'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD2222)),
                  child: Text(tr.get('browse_menu', lang), style: const TextStyle(color: Colors.white))),
              ]));
            }
            if (currentUserAsync.isLoading && !currentUserAsync.hasValue) {
              return const Center(child: CircularProgressIndicator());
            }
            if (currentUserAsync.hasError && (currentUserAsync.value == null || !_hasVerifiedPhone(currentUserAsync.value))) {
              return _buildNetworkErrorState(lang);
            }
            if (!_hasVerifiedPhone(currentUserAsync.asData?.value ?? currentUserAsync.value)) {
              return _buildPhoneRequiredState(lang);
            }
            final deliveryFee = _orderType == 'delivery' ? (_selectedDeliveryQuote?.amount ?? 0.0) : 0.0;
            final currentCartTotal = cart.total - (_selectedVoucherDiscount ?? 0) + deliveryFee;
            final isQrisBelowMin = currentCartTotal < 15000;

            if (isQrisBelowMin && _orderType == 'dine_in' && _paymentMethod == 'qris') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _orderType == 'dine_in' && _paymentMethod == 'qris') {
                  setState(() => _paymentMethod = 'cash');
                }
              });
            }

            return ListView(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), children: [
              // Order Type
              _buildSectionHeader(tr.get('order_type', lang)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildOrderTypeCard('dine_in', tr.get('order_type_dine_in', lang), Icons.restaurant, isQrisBelowMin)),
                const SizedBox(width: 8),
                Expanded(child: _buildOrderTypeCard('take_away', tr.get('order_type_take_away', lang), Icons.shopping_bag_outlined, isQrisBelowMin)),
                const SizedBox(width: 8),
                Expanded(child: _buildOrderTypeCard('delivery', tr.get('order_type_delivery', lang), Icons.delivery_dining, isQrisBelowMin)),
              ]),
              _buildOrderEstimationPreviewCard(lang, cart.items),
              const SizedBox(height: 14),
              // Table Number
              if (_orderType == 'dine_in') ...[
                Builder(builder: (context) {
                  final tableSession = ref.watch(tableSessionProvider);
                  final isLocked = tableSession != null &&
                      tableSession.isLockedFromQr &&
                      tableSession.tableNumber.isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        tr.get('table_number', lang),
                        trailing: isLocked
                            ? TextButton.icon(
                                onPressed: () async {
                                  final confirmed = await AppDialog.showConfirm(
                                    context: context,
                                    title: tr.get('change_table_session_title', lang),
                                    message: tr.get('change_table_session_confirm', lang),
                                    confirmText: tr.get('yes_change', lang, fallback: 'Ya, Ganti'),
                                    cancelText: tr.get('cancel', lang),
                                    type: AppDialogType.danger,
                                    showIcon: false,
                                  );
                                  if (confirmed) {
                                    if (!context.mounted) return;
                                    ref.read(tableSessionProvider.notifier).state = null;
                                    _tableNumberController.clear();
                                    context.push(AppRouter.qrScanner);
                                  }
                                },
                                icon: const Icon(Icons.swap_horiz, size: 13),
                                label: Text(
                                  tr.get('btn_change', lang),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDD2222),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isLocked
                            ? () {
                                AppDialog.showAlert(
                                  context: context,
                                  title: tr.get('table_locked_alert_title', lang),
                                  message: tr.get('table_locked_alert_desc', lang),
                                  buttonText: tr.get('understand_button', lang, fallback: 'Mengerti'),
                                  buttonColor: const Color(0xFFDD2222),
                                  showIcon: false,
                                  type: AppDialogType.info,
                                );
                              }
                            : null,
                        child: IgnorePointer(
                          ignoring: isLocked,
                        child: TextField(
                          controller: _tableNumberController,
                          readOnly: isLocked,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? const Color(0xFF1E293B) : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: tr.get('enter_table_number', lang),
                            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.table_restaurant, size: 18),
                            suffixIcon: isLocked
                                ? const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF64748B))
                                : null,
                            filled: true,
                            fillColor: isLocked ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isLocked ? const Color(0xFFCBD5E1) : Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isLocked ? const Color(0xFFCBD5E1) : const Color(0xFFDD2222),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ],
                  );
                }),
              ],
              // Delivery Address
              if (_orderType == 'delivery') ...[
                _buildSectionHeader(
                  tr.get('shipping_address', lang),
                  trailing: TextButton.icon(
                    onPressed: _changeDeliveryAddress,
                    icon: const Icon(Icons.swap_horiz, size: 13),
                    label: Text(
                      tr.get('change_address', lang),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDD2222),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_tempDeliveryAddress != null) ...[
                  Card(
                    elevation: 0, color: const Color(0xFFFFF5F5),
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFFFCCCC), width: 1)),
                    child: Padding(padding: const EdgeInsets.all(11),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0E0), borderRadius: BorderRadius.circular(7)),
                          child: const Icon(Icons.location_on, color: Color(0xFFDD2222), size: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_tempDeliveryLabel ?? tr.get('selected_location', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(_tempDeliveryAddress!,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (_tempDeliveryNotes != null && _tempDeliveryNotes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(_tempDeliveryNotes!,
                              style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                          ],
                        ])),
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFDD2222), size: 18),
                      ]))),
                  const SizedBox(height: 8),
                  _buildDeliveryQuoteCard(lang),
                ] else ...[
                  Builder(builder: (ctx) {
                    return addressesAsync.when(
                      data: (addresses) {
                        if (addresses.isNotEmpty && _selectedAddressId == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_selectedAddressId == null && mounted) {
                              final def = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
                              setState(() {
                                _selectedAddressId = def.id;
                                _tempDeliveryAddress = def.address;
                                _tempDeliveryLabel = def.label;
                                _tempDeliveryNotes = def.notes;
                                _tempDeliveryLat = def.latitude;
                                _tempDeliveryLong = def.longitude;
                              });
                              _fetchDeliveryQuote();
                            }
                          });
                        }
                        return _buildNoAddressCard(lang);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _buildNoAddressCard(lang));
                  }),
                ],
                const SizedBox(height: 14),
              ],
              // Order Items Preview
              _buildOrderItemsPreviewCard(cart, lang),
              const SizedBox(height: 14),
              // Vouchers
              _buildSectionHeader(tr.get('vouchers', lang), optionalBadge: '(${tr.get('optional', lang)})'),
              const SizedBox(height: 8),
              vouchersAsync.when(
                data: (vouchers) {
                  final selectedBranch = ref.read(selectedBranchProvider);
                  final currentBrandId = selectedBranch?.brandId;
                  final cartSubtotal = cart.subtotal;

                  // Auto-apply best voucher if user hasn't manually deselected
                  _checkAndAutoApplyBestVoucher(
                    vouchers: vouchers,
                    cartSubtotal: cartSubtotal,
                    deliveryFee: deliveryFee,
                    currentBrandId: currentBrandId,
                  );

                  // Check if currently selected voucher is still valid in active vouchers
                  DetailVoucher? selectedDv;
                  if (_selectedVoucherId != null) {
                    final matched = vouchers.where((dv) => dv.id == _selectedVoucherId);
                    if (matched.isNotEmpty) {
                      selectedDv = matched.first;
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _clearSelectedVoucher();
                      });
                    }
                  }

                  void openSheet() {
                    _openVoucherBottomSheet(
                      userVouchers: vouchers,
                      currentBrandId: currentBrandId,
                      currentBrandName: selectedBranch?.brandName,
                      cartSubtotal: cartSubtotal,
                      deliveryFee: deliveryFee,
                      lang: lang,
                    );
                  }

                  if (selectedDv != null) {
                    return _buildSelectedVoucherCard(
                      detailVoucher: selectedDv,
                      discountAmount: _selectedVoucherDiscount ?? 0.0,
                      lang: lang,
                      onTap: openSheet,
                    );
                  }

                  return _buildNoVoucherCard(lang, onTap: openSheet);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFDD2222)),
                    ),
                  ),
                ),
                error: (_, __) => _buildNoVoucherCard(
                  lang,
                  onTap: () {
                    final selectedBranch = ref.read(selectedBranchProvider);
                    _openVoucherBottomSheet(
                      userVouchers: const [],
                      currentBrandId: selectedBranch?.brandId,
                      currentBrandName: selectedBranch?.brandName,
                      cartSubtotal: cart.subtotal,
                      deliveryFee: deliveryFee,
                      lang: lang,
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              // Payment Method
              _buildSectionHeader(tr.get('payment_method', lang)),
              const SizedBox(height: 8),
              _buildPaymentMethodCard(
                'qris',
                'QRIS',
                Icons.qr_code_scanner,
                tr.get('qris_desc', lang),
                badgeText: isQrisBelowMin ? 'Min. Rp 15.000' : null,
                badgeColor: Colors.orange.shade800,
                isDisabled: isQrisBelowMin,
                onCustomTap: isQrisBelowMin
                    ? () {
                        _showQrisMinAmountSnackbar(currentCartTotal, lang);
                      }
                    : null,
              ),
              if (_orderType == 'dine_in')
                _buildPaymentMethodCard(
                  'cash',
                  tr.get('cash', lang),
                  Icons.payments,
                  tr.get('cash_desc', lang),
                  badgeText: isQrisBelowMin ? (lang == AppLanguage.indonesia ? 'Disarankan' : 'Recommended') : null,
                  badgeColor: Colors.green.shade700,
                ),
              const SizedBox(height: 14),
              // Notes
              _buildSectionHeader(tr.get('order_notes', lang), optionalBadge: '(${tr.get('optional', lang)})'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController, maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: tr.get('add_special_instructions', lang),
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDD2222), width: 1.2)))),
              const SizedBox(height: 14),
              // Order Summary
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildSectionHeader(tr.get('order_summary', lang)),
                    const SizedBox(height: 10),
                    _buildSummaryRow(tr.get('subtotal', lang), cart.subtotal),
                    _buildSummaryRow(tr.get('tax', lang), cart.tax),
                    _buildSummaryRow(tr.get('service', lang), cart.service),
                    if (_orderType == 'delivery' && (_tempDeliveryAddress != null || _selectedAddressId != null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr.get('delivery_fee', lang),
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                            ),
                            if (_isLoadingQuote)
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            else if (_selectedDeliveryQuote != null)
                              Text(
                                _selectedDeliveryQuote!.formattedAmount,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              )
                            else
                              const Text('Rp -', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                    if (_selectedVoucherId != null && _selectedVoucherDiscount != null)
                      _buildSummaryRow(tr.get('voucher_discount', lang), -_selectedVoucherDiscount!, isDiscount: true),
                    Divider(height: 14, color: Colors.grey.shade200),
                    _buildSummaryRow(tr.get('total', lang),
                      cart.total - (_selectedVoucherDiscount ?? 0) +
                          (_orderType == 'delivery' && _selectedDeliveryQuote != null ? _selectedDeliveryQuote!.amount : 0),
                      isTotal: true),
                  ]))),
              const SizedBox(height: 24),
            ]);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text('${tr.get('something_went_wrong', lang)}: ${error.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => ref.refresh(cartProvider), child: Text(tr.get('retry', lang))),
          ]))),
        bottomNavigationBar: cartAsync.when(
          data: (cart) {
            if (cart.items.isEmpty || !_hasVerifiedPhone(currentUserAsync.asData?.value)) {
              return const SizedBox.shrink();
            }

            final maintenance = ref.watch(appMaintenanceProvider);
            final isMaintenance = maintenance?.isActive == true;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))]),
              child: SafeArea(child: ElevatedButton(
                onPressed: _isPlacingOrder
                    ? null
                    : (isMaintenance
                        ? () async {
                            await ref.read(appMaintenanceProvider.notifier).fetchMaintenance();
                            final updated = ref.read(appMaintenanceProvider);
                            if (updated?.isActive == true) {
                              if (context.mounted) {
                                AppMaintenanceDialog.show(context, maintenance: updated!);
                              }
                            } else {
                              _placeOrder(cart);
                            }
                          }
                        : () => _placeOrder(cart)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMaintenance ? const Color(0xFFEA580C) : const Color(0xFFDD2222),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[400]),
                child: _isPlacingOrder
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isMaintenance
                            ? (lang == AppLanguage.indonesia
                                ? 'Pemesanan Dibuka ${maintenance?.launchDate ?? "Desember 2026"}'
                                : 'Ordering Opens ${maintenance?.launchDate ?? "December 2026"}')
                            : tr.get('place_order', lang),
                        style: const TextStyle(fontSize: 14.5, color: Colors.white)))));
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink()),
      ),
      if (_isPlacingOrder)
        PopScope(
          canPop: false,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFDD2222)),
                      const SizedBox(height: 18),
                      Text(
                        lang == AppLanguage.indonesia
                            ? 'Memproses Pesanan Anda...'
                            : 'Processing Your Order...',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang == AppLanguage.indonesia
                            ? 'Mohon tunggu sebentar, jangan menutup aplikasi...'
                            : 'Please wait, do not close the app...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.none,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  ));
  }

  bool _hasVerifiedPhone(dynamic user) {
    final phone = user?.phoneNumber;
    return phone is String && phone.trim().isNotEmpty;
  }

  Widget _buildPhoneRequiredState(AppLanguage lang) {
    return Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD6D6)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 68, height: 68,
            decoration: const BoxDecoration(color: Color(0xFFFFEEEE), shape: BoxShape.circle),
            child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFFDD2222), size: 34)),
          const SizedBox(height: 18),
          Text(tr.get('verify_phone_title', lang), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF242424))),
          const SizedBox(height: 10),
          Text(
            lang == AppLanguage.indonesia
                ? 'Nomor ponsel perlu ditambahkan dan diverifikasi sebelum checkout.'
                : 'Phone number needs to be added and verified before checkout.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: Colors.grey.shade700)),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _openAddPhoneNumber,
            icon: const Icon(Icons.add_call),
            label: Text(tr.get('add_phone_number_btn', lang)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]))));
  }

  Widget _buildNetworkErrorState(AppLanguage lang) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.orange.shade800,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                lang == AppLanguage.indonesia
                    ? 'Koneksi Internet Lemot'
                    : 'Slow Internet Connection',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF242424),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lang == AppLanguage.indonesia
                    ? 'Gagal memuat rincian akun dan checkout karena koneksi tidak stabil.'
                    : 'Failed to load account details and checkout due to unstable connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => ref.invalidate(currentUserProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    lang == AppLanguage.indonesia ? 'Coba Lagi' : 'Retry',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddPhoneNumber() {
    context.go('${AppRouter.addPhoneNumber}?returnTo=${Uri.encodeComponent(AppRouter.checkout)}');
  }

  Widget _buildOrderTypeCard(String value, String label, IconData icon, [bool isQrisBelowMin = false]) {
    final isSelected = _orderType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _orderType = value;
        if (_orderType == 'dine_in') {
          final tableSession = ref.read(tableSessionProvider);
          if (tableSession != null && tableSession.tableNumber.isNotEmpty) {
            _tableNumberController.text = tableSession.tableNumber;
          }
          if (isQrisBelowMin) {
            _paymentMethod = 'cash';
          }
        } else if (_paymentMethod == 'cash') {
          _paymentMethod = 'qris';
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDD2222) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFDD2222) : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFDD2222).withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: isSelected ? Colors.white : Colors.grey[700]),
          const SizedBox(height: 5),
          Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ]),
      ),
    );
  }

  int _resolveItemBaseMinutes(CartItem item) {
    if (item.prepTimeMax != null && item.prepTimeMax! > 0) {
      return item.prepTimeMax!;
    }
    if (item.prepTimeMin != null && item.prepTimeMin! > 0) {
      return item.prepTimeMin!;
    }
    final minMins = item.minPrepMinutes;
    final maxMins = item.maxPrepMinutes;
    if (maxMins > 0) {
      return maxMins;
    }
    if (minMins > 0) {
      return minMins;
    }

    final text = '${item.category ?? ''} ${item.menuName}'.toLowerCase();
    // Pelengkap & Minuman -> 3 menit (Tier 2-4)
    if (text.contains('sambal') || text.contains('saos') || text.contains('nasi putih') || text.contains('mineral') ||
        text.contains('teh') || text.contains('tea') || text.contains('kopi') || text.contains('coffee') ||
        text.contains('drink') || text.contains('juice') || text.contains('jus') || text.contains('es ') ||
        text.contains('milo') || text.contains('cendol') || text.contains('water') || text.contains('ocha')) {
      return 3;
    }
    // Sushi dingin sederhana, toast, dessert -> 6 menit (Tier 5-7)
    if (text.contains('nigiri') || text.contains('gunkan') || text.contains('sashimi') || text.contains('inari') ||
        text.contains('pudding') || text.contains('cake') || text.contains('dessert') || text.contains('toast') || text.contains('roti')) {
      return 6;
    }
    // Dimsum, takoyaki, snack gorengan, maki roll -> 9 menit (Tier 8-10)
    if (text.contains('dimsum') || text.contains('siomay') || text.contains('bakpao') || text.contains('gyoza') ||
        text.contains('takoyaki') || text.contains('fries') || text.contains('kentang') || text.contains('jamur') ||
        text.contains('pisang') || text.contains('maki')) {
      return 9;
    }
    // Sushi roll/mentai/aburi, mie/ramen/udon, nasi goreng/donburi -> 12 menit (Tier 11-14)
    if (text.contains('sushi') || text.contains('roll') || text.contains('volcano') || text.contains('aburi') ||
        text.contains('mentai') || text.contains('ramen') || text.contains('udon') || text.contains('yakisoba') ||
        text.contains('mie') || text.contains('bakso') || text.contains('nasi goreng') || text.contains('yakimeshi') ||
        text.contains('pepper rice') || text.contains('donburi') || text.contains('rice bowl')) {
      return 12;
    }
    // Bento, steak, hotpot, ayam, beef, platter -> 15 menit (Tier >= 15)
    if (text.contains('bento') || text.contains('ayam') || text.contains('lele') || text.contains('steak') ||
        text.contains('hotpot') || text.contains('beef') || text.contains('daging') || text.contains('platter')) {
      return 15;
    }
    return 10;
  }

  int _getIntervalBuffer(int baseMinutes) {
    if (baseMinutes <= 4) return 0;
    if (baseMinutes <= 7) return 1;
    if (baseMinutes <= 10) return 2;
    if (baseMinutes <= 14) return 3;
    if (baseMinutes <= 19) return 4;
    return 5; // 20 - 25 menit ke atas
  }

  (int, int) _calculateCartKitchenPrepRange(List<CartItem> items, String orderType) {
    if (items.isEmpty) return (10, 15);

    // Expand all items into individual portions
    final List<int> allPortions = [];
    for (final item in items) {
      final baseMins = _resolveItemBaseMinutes(item);
      final qty = item.quantity > 0 ? item.quantity : 1;
      for (int i = 0; i < qty; i++) {
        allPortions.add(baseMins);
      }
    }

    if (allPortions.isEmpty) return (10, 15);

    // Sort descending so the bottleneck (longest item) is first
    allPortions.sort((a, b) => b.compareTo(a));

    // Base cooking time is the longest menu item
    int totalMinutes = allPortions.first;

    // Every subsequent portion adds time according to its interval tier (no batch discount)
    for (int i = 1; i < allPortions.length; i++) {
      totalMinutes += _getIntervalBuffer(allPortions[i]);
    }

    // Packaging buffer
    int packagingBuffer = 0; // Dine in
    if (orderType == 'take_away') {
      packagingBuffer = 2; // Box / tas bawa pulang
    } else if (orderType == 'delivery') {
      packagingBuffer = 3; // Kemas rapat delivery
    }
    totalMinutes += packagingBuffer;

    // Cap at reasonable restaurant limit
    totalMinutes = totalMinutes.clamp(3, 60);

    // Derive display range in 5-minute interval windows (e.g. 20 -> 20 - 25, 23 -> 20 - 25, 15 -> 15 - 20)
    if (totalMinutes <= 4) {
      return (3, 5);
    }
    final minTime = (totalMinutes ~/ 5) * 5;
    final maxTime = minTime + 5;

    return (minTime, maxTime);
  }

  Widget _buildOrderEstimationPreviewCard(AppLanguage lang, [List<CartItem> items = const []]) {
    final isEn = lang == AppLanguage.english;
    final isDelivery = _orderType == 'delivery';
    final isTakeAway = _orderType == 'take_away';

    String subtext;

    if (isDelivery) {
      final (prepMin, prepMax) = _calculateCartKitchenPrepRange(items, 'delivery');
      if (_selectedDeliveryQuote != null) {
        final grabMins = _selectedDeliveryQuote!.estimatedTimeMinutes;
        final minTime = (prepMin + grabMins).clamp(15, 180);
        final maxTime = prepMax + grabMins;

        final target = DateTime.now().add(Duration(minutes: maxTime));
        final hh = target.hour.toString().padLeft(2, '0');
        final mm = target.minute.toString().padLeft(2, '0');

        subtext = isEn
            ? 'Estimated completion in $minTime - $maxTime mins, estimated arrival around $hh:$mm.'
            : 'Perkiraan selesai dalam $minTime - $maxTime menit, estimasi tiba sekitar pukul $hh.$mm WIB.';
      } else {
        final minTime = (prepMin + 15).clamp(20, 180);
        final maxTime = prepMax + 25;
        subtext = isEn
            ? 'Estimated completion in $minTime - $maxTime mins once address is selected.'
            : 'Perkiraan selesai dalam $minTime - $maxTime menit setelah alamat dipilih.';
      }
    } else if (isTakeAway) {
      final (minTime, maxTime) = _calculateCartKitchenPrepRange(items, 'take_away');
      final target = DateTime.now().add(Duration(minutes: maxTime));
      final hh = target.hour.toString().padLeft(2, '0');
      final mm = target.minute.toString().padLeft(2, '0');
      subtext = isEn
          ? 'Estimated ready for pick-up in $minTime - $maxTime mins, around $hh:$mm.'
          : 'Perkiraan siap diambil dalam $minTime - $maxTime menit, sekitar pukul $hh.$mm WIB.';
    } else {
      final (minTime, maxTime) = _calculateCartKitchenPrepRange(items, 'dine_in');
      final target = DateTime.now().add(Duration(minutes: maxTime));
      final hh = target.hour.toString().padLeft(2, '0');
      final mm = target.minute.toString().padLeft(2, '0');
      subtext = isEn
          ? 'Estimated ready to serve at table in $minTime - $maxTime mins, around $hh:$mm.'
          : 'Perkiraan siap disajikan di meja dalam $minTime - $maxTime menit, sekitar pukul $hh.$mm WIB.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showEstimationInfoDialog(context, isEn),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFFDD6B20),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isEn ? 'Estimated Order Time' : 'Estimasi Waktu Pesanan',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtext,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color.fromARGB(255, 0, 0, 0),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEstimationInfoDialog(BuildContext context, bool isEn) {
    AppDialog.showAlert(
      context: context,
      title: isEn ? 'Additional Information' : 'Informasi Tambahan',
      message: isEn
          ? 'Estimated time may increase if the outlet experiences a kitchen order queue surge or during rush hours.'
          : 'Estimasi waktu dapat bertambah apabila outlet sedang mengalami lonjakan antrian pesanan dapur atau jam sibuk',
      buttonText: isEn ? 'Got It' : 'Mengerti',
      buttonColor: const Color(0xFFDD2222),
      showIcon: false,
    );
  }

  Widget _buildPaymentMethodCard(
    String value,
    String label,
    IconData icon,
    String description, {
    String? badgeText,
    Color? badgeColor,
    String? warningNote,
    bool isDisabled = false,
    VoidCallback? onCustomTap,
  }) {
    final isSelected = !isDisabled && _paymentMethod == value;
    return GestureDetector(
      onTap: () {
        if (isDisabled) {
          if (onCustomTap != null) onCustomTap();
          return;
        }
        setState(() => _paymentMethod = value);
        if (onCustomTap != null) onCustomTap();
      },
      child: Opacity(
        opacity: isDisabled ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFEBEE)
                : (isDisabled ? const Color(0xFFF8FAFC) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFDD2222) : Colors.grey.shade300,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFDD2222)
                          : (isDisabled ? Colors.grey[200] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : (isDisabled ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isDisabled ? Colors.grey[600] : const Color(0xFF1E293B),
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (badgeColor ?? Colors.orange).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (badgeColor ?? Colors.orange).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor ?? Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle, color: Color(0xFFDD2222), size: 18),
                  if (isDisabled)
                    Icon(Icons.lock_outline_rounded, color: Colors.orange.shade700, size: 18),
                ],
              ),
            if (warningNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 13, color: Colors.orange.shade800),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        warningNote,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12.5,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? const Color(0xFF16A34A) : isTotal ? const Color(0xFF1E293B) : const Color(0xFF475569),
            ),
          ),
          Text(
            '${isDiscount ? "-" : ""}Rp ${amount.abs().toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}',
            style: TextStyle(
              fontSize: isTotal ? 14.5 : 12.5,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal
                  ? const Color(0xFFDD2222)
                  : isDiscount
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrisMinAmountSnackbar(double currentTotal, AppLanguage lang) {
    if (!mounted) return;
    final remaining = (15000 - currentTotal).clamp(0.0, 15000.0);
    final remainingFormatted = remaining.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.'
    );
    Helpers.showSnackbar(
      context,
      lang == AppLanguage.indonesia
          ? 'Kurang Rp $remainingFormatted untuk menggunakan pembayaran QRIS'
          : 'Need Rp $remainingFormatted more to use QRIS payment',
      backgroundColor: Colors.orange,
    );
  }

  Future<void> _placeOrder(dynamic cart) async {
    if (_isPlacingOrder) return;

    final currentMaintenance = ref.read(appMaintenanceProvider);
    if (currentMaintenance?.isActive == true) {
      // Re-verifikasi ke server barangkali admin baru saja menonaktifkan maintenance
      await ref.read(appMaintenanceProvider.notifier).fetchMaintenance();
      final rechecked = ref.read(appMaintenanceProvider);
      if (rechecked?.isActive == true) {
        if (mounted) {
          AppMaintenanceDialog.show(context, maintenance: rechecked!);
        }
        return;
      }
    }

    setState(() => _isPlacingOrder = true);

    final lang = ref.read(appLanguageProvider);
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (!mounted) return;
      if (!_hasVerifiedPhone(currentUser)) {
        setState(() => _isPlacingOrder = false);
        _showPhoneRequiredDialog();
        return;
      }

      Branch? selectedBranch = ref.read(selectedBranchProvider);
      if (cart.branchId != null) {
        final branches = ref.read(branchesProvider).valueOrNull;
        if (branches != null) {
          final matched = branches.where((b) => b.id == cart.branchId);
          if (matched.isNotEmpty) selectedBranch = matched.first;
        }
      }
      if (selectedBranch != null && !selectedBranch.isOpenNow) {
        setState(() => _isPlacingOrder = false);
        showDialog(context: context, builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr.get('branch_closed_title', lang),
            style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(tr.get('branch_closed_checkout_message', lang),
            style: const TextStyle(fontSize: 14)),
          actions: [ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD2222)),
            child: Text(tr.get('understand', lang), style: const TextStyle(color: Colors.white)))]));
        return;
      }

      if (_orderType == 'dine_in') {
        final tableNum = _tableNumberController.text.trim();
        final parsedTable = int.tryParse(tableNum);
        if (tableNum.isEmpty || parsedTable == null || parsedTable <= 0) {
          setState(() => _isPlacingOrder = false);
          Helpers.showSnackbar(
            context,
            lang == AppLanguage.indonesia
                ? 'Silakan masukkan nomor meja yang valid (hanya angka)'
                : 'Please enter a valid table number (digits only)',
            backgroundColor: Colors.orange,
          );
          return;
        }
      }

      if (_orderType != 'dine_in' && _paymentMethod == 'cash') {
        setState(() {
          _isPlacingOrder = false;
          _paymentMethod = 'qris';
        });
        final orderTypeLabel = _orderType == 'take_away'
            ? tr.get('order_type_take_away', lang)
            : tr.get('order_type_delivery', lang);
        Helpers.showSnackbar(
          context,
          tr.get('cash_not_allowed_for_order_type', lang).replaceFirst('{type}', orderTypeLabel),
          backgroundColor: Colors.orange,
        );
        return;
      }

      if (_orderType == 'delivery') {
        if (_tempDeliveryAddress == null && _selectedAddressId == null) {
          setState(() => _isPlacingOrder = false);
          Helpers.showSnackbar(context, tr.get('select_delivery_address_first', lang), backgroundColor: Colors.red);
          return;
        }
        if (_tempDeliveryAddress != null && (_tempDeliveryLat == null || _tempDeliveryLong == null)) {
          setState(() => _isPlacingOrder = false);
          Helpers.showSnackbar(
            context,
            tr.get('invalid_delivery_coordinates', lang),
            backgroundColor: Colors.red,
          );
          return;
        }
      }

      final userIdNullable = await ref.read(voucher_controller.currentUserIdProvider.future);
      if (userIdNullable == null) throw Exception('User not logged in');
      final userId = userIdNullable;

      String? deliveryAddress;
      double? deliveryLat;
      double? deliverLong;
      if (_orderType == 'delivery') {
        if (_tempDeliveryAddress != null) {
          deliveryAddress = _tempDeliveryAddress!;
          deliveryLat = _tempDeliveryLat!;
          deliverLong = _tempDeliveryLong!;
        } else if (_selectedAddressId != null) {
          final addressesAsync = ref.read(addressesProvider);
          await addressesAsync.when(
            data: (addresses) async {
              final addr = addresses.firstWhere((a) => a.id == _selectedAddressId);
              deliveryAddress = addr.address;
              deliveryLat = addr.latitude;
              deliverLong = addr.longitude;
            },
            loading: () => throw Exception('Loading addresses...'),
            error: (e, st) => throw Exception('Failed to load addresses'));
        }
      }

      final branchId = cart.branchId ?? ref.read(selectedBranchProvider)?.id ?? 1;
      final orderItems = cart.items.map<OrderDetailRequest>((item) {
        final hasBmi = item.branchMenuItemId != null && item.branchMenuItemId! > 0;
        return OrderDetailRequest(
          menuId: (!hasBmi && item.menuId > 0) ? item.menuId : null,
          branchMenuItemId: hasBmi ? item.branchMenuItemId : null,
          menuCode: item.menuCode,
          templateCode: item.templateCode,
          notes: item.notes,
          qty: item.quantity,
          total: item.price * item.quantity);
      }).toList();

      final subtotal = cart.subtotal;
      final deliveryFee = _orderType == 'delivery' ? (_selectedDeliveryQuote?.amount ?? 0.0) : 0.0;
      final tax = subtotal * 0.1;
      final service = (subtotal + tax) * 0.05;
      final discount = _selectedVoucherDiscount ?? 0.0;
      final grandTotal = subtotal + deliveryFee;
      final finalTotal = (grandTotal + tax + service - discount).clamp(0.0, double.infinity);

      if (_paymentMethod == 'qris' && finalTotal < 15000) {
        setState(() => _isPlacingOrder = false);
        _showQrisMinAmountSnackbar(finalTotal, lang);
        return;
      }

      if (_orderType != 'dine_in' && finalTotal < 15000) {
        setState(() => _isPlacingOrder = false);
        _showQrisMinAmountSnackbar(finalTotal, lang);
        return;
      }

      final request = CreateOrderRequest(
        date: DateTime.now().toIso8601String().split('T')[0],
        grandTotal: grandTotal, finalTotal: finalTotal, discount: discount,
        tax: tax, service: service, orderType: _orderType,
        payment: _paymentMethod.toUpperCase(), userId: userId, branchId: branchId,
        tableNumber: _orderType == 'dine_in' ? _tableNumberController.text.trim() : '0',
        userVoucherId: _selectedVoucherId, details: orderItems,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        deliverAddress: deliveryAddress, deliverLat: deliveryLat, deliverLong: deliverLong,
        grabDurationMinutes: _orderType == 'delivery' ? _selectedDeliveryQuote?.estimatedTimeMinutes : null,
        deliveryFee: deliveryFee);

      final response = await ref.read(orderControllerProvider.notifier).createOrder(request);

      if (mounted) {
        try { await ref.read(cartControllerProvider.notifier).clearCart(); } catch (_) {}
        if (_selectedVoucherId != null) {
          ref.invalidate(voucher_controller.myVouchersByStatusProvider('active'));
        }
        if (!mounted) return;
        if (_paymentMethod == 'qris') {
          context.go('/payment/${response.orderId}');
        } else {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => CashPaymentView(orderId: response.orderId, amount: finalTotal)));
        }
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e is ApiException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');

        final isMaintenanceError = (e is ApiException && e.statusCode == 422 &&
            (rawMsg.toLowerCase().contains('pemeliharaan') ||
             rawMsg.toLowerCase().contains('maintenance') ||
             rawMsg.toLowerCase().contains('desember 2026'))) ||
            rawMsg.toLowerCase().contains('pemeliharaan sistem') ||
            rawMsg.toLowerCase().contains('layanan pemesanan sedang');

        if (isMaintenanceError) {
          final isIndo = lang == AppLanguage.indonesia;
          final maintInfo = AppMaintenanceInfo(
            isActive: true,
            title: isIndo ? 'Maintenance Aplikasi' : 'App Maintenance',
            message: rawMsg.isNotEmpty
                ? rawMsg
                : (isIndo
                    ? 'Layanan pemesanan sedang dalam pemeliharaan sistem. Pemesanan menu akan dibuka pada Desember 2026.'
                    : 'Ordering service is currently under system maintenance. Menu ordering will open in December 2026.'),
            launchDate: isIndo ? 'Desember 2026' : 'December 2026',
            allowBrowsing: true,
            contactWhatsapp: '6281234567890',
          );
          ref.read(appMaintenanceProvider.notifier).setMaintenance(maintInfo);

          await AppMaintenanceDialog.show(context, maintenance: maintInfo);
        } else if (_isActiveUnpaidOrderError(e)) {
          await _showActiveUnpaidOrderDialog(_activeOrderIdFromError(e));
        } else {
          Helpers.showSnackbar(
            context,
            '${tr.get('failed_place_order', lang)}: $rawMsg',
            backgroundColor: Colors.red,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  bool _isActiveUnpaidOrderError(Object error) {
    final apiError = error is ApiException ? error : null;
    final message = apiError?.message ?? error.toString();
    return apiError?.statusCode == 409 ||
        message.contains('Selesaikan pembayaran pesanan sebelumnya') ||
        message.contains('Selesaikan pembayaran QRIS sebelumnya');
  }

  String? _activeOrderIdFromError(Object error) {
    if (error is ApiException) return error.data?['active_order_id']?.toString();
    return null;
  }

  Future<void> _showActiveUnpaidOrderDialog(String? activeOrderId) async {
    final lang = ref.read(appLanguageProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.get('active_unpaid_order_title', lang)),
        content: Text(tr.get('active_unpaid_order_message', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr.get('cancel', lang))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (!mounted) return;
              if (activeOrderId != null && activeOrderId.isNotEmpty) {
                context.go('/orders/${Uri.encodeComponent(activeOrderId)}');
              } else {
                context.go('/navigation?index=3');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD2222), foregroundColor: Colors.white),
            child: Text(tr.get('view_order', lang))),
        ]));
  }

  void _clearSelectedVoucher() {
    setState(() {
      _selectedVoucherId = null;
      _selectedVoucherDiscount = null;
    });
  }

  String _formatRupiah(double amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
        RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.");
    return 'Rp $formatted';
  }

  void _showPhoneRequiredDialog() {
    final lang = ref.read(appLanguageProvider);
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(tr.get('verify_phone_title', lang)),
      content: Text(tr.get('phone_checkout_required_message', lang)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.get('later', lang))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _openAddPhoneNumber(); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD2222), foregroundColor: Colors.white),
          child: Text(tr.get('add_phone_btn', lang))),
      ]));
  }
}
