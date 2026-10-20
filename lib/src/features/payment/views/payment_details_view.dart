import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../order/controllers/order_controller.dart';
import '../controllers/payment_controller.dart';
import '../models/payment_model.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class PaymentDetailsView extends ConsumerStatefulWidget {
  final String transactionId;

  const PaymentDetailsView({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<PaymentDetailsView> createState() => _PaymentDetailsViewState();
}

class _PaymentDetailsViewState extends ConsumerState<PaymentDetailsView> {
  final GlobalKey _qrCardKey = GlobalKey();
  Timer? _pollTimer;
  int _remainingSeconds = 0;
  bool _isTimerStarted = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll payment status every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final inquiry = await ref
            .read(paymentControllerProvider.notifier)
            .checkStatus(widget.transactionId);

        if (inquiry.isPaid) {
          _pollTimer?.cancel();
          if (mounted) {
            final lang = ref.read(appLanguageProvider);
            Helpers.showSnackbar(
              context,
              tr.get('payment_successful', lang),
              backgroundColor: Colors.green,
            );
            context.go('/navigation?index=3'); // Go to orders tab
          }
        } else if (inquiry.isFailed || inquiry.isExpired) {
          _pollTimer?.cancel();
          if (mounted) {
            final lang = ref.read(appLanguageProvider);
            Helpers.showSnackbar(
              context,
              '${tr.get('payment_status_prefix', lang)}: ${inquiry.paymentStatus}',
              backgroundColor: Colors.red,
            );
          }
        }
      } catch (e) {
        // Continue polling even if error
      }
    });
  }

  void _updateCountdown(DateTime expiredAt) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final difference = expiredAt.difference(now);

      if (difference.isNegative) {
        timer.cancel();
        if (_remainingSeconds != 0) {
          setState(() => _remainingSeconds = 0);
        }

        // Auto-cancel payment if time expires
        final inquiry =
            ref.read(paymentInquiryProvider(widget.transactionId)).valueOrNull;
        if (inquiry != null && inquiry.isPending) {
          ref
              .read(paymentControllerProvider.notifier)
              .cancelPayment(widget.transactionId)
              .catchError((_) {});
        }
      } else {
        setState(() => _remainingSeconds = difference.inSeconds);
      }
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<Uint8List?> _captureQrCard() async {
    try {
      final boundary = _qrCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR code: $e');
      return null;
    }
  }

  Future<void> _shareQrCode({
    required String qrData,
    required String orderId,
    required String amount,
    required String merchantName,
    required AppLanguage lang,
  }) async {
    final isIndo = lang == AppLanguage.indonesia;
    try {
      final bytes = await _captureQrCard();
      if (bytes != null) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'QRIS_DELITOPIA_$orderId.png',
            ),
          ],
          text: isIndo
              ? 'QRIS Pembayaran $merchantName\nNomor Pesanan: $orderId\nTotal Pembayaran: $amount\n\nSilakan scan kode QRIS terlampir menggunakan aplikasi Mobile Banking atau E-Wallet pilihan Anda.'
              : '$merchantName QRIS Payment\nOrder ID: $orderId\nTotal Amount: $amount\n\nPlease scan the attached QRIS code using your preferred Mobile Banking or E-Wallet app.',
        );
      } else {
        await Share.share(
          'QRIS $merchantName\nOrder ID: $orderId\nTotal: $amount\nData: $qrData',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo
                ? 'Gagal membagikan QRIS: $e'
                : 'Failed to share QRIS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveQrToGallery({
    required String qrData,
    required String orderId,
    required String amount,
    required String merchantName,
    required AppLanguage lang,
  }) async {
    final isIndo = lang == AppLanguage.indonesia;
    try {
      final bytes = await _captureQrCard();
      if (bytes == null) {
        throw Exception(isIndo
            ? 'Gagal menangkap gambar QRIS.'
            : 'Failed to capture QRIS image.');
      }

      final cleanOrderId =
          orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      bool savedDirectly = false;
      try {
        await Gal.putImageBytes(
          bytes,
          name: 'QRIS_DELITOPIA_$cleanOrderId.png',
        );
        savedDirectly = true;
      } catch (nativeErr) {
        debugPrint('Direct gallery save failed: $nativeErr. Falling back to share.');
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'QRIS_DELITOPIA_$cleanOrderId.png',
            ),
          ],
          text: isIndo
              ? 'QRIS Pembayaran $merchantName\nNomor Pesanan: $orderId\nTotal: $amount'
              : '$merchantName QRIS Payment\nOrder ID: $orderId\nTotal: $amount',
        );
        return;
      }

      if (savedDirectly && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr.get('qris_saved_success', lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo
                ? 'Gagal memproses QRIS: $e'
                : 'Failed to process QRIS: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showZoomQrDialog({
    required String qrData,
    required String orderId,
    required String amount,
    required String merchantName,
    required AppLanguage lang,
  }) {
    final isIndo = lang == AppLanguage.indonesia;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF202124),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#$orderId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: isIndo ? 'Tutup' : 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 1.5),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDD2222),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isIndo
                    ? 'Arahkan kamera atau scan dari galeri aplikasi bank/e-wallet'
                    : 'Scan with camera or upload from gallery in your banking/e-wallet app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentAsync =
        ref.watch(paymentInquiryProvider(widget.transactionId));
    final orderAsync = ref.watch(orderDetailsProvider(widget.transactionId));
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=3',
      onBack: () => context.go('/navigation?index=3'),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          leading: AppBackButton(
            backRoute: '/navigation?index=3',
            onBack: () => context.go('/navigation?index=3'),
            color: Colors.white,
          ),
          title: Text(
            tr.get('qris_payment_title', lang),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: paymentAsync.when(
          data: (inquiry) {
            return orderAsync.when(
              data: (order) {
                // Calculate countdown from exact order creation time
                if (!_isTimerStarted) {
                  _isTimerStarted = true;
                  DateTime actualExpiry =
                      order.createdAt.add(const Duration(minutes: 15));

                  final now = DateTime.now();
                  final difference = actualExpiry.difference(now);

                  _remainingSeconds =
                      difference.isNegative ? 0 : difference.inSeconds;
                  _updateCountdown(actualExpiry);
                }

                final orderNumber = order.orderNumber.isNotEmpty
                    ? order.orderNumber
                    : widget.transactionId;
                final merchantName = (order.branchName.trim().isNotEmpty)
                    ? 'DELITOPIA - ${order.branchName.toUpperCase()}'
                    : 'DELITOPIA';

                final effectiveQr = (inquiry.qrString != null &&
                        inquiry.qrString!.isNotEmpty)
                    ? inquiry.qrString!
                    : (order.pgQrString != null && order.pgQrString!.isNotEmpty
                        ? order.pgQrString!
                        : '');

                final isActuallyExpired =
                    inquiry.isExpired || _remainingSeconds <= 0;
                final isActuallyFailed = inquiry.isFailed;

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Compact Unified Status & Amount Header Card
                      _buildCompactHeaderCard(inquiry, orderNumber, lang),
                      const SizedBox(height: 10),

                      // 2. Official Branded QRIS Card & Action Buttons
                      if (inquiry.isPaid) ...[
                        // Paid Status Detail
                        _buildPaidStateCard(lang),
                      ] else if (isActuallyFailed || isActuallyExpired) ...[
                        // Expired or Failed State
                        _buildExpiredOrFailedCard(inquiry, lang),
                      ] else if (effectiveQr.isNotEmpty) ...[
                        _buildOfficialQrisCard(
                          inquiry: inquiry,
                          orderNumber: orderNumber,
                          merchantName: merchantName,
                          lang: lang,
                          qrData: effectiveQr,
                        ),
                        const SizedBox(height: 10),

                        // Quick Action Buttons (Download & Share)
                        _buildActionButtons(
                          qrData: effectiveQr,
                          orderId: orderNumber,
                          amount: inquiry.formattedAmount,
                          merchantName: merchantName,
                          lang: lang,
                        ),
                        const SizedBox(height: 12),

                        // Payment Instructions
                        _buildPaymentInstructions(
                            inquiry.formattedAmount, merchantName, lang),
                        const SizedBox(height: 14),

                        // Cancel Button
                        OutlinedButton(
                          onPressed: () => _confirmCancel(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDD2222),
                            side: const BorderSide(
                                color: Color(0xFFDD2222), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            tr.get('cancel_payment_btn', lang),
                            style: const TextStyle(
                                fontWeight: FontWeight.normal, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        _buildGeneratingOrEmptyQrCard(lang, orderNumber),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      '${tr.get('error_loading_order_details', lang)}: $error'),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text('${tr.get('something_went_wrong', lang)}: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => BackButtonWrapper.handleBack(
                      context,
                      backRoute: '/navigation?index=3',
                    ),
                    child: Text(tr.get('go_back', lang)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Compact Header Summary Card
  Widget _buildCompactHeaderCard(
      PaymentInquiry inquiry, String orderNumber, AppLanguage lang) {
    final isPending = inquiry.isPending && _remainingSeconds > 0;
    final isIndo = lang == AppLanguage.indonesia;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (inquiry.isPaid) {
      statusText = isIndo ? 'Pembayaran Berhasil' : 'Payment Successful';
      statusColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_rounded;
    } else if (isPending) {
      statusText = isIndo ? 'Menunggu Pembayaran' : 'Waiting for Payment';
      statusColor = const Color(0xFFE65100);
      statusIcon = Icons.schedule_rounded;
    } else if (inquiry.isFailed) {
      statusText = isIndo ? 'Pembayaran Gagal' : 'Payment Failed';
      statusColor = const Color(0xFFC62828);
      statusIcon = Icons.cancel_rounded;
    } else {
      statusText = isIndo ? 'Kedaluwarsa' : 'Expired';
      statusColor = Colors.grey[700]!;
      statusIcon = Icons.timer_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Status badge & Timer Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              if (isPending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: Color(0xFFDD2222)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDD2222),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 14, thickness: 0.8),
          // Order ID Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isIndo ? 'Nomor Pesanan' : 'Order ID'}:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: orderNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr.get('order_id_copied', lang)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, size: 13, color: Colors.grey[500]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Total Payment Row (placed below Order ID)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tr.get('total_payment', lang)}:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                inquiry.formattedAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDD2222),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Official Branded QRIS Card
  Widget _buildOfficialQrisCard({
    required PaymentInquiry inquiry,
    required String orderNumber,
    required String merchantName,
    required AppLanguage lang,
    required String qrData,
  }) {
    return RepaintBoundary(
      key: _qrCardKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // QRIS Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDD2222), Color(0xFFB71C1C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'QRIS',
                          style: TextStyle(
                            color: Color(0xFFDD2222),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr.get('national_payment_standard', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'GPN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            // Merchant Name & NMID
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  Text(
                    merchantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF202124),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NMID: ID1020021115598 • A01',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // QR Code with Tap to Zoom gesture
            GestureDetector(
              onTap: () => _showZoomQrDialog(
                qrData: qrData,
                orderId: orderNumber,
                amount: inquiry.formattedAmount,
                merchantName: merchantName,
                lang: lang,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 210,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ],
                ),
              ),
            ),

            // Nominal Card & Tap Hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFFAFAFA),
              child: Column(
                children: [
                  Text(
                    inquiry.formattedAmount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDD2222),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        tr.get('tap_to_zoom_qris', lang),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Action Buttons (Save to Gallery & Share)
  Widget _buildActionButtons({
    required String qrData,
    required String orderId,
    required String amount,
    required String merchantName,
    required AppLanguage lang,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveQrToGallery(
              qrData: qrData,
              orderId: orderId,
              amount: amount,
              merchantName: merchantName,
              lang: lang,
            ),
            icon: const Icon(Icons.download_for_offline_rounded,
                size: 18, color: Color(0xFFDD2222)),
            label: Text(
              tr.get('save_to_gallery', lang),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDD2222),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFDD2222), width: 1.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareQrCode(
              qrData: qrData,
              orderId: orderId,
              amount: amount,
              merchantName: merchantName,
              lang: lang,
            ),
            icon: const Icon(Icons.share_rounded,
                size: 18, color: Colors.white),
            label: Text(
              tr.get('share_qris', lang),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: const Color(0xFFDD2222),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // 4. Payment Instructions (Mobile-Friendly 5 Steps)
  Widget _buildPaymentInstructions(
      String formattedAmount, String merchantName, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 18, color: Color(0xFFDD2222)),
              const SizedBox(width: 8),
              Text(
                isIndo
                    ? 'Cara Pembayaran di HP Ini:'
                    : 'How to Pay on This Device:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '1',
            tr.get('qris_step_save_qr', lang),
          ),
          _buildInstructionStep(
            '2',
            tr.get('qris_step_open_wallet', lang),
          ),
          _buildInstructionStep(
            '3',
            tr.get('qris_step_scan_qr', lang),
          ),
          _buildInstructionStep(
            '4',
            tr
                .get('qris_step_verify_merchant', lang)
                .replaceAll('DELITOPIA', merchantName),
          ),
          _buildInstructionStep(
            '5',
            tr.get('qris_step_finish_payment', lang),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr.get('payment_auto_verified', lang),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF2E7D32),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFFDD2222),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // Paid State Card
  Widget _buildPaidStateCard(AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 64, color: Color(0xFF2E7D32)),
          const SizedBox(height: 12),
          Text(
            isIndo ? 'Pembayaran Telah Selesai!' : 'Payment Completed!',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIndo
                ? 'Pesanan Anda sedang dipersiapkan oleh pihak restoran.'
                : 'Your order is being prepared by the restaurant.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.go('/navigation?index=3'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isIndo ? 'Lihat Pesanan Saya' : 'View My Orders'),
          ),
        ],
      ),
    );
  }

  // Generating or Empty QR State Card
  Widget _buildGeneratingOrEmptyQrCard(AppLanguage lang, String orderNumber) {
    final isIndo = lang == AppLanguage.indonesia;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
                color: Color(0xFFDD2222), strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            isIndo ? 'Menyiapkan Kode QRIS...' : 'Preparing QRIS Code...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIndo
                ? 'Sistem sedang memproses kode QRIS resmi. Jika kode belum muncul dalam beberapa detik, silakan tekan Muat Ulang.'
                : 'The system is generating your official QRIS code. If it doesn\'t appear, please tap Refresh.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(paymentInquiryProvider(widget.transactionId));
              ref.invalidate(orderDetailsProvider(widget.transactionId));
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(isIndo ? 'Muat Ulang QRIS' : 'Refresh QRIS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // Expired or Failed State Card
  Widget _buildExpiredOrFailedCard(PaymentInquiry inquiry, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            inquiry.isFailed ? Icons.cancel_rounded : Icons.timer_off_rounded,
            size: 56,
            color: inquiry.isFailed ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            inquiry.isFailed
                ? (isIndo ? 'Pembayaran Gagal' : 'Payment Failed')
                : (isIndo ? 'Waktu Pembayaran Telah Habis' : 'Payment Expired'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: inquiry.isFailed ? Colors.red : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIndo
                ? 'Silakan buat pesanan baru untuk melanjutkan pembelian.'
                : 'Please create a new order to proceed with payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => BackButtonWrapper.handleBack(
              context,
              backRoute: '/navigation?index=3',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr.get('go_back', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final lang = ref.read(appLanguageProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.get('cancel_payment_title', lang)),
        content: Text(tr.get('cancel_payment_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr.get('no', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr.get('yes_cancel', lang)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(paymentControllerProvider.notifier)
            .cancelPayment(widget.transactionId);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(tr.get('payment_cancelled_success', lang))),
        );
        if (mounted) {
          BackButtonWrapper.handleBack(
            context,
            backRoute: '/navigation?index=3',
          );
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${tr.get('payment_cancel_failed', lang)}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
