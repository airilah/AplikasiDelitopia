import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/services/api_client.dart';
import '../../../core/localization/app_language.dart';
import '../../voucher/controllers/voucher_controller.dart';
import '../../../shared/services/service_providers.dart'
    show notificationsProvider, hasUnreadNotificationsProvider, branchesProvider;
import '../../../shared/models/table_session_model.dart';
import '../../../shared/models/brand_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/auth_guard.dart';

class QRScannerView extends ConsumerStatefulWidget {
  const QRScannerView({super.key});

  @override
  ConsumerState<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends ConsumerState<QRScannerView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isLoading = false;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;
  bool _showManualInput = false;

  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(
        parent: _laserAnimController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleScannedCode(String rawCode) async {
    if (_isProcessingScan || _isLoading) return;
    final cleanCode = rawCode.trim();
    if (cleanCode.isEmpty) return;

    setState(() => _isProcessingScan = true);
    HapticFeedback.mediumImpact();

    // 1. Check if the scanned code is a table barcode/QR
    final tableSession = TableQRParser.parse(cleanCode);
    if (tableSession != null) {
      await _processTableScan(tableSession);
      return;
    }

    // 2. Otherwise fallback to voucher code claim
    await _processClaimVoucher(cleanCode);
  }

  Future<void> _processTableScan(TableSession tableData) async {
    final lang = ref.read(appLanguageProvider);
    setState(() => _isLoading = true);

    try {
      int? resolvedBrandId = tableData.brandId;
      String? resolvedBranchName = tableData.branchName;
      String? resolvedBrandName = tableData.brandName;

      // Match branch info from branchesProvider
      try {
        final branches = await ref.read(branchesProvider.future);
        final matched = branches.where((b) => b.id == tableData.branchId);
        if (matched.isNotEmpty) {
          final branch = matched.first;
          resolvedBrandId ??= branch.brandId;
          resolvedBranchName ??= branch.outlet;
          resolvedBrandName ??= branch.brandName;

          // Set active branch & brand in Riverpod
          ref.read(selectedBranchProvider.notifier).state = branch;
          ref.read(selectedBrandProvider.notifier).state = Brand(
            id: branch.brandId,
            name: branch.brandName,
            logo: branch.brandLogo ?? '',
            service: 0,
            tax: 0,
            category: const [],
          );
        }
      } catch (_) {}

      // Save table session
      final finalSession = tableData.copyWith(
        brandId: resolvedBrandId,
        branchName: resolvedBranchName,
        brandName: resolvedBrandName,
        isLockedFromQr: true,
      );
      ref.read(tableSessionProvider.notifier).state = finalSession;

      if (!mounted) return;

      final successMsg = lang == AppLanguage.indonesia
          ? 'Meja ${finalSession.tableNumber} terdeteksi! Membuka menu cabang...'
          : 'Table ${finalSession.tableNumber} detected! Opening branch menu...';

      Helpers.showSnackbar(context, successMsg);

      final brandParam = resolvedBrandId ?? 1;
      context.go('${AppRouter.menu}?branchId=${finalSession.branchId}&brandId=$brandParam');
    } catch (e) {
      if (!mounted) return;
      _showErrorAlert(
        lang == AppLanguage.indonesia ? 'Gagal Membuka Meja' : 'Failed to Open Table',
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessingScan = false;
        });
      }
    }
  }

  Future<void> _processClaimVoucher(String code) async {
    final lang = ref.read(appLanguageProvider);
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      _showErrorAlert(
        tr.get('code_empty_title', lang),
        tr.get('code_empty_desc', lang),
      );
      setState(() => _isProcessingScan = false);
      return;
    }

    if (!AuthGuard.isAuthenticated(ref)) {
      setState(() {
        _isProcessingScan = false;
        _isLoading = false;
      });
      AuthGuard.showLoginRequiredDialog(
        context,
        redirectTo: AppRouter.qrScanner,
        lang: lang,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/v2/vouchers/scan-claim',
        data: {
          'qr_code': cleanCode,
        },
      );

      // Invalidate voucher & notification providers to refresh immediately
      ref.invalidate(myVouchersProvider);
      ref.invalidate(availableVouchersProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(hasUnreadNotificationsProvider);

      if (!mounted) return;

      final data = response['data'] ?? {};
      final voucherName = data['voucher_name'] ?? tr.get('vouchers', lang);
      final message =
          response['message'] ?? tr.get('voucher_claimed_success', lang);

      _showSuccessClaimDialog(voucherName, message, data);
    } catch (e) {
      if (!mounted) return;
      String title = tr.get('claim_failed_title', lang);
      String errMsg = lang == AppLanguage.indonesia
          ? 'Terjadi kesalahan saat memproses voucher.'
          : 'An error occurred while processing the voucher.';

      if (e is ApiException) {
        errMsg = e.message;
        if (errMsg.toLowerCase().contains('kuota') ||
            errMsg.toLowerCase().contains('quota')) {
          title = tr.get('quota_exceeded_title', lang);
        } else if (errMsg.toLowerCase().contains('sudah pernah') ||
            errMsg.toLowerCase().contains('already')) {
          title = tr.get('already_claimed_title', lang);
        } else if (errMsg.toLowerCase().contains('kedaluwarsa') ||
            errMsg.toLowerCase().contains('kadaluarsa') ||
            errMsg.toLowerCase().contains('expired')) {
          title = tr.get('voucher_expired_title', lang);
        } else if (errMsg.toLowerCase().contains('tidak valid') ||
            errMsg.toLowerCase().contains('invalid')) {
          title = tr.get('invalid_qr_title', lang);
        }
      } else {
        errMsg = e.toString().replaceAll('Exception: ', '');
      }

      _showErrorAlert(title, errMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessClaimDialog(
      String voucherName, String message, Map<String, dynamic> data) {
    final lang = ref.read(appLanguageProvider);
    final claimCode = data['claim_code'] ?? '';
    final expiryDate = data['expiry_date'] ?? tr.get('no_expiry_limit', lang);
    final discountAmount = data['discount_amount'];
    final discountPercentage = data['discount_percentage'];

    String discountText = '';
    if (discountPercentage != null && discountPercentage > 0) {
      discountText = '${tr.get('discount', lang)} $discountPercentage%';
    } else if (discountAmount != null && discountAmount > 0) {
      final formattedAmount =
          NumberFormat('#,###', 'id_ID').format(discountAmount);
      discountText = '${tr.get('discount', lang)} Rp $formattedAmount';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // Success Icon with Glow
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EE),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 44,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              tr.get('voucher_claimed_success', lang),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            Text(
              voucherName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDD2222),
              ),
              textAlign: TextAlign.center,
            ),

            if (discountText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD4D4)),
                ),
                child: Text(
                  discountText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDD2222),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Voucher Details Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (claimCode.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr.get('voucher_code_label', lang),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: claimCode));
                            Helpers.showSnackbar(
                              context,
                              tr.get('code_copied_toast', lang),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                claimCode,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.copy_rounded,
                                size: 15,
                                color: Color(0xFFDD2222),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 20, color: Colors.grey.shade200),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr.get('validity_label', lang),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        expiryDate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr.get('status_label', lang),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8EE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr.get('active_now_badge', lang),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isProcessingScan = false;
                        _codeController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      tr.get('scan_again', lang),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go(AppRouter.vouchers);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      tr.get('view_my_vouchers', lang),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorAlert(String title, String message) {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
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
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isProcessingScan = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr.get('understand_button', lang),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final screenSize = MediaQuery.of(context).size;
    // Larger scanner box: 76% of screen width (max 320)
    final scannerSize = (screenSize.width * 0.76).clamp(260.0, 320.0);

    return BackButtonWrapper(
      backRoute: AppRouter.navigation,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Live Camera Feed ──────────────────────
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (BarcodeCapture capture) {
                  final barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null &&
                        barcode.rawValue!.isNotEmpty) {
                      _handleScannedCode(barcode.rawValue!);
                      break;
                    }
                  }
                },
                errorBuilder: (context, error, child) {
                  return Container(
                    color: const Color(0xFF18181B),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_off_rounded,
                            size: 54,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr.get('camera_permission_required', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr.get('camera_permission_desc', lang),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => _scannerController.start(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(tr.get('retry', lang)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDD2222),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Semi-transparent Dark Overlay with Viewfinder Cutout ──
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerHoleOverlayPainter(
                  holeSize: scannerSize,
                  borderRadius: 24,
                ),
              ),
            ),

            // ── Viewfinder Frame & Animated Laser ─────
            Center(
              child: SizedBox(
                width: scannerSize,
                height: scannerSize,
                child: Stack(
                  children: [
                    // Corner border accents
                    _buildCornerBorders(scannerSize),

                    // Laser beam animation
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value * (scannerSize - 4),
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFFFF3333),
                                  Colors.white,
                                  Color(0xFFFF3333),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2222)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      },
                    ),

                    // Scanning progress indicator when processing
                    if (_isLoading || _isProcessingScan)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFFDD2222),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tr.get('claiming_voucher_progress', lang),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Top Bar (Back, Title, Flash, Flip) ─────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => context.go(AppRouter.navigation),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title
                      Expanded(
                        child: Text(
                          tr.get('scan_qr_voucher', lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      // Flash Toggle
                      IconButton(
                        onPressed: () async {
                          await _scannerController.toggleTorch();
                          setState(() {
                            _isTorchOn = !_isTorchOn;
                          });
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isTorchOn
                                ? const Color(0xFFDD2222)
                                : Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Camera Switch
                      IconButton(
                        onPressed: () => _scannerController.switchCamera(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cameraswitch_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Viewfinder Subtitle Guidance ──────────
            Positioned(
              top: (screenSize.height / 2) + (scannerSize / 2) + 16,
              left: 20,
              right: 20,
              child: Text(
                tr.get('point_camera_at_qr', lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 8),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Bottom Manual Input Drawer / Card ─────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row / Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.keyboard_alt_outlined,
                                  color: Color(0xFFDD2222),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr.get('have_voucher_code', lang),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    tr.get('manual_code_subtitle', lang),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showManualInput = !_showManualInput;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDD2222),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _showManualInput
                                  ? tr.get('close', lang)
                                  : tr.get('enter_code', lang),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_showManualInput) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                                decoration: InputDecoration(
                                  hintText: tr.get('voucher_code_hint', lang),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.normal,
                                    letterSpacing: 0,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDD2222), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _processClaimVoucher(
                                      _codeController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDD2222),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 13),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      tr.get('claim_voucher_now', lang),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCornerBorders(double size) {
    const cornerLength = 32.0;
    const cornerThickness = 4.0;
    const cornerRadius = 24.0;
    const color = Color(0xFFDD2222);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Top-Left Corner
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerLength,
              height: cornerThickness,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerThickness,
              height: cornerLength,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),

          // Top-Right Corner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerLength,
              height: cornerThickness,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerThickness,
              height: cornerLength,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),

          // Bottom-Left Corner
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerLength,
              height: cornerThickness,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerThickness,
              height: cornerLength,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),

          // Bottom-Right Corner
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerLength,
              height: cornerThickness,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerThickness,
              height: cornerLength,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(cornerRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for semi-transparent overlay with a rounded rectangular cutout for the viewfinder
class _ScannerHoleOverlayPainter extends CustomPainter {
  final double holeSize;
  final double borderRadius;

  _ScannerHoleOverlayPainter({
    required this.holeSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);
    final holeRect = Rect.fromCenter(
      center: center,
      width: holeSize,
      height: holeSize,
    );

    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          holeRect,
          Radius.circular(borderRadius),
        ),
      );

    final overlayPath =
        Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerHoleOverlayPainter oldDelegate) {
    return oldDelegate.holeSize != holeSize ||
        oldDelegate.borderRadius != borderRadius;
  }
}
