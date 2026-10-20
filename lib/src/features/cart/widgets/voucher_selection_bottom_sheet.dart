import 'package:flutter/material.dart';
import '../../../core/localization/app_language.dart';
import '../../voucher/models/voucher_model.dart';

class VoucherItemCalculation {
  final DetailVoucher detailVoucher;
  final bool isEligible;
  final double discountAmount;
  final String? ineligibleReason;

  const VoucherItemCalculation({
    required this.detailVoucher,
    required this.isEligible,
    required this.discountAmount,
    this.ineligibleReason,
  });
}

class VoucherSelectionBottomSheet extends StatelessWidget {
  final List<DetailVoucher> userVouchers;
  final int? currentBrandId;
  final String? currentBrandName;
  final double cartSubtotal;
  final double deliveryFee;
  final String orderType;
  final int? selectedVoucherId;
  final AppLanguage lang;
  final void Function(DetailVoucher? selectedVoucher, double discountAmount)
      onSelectVoucher;

  const VoucherSelectionBottomSheet({
    super.key,
    required this.userVouchers,
    required this.currentBrandId,
    this.currentBrandName,
    required this.cartSubtotal,
    required this.deliveryFee,
    required this.orderType,
    required this.selectedVoucherId,
    required this.lang,
    required this.onSelectVoucher,
  });

  static Future<void> show({
    required BuildContext context,
    required List<DetailVoucher> userVouchers,
    required int? currentBrandId,
    String? currentBrandName,
    required double cartSubtotal,
    required double deliveryFee,
    required String orderType,
    required int? selectedVoucherId,
    required AppLanguage lang,
    required void Function(DetailVoucher? selectedVoucher, double discountAmount)
        onSelectVoucher,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => VoucherSelectionBottomSheet(
        userVouchers: userVouchers,
        currentBrandId: currentBrandId,
        currentBrandName: currentBrandName,
        cartSubtotal: cartSubtotal,
        deliveryFee: deliveryFee,
        orderType: orderType,
        selectedVoucherId: selectedVoucherId,
        lang: lang,
        onSelectVoucher: onSelectVoucher,
      ),
    );
  }

  static String formatRupiah(num amount) {
    return 'Rp ${amount.abs().toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  static String formatVoucherEndDate(Voucher v) {
    if (v.endDate == null || v.endDate!.trim().isEmpty) return '';
    try {
      final end = DateTime.parse(v.endDate!);
      return '${end.day}/${end.month}/${end.year}';
    } catch (_) {
      return v.endDate!.trim();
    }
  }

  VoucherItemCalculation _evaluateVoucher(DetailVoucher dv) {
    final v = dv.voucher;
    final isId = lang == AppLanguage.indonesia;

    if (v == null) {
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Data voucher tidak valid'
            : 'Invalid voucher data',
      );
    }

    // 1. Channel check (Not cashier/outlet physical only)
    final channel = v.usageChannel.toLowerCase();
    final type = v.voucherType.toLowerCase();
    final isCashierOnly = channel == 'cashier_only' ||
        type == 'buy_1_get_1' ||
        type == 'free_menu' ||
        type == 'free_item';
    if (isCashierOnly) {
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Hanya berlaku penukaran langsung di outlet'
            : 'Only valid for direct redemption at outlet',
      );
    }

    // 2. Brand compatibility check
    final brandMatches = (v.brandId == null || v.brandId == 0) ||
        (currentBrandId != null && v.brandId == currentBrandId);
    if (!brandMatches) {
      final brandTarget = v.brandName != null && v.brandName!.trim().isNotEmpty
          ? v.brandName!.trim()
          : (isId ? 'brand lain' : 'other brand');
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Hanya berlaku di outlet $brandTarget'
            : 'Only valid at $brandTarget outlets',
      );
    }

    // 3. Order type check (Free delivery only for delivery order)
    if (type == 'free_delivery' && orderType != 'delivery') {
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Khusus untuk pesanan Delivery'
            : 'Only valid for Delivery orders',
      );
    }

    // 4. Minimum spend check
    final minSpend = v.minSpend ?? 0.0;
    if (cartSubtotal < minSpend) {
      final diff = minSpend - cartSubtotal;
      final diffFormatted = formatRupiah(diff);
      final minSpendFormatted = formatRupiah(minSpend);
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Kurang $diffFormatted lagi untuk menggunakan voucher ini (Min. belanja $minSpendFormatted)'
            : 'Need $diffFormatted more to use this voucher (Min. spend $minSpendFormatted)',
      );
    }

    // 5. Expiration check
    if (v.isExpired) {
      return VoucherItemCalculation(
        detailVoucher: dv,
        isEligible: false,
        discountAmount: 0.0,
        ineligibleReason: isId
            ? 'Masa berlaku voucher telah berakhir'
            : 'Voucher has expired',
      );
    }

    // Calculate real discount amount
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

    return VoucherItemCalculation(
      detailVoucher: dv,
      isEligible: true,
      discountAmount: discount,
      ineligibleReason: null,
    );
  }

  String _benefitText(Voucher v) {
    return v.getBenefitSummary(lang);
  }

  @override
  Widget build(BuildContext context) {
    final isId = lang == AppLanguage.indonesia;

    // Process all user vouchers
    final calculations = userVouchers.map(_evaluateVoucher).toList();

    // Separate into eligible and ineligible
    final eligible = calculations.where((c) => c.isEligible).toList();
    // Sort eligible by discount amount descending (best discount first)
    eligible.sort((a, b) => b.discountAmount.compareTo(a.discountAmount));

    final ineligible = calculations.where((c) => !c.isEligible).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isId ? 'Pilih Voucher' : 'Select Voucher',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isId
                            ? 'Gunakan voucher untuk hemat lebih banyak'
                            : 'Use a voucher to save more on your order',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Scrollable List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Option: Tanpa Voucher
                  _buildNoVoucherOption(context, isId),
                  const SizedBox(height: 14),

                  // Section: Eligible Vouchers
                  if (eligible.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        isId
                            ? 'VOUCHER DAPAT DIGUNAKAN (${eligible.length})'
                            : 'AVAILABLE VOUCHERS (${eligible.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...eligible.map((item) => _buildEligibleVoucherCard(
                          context,
                          item,
                          isId,
                        )),
                    const SizedBox(height: 8),
                  ],

                  // Section: Ineligible Vouchers
                  if (ineligible.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        isId
                            ? 'VOUCHER BELUM MEMENUHI SYARAT (${ineligible.length})'
                            : 'INELIGIBLE VOUCHERS (${ineligible.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...ineligible.map((item) => _buildIneligibleVoucherCard(
                          item,
                          isId,
                        )),
                  ],

                  // Empty State if user has 0 vouchers at all
                  if (userVouchers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isId
                                  ? 'Anda belum memiliki voucher aktif'
                                  : 'You do not have any active vouchers yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVoucherOption(BuildContext context, bool isId) {
    final isSelected = selectedVoucherId == null;

    return InkWell(
      onTap: () {
        onSelectVoucher(null, 0.0);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFDD2222)
                : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFE0E0)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                size: 16,
                color: isSelected
                    ? const Color(0xFFDD2222)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isId ? 'Tanpa Voucher' : 'No Voucher',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFDD2222)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isId
                        ? 'Lanjutkan pesanan tanpa menggunakan voucher diskon'
                        : 'Continue order without using discount voucher',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? const Color(0xFFDD2222)
                  : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibleVoucherCard(
    BuildContext context,
    VoucherItemCalculation item,
    bool isId,
  ) {
    final dv = item.detailVoucher;
    final v = dv.voucher!;
    final isSelected = selectedVoucherId == dv.id;
    final minSpend = v.minSpend ?? 0.0;
    final minSpendText = minSpend > 0
        ? '${isId ? "Min. belanja" : "Min. spend"} ${formatRupiah(minSpend)}'
        : (isId ? 'Tanpa min. belanja' : 'No min. spend');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          onSelectVoucher(dv, item.discountAmount);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFDD2222)
                  : Colors.grey.shade200,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ticket Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFE0E0)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  v.voucherType.toLowerCase() == 'free_delivery'
                      ? Icons.delivery_dining_rounded
                      : Icons.confirmation_number_outlined,
                  size: 18,
                  color: const Color(0xFFDD2222),
                ),
              ),
              const SizedBox(width: 12),

              // Voucher Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.voucherName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFFDD2222)
                            : const Color(0xFF1E293B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _benefitText(v),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$minSpendText${v.endDate != null && formatVoucherEndDate(v).isNotEmpty ? ' • ${(isId ? 'Hingga ' : 'Valid until ')}${formatVoucherEndDate(v)}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Radio Check Icon
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? const Color(0xFFDD2222)
                    : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIneligibleVoucherCard(
    VoucherItemCalculation item,
    bool isId,
  ) {
    final dv = item.detailVoucher;
    final v = dv.voucher;
    final voucherName = v?.voucherName ?? (isId ? 'Voucher' : 'Voucher');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Disabled Ticket Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Benefit (Muted)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucherName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (v != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _benefitText(v),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Lock Icon
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),

          // Ineligible Reason Banner
          if (item.ineligibleReason != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFFED7AA),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Color(0xFFC2410C),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.ineligibleReason!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
