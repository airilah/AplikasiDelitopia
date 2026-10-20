import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/localization/app_language.dart';
import 'dart:async';
import '../controllers/order_controller.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class PaymentView extends ConsumerStatefulWidget {
  final String orderId;
  const PaymentView({super.key, required this.orderId});

  @override
  ConsumerState<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<PaymentView> {
  Timer? _countdownTimer;
  Timer? _statusCheckTimer;
  int _remainingSeconds = 900; // 15 minutes
  AppLanguage get _lang => ref.read(appLanguageProvider);
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _countdownTimer?.cancel();
            _statusCheckTimer?.cancel();
            _showTimeoutDialog();
          }
        });
      }
    });
  }

  void _startStatusPolling() {
    // Check payment status every 5 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isCheckingStatus) {
        _checkPaymentStatus();
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isCheckingStatus = true);

    try {
      final orderDetails =
          await ref.read(orderDetailsProvider(widget.orderId).future);

      if (mounted) {
        final status = orderDetails.paymentStatus.toLowerCase();

        if (status == 'paid' || status == 'success' || status == 'completed') {
          _countdownTimer?.cancel();
          _statusCheckTimer?.cancel();
          _showSuccessDialog();
        } else if (status == 'failed' ||
            status == 'expired' ||
            status == 'cancelled') {
          _countdownTimer?.cancel();
          _statusCheckTimer?.cancel();
          _showFailureDialog(status);
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmCancelPayment() async {
    final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(tr.get('cancel_payment_title', _lang)),
              content: Text(tr.get('cancel_payment_confirm', _lang)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr.get('no', _lang)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr.get('yes', _lang),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ));
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final orderDetailsAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final canPop = await _confirmCancelPayment();
        if (canPop && mounted) {
          router.go('/orders/${widget.orderId}');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: tr.get('back', lang),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final router = GoRouter.of(context);
              if (await _confirmCancelPayment() && mounted) {
                router.go('/orders/${widget.orderId}');
              }
            },
          ),
          title: Text(tr.get('payment_title', lang)),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: orderDetailsAsync.when(
          data: (order) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 300
                      ? Colors.red[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _remainingSeconds < 300
                        ? Colors.red[200]!
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: _remainingSeconds < 300
                          ? Colors.red[700]
                          : Colors.orange[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIndo
                                ? 'Selesaikan pembayaran dalam'
                                : 'Complete payment within',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _formattedTime,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds < 300
                                  ? Colors.red[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isCheckingStatus)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment Method Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            order.paymentMethod == 'qris'
                                ? Icons.qr_code
                                : Icons.account_balance,
                            color: const Color(0xFFDD2222),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            order.paymentMethod == 'qris'
                                ? (isIndo ? 'Pembayaran QRIS' : 'QRIS Payment')
                                : 'Virtual Account',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${isIndo ? 'Nomor Pesanan' : 'Order ID'}: ${order.orderNumber.isNotEmpty ? order.orderNumber : widget.orderId}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isIndo ? 'Total Pembayaran' : 'Total Amount',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Rp ${order.formattedTotalAmount}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDD2222),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // QRIS or VA Display
              if (order.paymentMethod == 'qris')
                _buildQRISSection(order, lang)
              else
                _buildVASection(order, lang),

              const SizedBox(height: 24),

              // Payment Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndo ? 'Petunjuk Pembayaran' : 'Payment Instructions',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (order.paymentMethod == 'qris') ...[
                        _buildInstructionStep(
                            '1',
                            isIndo
                                ? 'Simpan / Screenshot kode QRIS di atas'
                                : 'Save / Screenshot the QRIS code above'),
                        _buildInstructionStep(
                            '2',
                            isIndo
                                ? 'Buka aplikasi Mobile Banking atau E-Wallet Anda'
                                : 'Open your Mobile Banking or E-Wallet app'),
                        _buildInstructionStep(
                            '3',
                            isIndo
                                ? 'Pilih menu Bayar / QRIS, lalu unggah gambar dari galeri'
                                : 'Select Pay / QRIS menu, then upload image from gallery'),
                        _buildInstructionStep(
                            '4',
                            isIndo
                                ? 'Periksa rincian pembayaran & masukkan PIN Anda'
                                : 'Check payment details & enter your PIN'),
                        _buildInstructionStep(
                            '5',
                            isIndo
                                ? 'Selesai! Pembayaran otomatis diverifikasi sistem'
                                : 'Done! Payment will be verified automatically'),
                      ] else ...[
                        _buildInstructionStep(
                            '1',
                            isIndo
                                ? 'Buka aplikasi m-banking atau ATM'
                                : 'Open your banking app or ATM'),
                        _buildInstructionStep(
                            '2',
                            isIndo
                                ? 'Pilih menu Transfer / Pembayaran'
                                : 'Select Transfer/Payment menu'),
                        _buildInstructionStep(
                            '3',
                            isIndo
                                ? 'Masukkan nomor Virtual Account di atas'
                                : 'Enter the Virtual Account number above'),
                        _buildInstructionStep(
                            '4',
                            isIndo
                                ? 'Periksa rincian pembayaran'
                                : 'Confirm payment details'),
                        _buildInstructionStep(
                            '5',
                            isIndo
                                ? 'Selesaikan pembayaran'
                                : 'Complete the payment'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Check Status Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCheckingStatus ? null : _checkPaymentStatus,
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(tr.get('check_payment_status_btn', lang)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: const Color(0xFFDD2222),
                  ),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                    '${tr.get('error_loading_payment', lang)}: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.refresh(orderDetailsProvider(widget.orderId)),
                  child: Text(tr.get('retry', lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRISSection(dynamic order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    // Mock QRIS string - in production, this should come from E-Smartlink API
    final qrisString = 'QRIS-PAYMENT-${widget.orderId}-${order.totalAmount}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              isIndo ? 'Scan Kode QR' : 'Scan QR Code',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: qrisString,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isIndo
                  ? 'Scan dengan aplikasi e-wallet atau mobile banking yang mendukung QRIS'
                  : 'Scan with any QRIS-enabled app',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVASection(dynamic order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    // Mock VA number - in production, this should come from E-Smartlink API
    final vaNumber = '8808${widget.orderId.padLeft(12, '0')}'.substring(0, 16);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIndo ? 'Nomor Virtual Account' : 'Virtual Account Number',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vaNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: vaNumber));
                      Helpers.showSnackbar(
                          context, tr.get('va_copied_msg', lang));
                    },
                    tooltip: tr.get('copy', lang),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bank: E-Smartlink',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFDD2222),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Pembayaran Berhasil!'
                  : 'Payment Successful!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Pembayaran Anda telah dikonfirmasi'
                  : 'Your payment has been confirmed',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/orders/${widget.orderId}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                ),
                child: Text(tr.get('view_order', lang),
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/navigation?index=0');
              },
              child: Text(tr.get('back_to_home', lang)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailureDialog(String status) {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Pembayaran Gagal'
                  : 'Payment Failed',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $status',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/navigation?index=3');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                ),
                child: Text(tr.get('view_orders_btn', lang),
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/navigation?index=0');
              },
              child: Text(tr.get('back_to_home', lang)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeoutDialog() {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, color: Colors.orange[700], size: 80),
            const SizedBox(height: 16),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Waktu Pembayaran Habis'
                  : 'Payment Timeout',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Waktu pembayaran telah habis. Silakan buat pesanan baru.'
                  : 'Payment time has expired. Please create a new order.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/navigation?index=0');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                ),
                child: Text(tr.get('back_to_home', lang),
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
