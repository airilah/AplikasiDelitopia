import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gal/gal.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/api_client.dart';
import '../../../shared/services/service_providers.dart';
import '../controllers/order_controller.dart';
import '../models/order_model.dart';
import '../../../core/widgets/app_rating_dialog.dart';
import '../../../core/widgets/app_dialog.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

final orderReviewProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, orderKey) async {
  final prefs = await SharedPreferences.getInstance();
  final dataStr = prefs.getString('order_review_$orderKey');
  Map<String, dynamic>? localData;
  if (dataStr != null && dataStr.isNotEmpty) {
    try {
      localData = jsonDecode(dataStr) as Map<String, dynamic>;
    } catch (_) {}
  }

  // Also query backend for real-time review moderation status
  try {
    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.get('/reviews/order/$orderKey');
    if (res['success'] == true && res['data'] != null) {
      final remote = res['data'] as Map<String, dynamic>;
      final merged = {
        ...?localData,
        ...remote,
        'rating': remote['rating'] ?? localData?['rating'],
        'comment': remote['comment'] ?? localData?['comment'],
        'status': remote['status'] ?? localData?['status'] ?? 'pending',
        'tags': remote['tags'] ?? localData?['tags'] ?? [],
        'updatedAt': remote['created_at'] ?? localData?['updatedAt'],
      };
      await prefs.setString('order_review_$orderKey', jsonEncode(merged));
      return merged;
    }
  } catch (_) {}

  return localData;
});

class OrderDetailsView extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailsView({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsView> createState() => _OrderDetailsViewState();
}

/// Drawn from the content layer instead of the timeline indicator: timeline_tile
/// clips its indicator's overflow, while this layer may visibly cross the line.
/// A short red line travels across the neutral connector into the active step.
class _TimelineProgressDot extends StatelessWidget {
  const _TimelineProgressDot({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final travel = animation.value;
        final fadeIn = (travel / 0.12).clamp(0.0, 1.0).toDouble();
        final fadeOut = ((1 - travel) / 0.10).clamp(0.0, 1.0).toDouble();
        final opacity = fadeIn < fadeOut ? fadeIn : fadeOut;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              // Follows the neutral connector into the active circle.
              left: -10,
              top: -28 + (44 * travel),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDD2222),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66DD2222),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fills the white centre only when the travelling dot reaches this step.
class _ActiveTimelineIndicator extends StatelessWidget {
  const _ActiveTimelineIndicator({
    required this.animation,
    required this.animateFill,
  });

  final Animation<double> animation;
  final bool animateFill;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final fill = animateFill
            ? ((animation.value - 0.82) / 0.14).clamp(0.0, 1.0).toDouble()
            : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            if (fill > 0)
              ClipOval(
                child: SizedBox(
                  width: 7,
                  height: 7,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fill,
                    child: const ColoredBox(
                      color: Color(0xFFDD2222),
                      child: SizedBox(width: 7, height: 7),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The final status is already connected, so it only pulses in place instead
/// of suggesting that progress is still travelling to another status.
class _FinalTimelineIndicator extends StatelessWidget {
  const _FinalTimelineIndicator({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final pulse = animation.value <= 0.5
            ? animation.value * 2
            : (1 - animation.value) * 2;

        return Transform.scale(
          // Keep the pulse inside timeline_tile's indicator bounds.
          scale: 0.84 + (pulse * 0.16),
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFFDD2222),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 11,
            ),
          ),
        );
      },
    );
  }
}

class _OrderDetailsViewState extends ConsumerState<OrderDetailsView>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  AnimationController? _timelineProgressController;
  Animation<double>? _timelineProgressAnimation;
  bool _isTimelineExpanded = false;
  bool _hasCheckedRatePrompt = false;

  void _checkAndShowRateDialog(Order order) {
    if (_hasCheckedRatePrompt) return;
    if (!order.isCompleted) return;

    _hasCheckedRatePrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final shouldShow = await AppRatingDialog.shouldShowPrompt();
      if (shouldShow && mounted) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          AppRatingDialog.show(context);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _ensureTimelineProgressAnimation();
    _startPolling();
    _startCountdownTimer();
  }

  // Kept lazy as well as initialized in initState so a hot reload can safely
  // upgrade an already-mounted order detail screen.
  void _ensureTimelineProgressAnimation() {
    if (_timelineProgressAnimation != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _timelineProgressController = controller;
    _timelineProgressAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.linear,
    );
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Adaptive fallback polling:
    // Real-time updates are pushed instantly via FCM notification invalidation.
    // 15s for pending payment (waiting for QRIS gateway callback),
    // 30s for cooking/delivery as safety fallback to avoid hammering the backend.
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      final orderState =
          ref.read(orderDetailsProvider(widget.orderId)).valueOrNull;
      if (orderState != null) {
        final isFinished = orderState.isCompleted ||
            orderState.isCancelled ||
            orderState.isRejected ||
            orderState.isExpired;
        if (isFinished) {
          timer.cancel();
          return;
        }

        // If order has moved beyond pending payment, skip alternate ticks (30s interval)
        if (!orderState.isPendingPayment && timer.tick % 2 != 0) {
          return;
        }
      }
      ref.invalidate(orderDetailsProvider(widget.orderId));
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final orderState =
          ref.read(orderDetailsProvider(widget.orderId)).valueOrNull;
      if (orderState != null && (orderState.isPendingPayment || orderState.isCompleted)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _timelineProgressController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderDetailsAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final lang = ref.watch(appLanguageProvider);
    final order = orderDetailsAsync.valueOrNull;

    Widget bodyContent;
    if (order != null) {
      final hasExpired = order.isExpired;
            final methodUpper = order.paymentMethod.toUpperCase();
            final isQris =
                methodUpper.contains('QRIS') || methodUpper.contains('QR');
            final expiryReasonText = isQris
                ? 'Waktu pembayaran QRIS habis (15 menit)'
                : 'Waktu pembayaran Tunai/Cash habis (30 menit)';

            if (order.isExpiredByTime &&
                !order.isExpiredStatus &&
                order.status != OrderStatus.cancelled) {
              Future.microtask(() async {
                try {
                  final userId = await ref.read(currentUserIdProvider.future);
                  if (userId != null) {
                    await ref
                        .read(orderControllerProvider.notifier)
                        .cancelOrder(order.id, userId, expiryReasonText);
                    ref.invalidate(orderDetailsProvider(widget.orderId));
                  }
                } catch (_) {}
              });
            }

            final orderKey = order.orderNumber.isNotEmpty
                ? order.orderNumber
                : order.id.toString();
            final submittedReview = order.isCompleted
                ? ref.watch(orderReviewProvider(orderKey)).valueOrNull
                : null;

            if (order.isCompleted) {
              _checkAndShowRateDialog(order);
            }

            bodyContent = RefreshIndicator(
              color: const Color(0xFFDD2222),
              backgroundColor: Colors.white,
              onRefresh: () =>
                  ref.refresh(orderDetailsProvider(widget.orderId).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // ── Status card (Includes Order Type & Clean Status Text) ──
                  _buildStatusCard(order, lang: lang, hasExpired: hasExpired),

                  const SizedBox(height: 10),

                  // ── Order Estimation Hero Card ─────────────────────
                  if (!hasExpired && !order.isCancelled && !order.isRejected) ...[
                    _buildOrderEstimationCard(order, lang),
                    const SizedBox(height: 10),
                  ],

                  // ── Admin Cancel Request Banner (Active Order) ─────
                  if (!order.isRejected &&
                      !order.isCancelled &&
                      !hasExpired &&
                      order.cancelReason != null &&
                      order.cancelReason!.isNotEmpty) ...[
                    _buildAdminCancelRequestCard(
                        context, ref, order, order.cancelReason!, lang),
                    const SizedBox(height: 10),
                  ],

                  // ── Progress timeline ──────────────────────────────
                  if ((order.isActive || order.isCompleted) && !hasExpired) ...[
                    _buildOrderTimeline(order, lang),
                    const SizedBox(height: 10),
                  ],

                  // ── GrabExpress Driver & Live Tracking Card (Only shown after order is accepted by restaurant) ──
                  if (order.isDelivery &&
                      order.status != OrderStatus.pendingPayment &&
                      order.status != OrderStatus.paymentFailed &&
                      order.status != OrderStatus.expired &&
                      order.status != OrderStatus.paid &&
                      order.status != 'pending' &&
                      order.status != 'awaiting_payment' &&
                      order.status != 'paid_waiting_confirmation' &&
                      !order.isCancelled &&
                      !order.isRejected &&
                      !hasExpired) ...[
                    _buildDeliveryDriverCard(order, lang),
                    const SizedBox(height: 10),
                  ],

                  // ── Cancel reason (rejected / cancelled) ──────────
                  if (((order.isRejected || order.isCancelled) || hasExpired) &&
                      (order.cancelReason != null || hasExpired)) ...[
                    _buildCancelReasonCard(
                        hasExpired ? expiryReasonText : order.cancelReason!),
                    const SizedBox(height: 10),
                  ],

                  // ── Items ──────────────────────────────────────────
                  _buildSectionHeader(lang == AppLanguage.indonesia
                      ? 'Item Pesanan'
                      : 'Ordered Items'),
                  const SizedBox(height: 6),
                  ...order.items
                      .map((item) => _buildOrderItem(context, item, order)),

                  const SizedBox(height: 12),

                  // ── Order Notes (Catatan Pesanan) ───────────────────
                  if (order.deliveryNotes != null &&
                      order.deliveryNotes!.trim().isNotEmpty) ...[
                    _buildSectionHeader(lang == AppLanguage.indonesia
                        ? 'Catatan Pesanan'
                        : 'Order Notes'),
                    const SizedBox(height: 6),
                    _buildOrderNotesCard(order.deliveryNotes!, lang),
                    const SizedBox(height: 12),
                  ],

                  // ── Branch / delivery info ─────────────────────────
                  if (order.branchName.isNotEmpty) ...[
                    _buildSectionHeader(lang == AppLanguage.indonesia
                        ? 'Lokasi Outlet'
                        : 'Outlet Location'),
                    const SizedBox(height: 6),
                    _buildBranchCard(context, order, lang),
                    const SizedBox(height: 12),
                  ],

                  if (order.isDelivery && order.deliveryAddress != null) ...[
                    _buildSectionHeader(lang == AppLanguage.indonesia
                        ? 'Alamat Pengiriman'
                        : 'Delivery Address'),
                    const SizedBox(height: 6),
                    _buildDeliveryAddressCard(context, order, lang),
                    const SizedBox(height: 12),
                  ],

                  // ── Payment summary ────────────────────────────────
                  _buildSectionHeader(lang == AppLanguage.indonesia
                      ? 'Ringkasan Pembayaran'
                      : 'Payment Summary'),
                  const SizedBox(height: 6),
                  _buildPaymentCard(context, ref, order, lang,
                      hasExpired: hasExpired),
                  const SizedBox(height: 8),
                  _buildOrderPointCard(context, order, lang,
                      submittedReview: submittedReview),

                  const SizedBox(height: 16),

                  // ── Action buttons ─────────────────────────────────
                  _buildActionButtons(context, ref, order, lang,
                      hasExpired: hasExpired,
                      submittedReview: submittedReview),

                  const SizedBox(height: 60),
                ],
              ),
            );
    } else if (orderDetailsAsync.hasError) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Gagal memuat pesanan:\n${orderDetailsAsync.error.toString()}'
                  : 'Failed to load order:\n${orderDetailsAsync.error.toString()}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(orderDetailsProvider(widget.orderId)),
              child: Text(tr.get('retry', lang)),
            ),
          ],
        ),
      );
    } else {
      bodyContent = const Center(
        child: CircularProgressIndicator(color: Color(0xFFDD2222)),
      );
    }

    return BackButtonWrapper(
      backRoute: '/navigation?index=3',
      onBack: () => context.go('/navigation?index=3'),
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            backRoute: '/navigation?index=3',
            onBack: () => context.go('/navigation?index=3'),
            color: Colors.white,
          ),
          title: Text(tr.get('order_details_title', lang)),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: bodyContent,
      ),
    );
  }

  String _getOrderDurationString(Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    final created = order.createdAt;
    final updated = (order.updatedAt != null && order.updatedAt!.isAfter(created))
        ? order.updatedAt!
        : created;
    final diff = updated.difference(created);
    final totalMinutes = diff.inMinutes;

    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (mins == 0) {
        return isIndo ? '⏱ $hours Jam' : '⏱ $hours Hrs';
      }
      return isIndo ? '⏱ $hours Jam $mins Menit' : '⏱ ${hours}h ${mins}m';
    } else {
      final mins = totalMinutes < 1 ? 1 : totalMinutes;
      return isIndo ? '⏱ $mins Menit' : '⏱ $mins Mins';
    }
  }

  String _formatSimpleDate(dynamic dateVal) {
    DateTime? dt;
    if (dateVal is DateTime) {
      dt = dateVal;
    } else if (dateVal is String) {
      dt = DateTime.tryParse(dateVal);
    }
    if (dt == null) return '';
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  // ─────────────────────────────────────────────────────────────
  // Status card
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatusCard(Order order,
      {required AppLanguage lang, bool hasExpired = false}) {
    final isIndo = lang == AppLanguage.indonesia;
    final color = hasExpired ? Colors.grey : order.statusColor;
    final String statusTitle;
    if (hasExpired) {
      statusTitle = isIndo ? 'KEDALUWARSA' : 'EXPIRED';
    } else if (order.isCompleted) {
      final cleanStatus = order
          .statusDisplayFor(lang)
          .replaceAll('✓', '')
          .trim()
          .toUpperCase();
      statusTitle = '$cleanStatus  ${_getOrderDurationString(order, lang)}';
    } else {
      statusTitle = order.statusDisplayFor(lang).toUpperCase();
    }
    final iconStatus =
        hasExpired ? Icons.hourglass_disabled_rounded : order.statusIcon;

    final IconData typeIcon;
    final String typeLabel;
    final Color typeColor;

    if (order.isDelivery) {
      typeIcon = Icons.delivery_dining_rounded;
      typeLabel = order.orderTypeDisplayFor(lang);
      typeColor = const Color(0xFF6366F1);
    } else if (order.isTakeAway) {
      typeIcon = Icons.shopping_bag_outlined;
      typeLabel = order.orderTypeDisplayFor(lang);
      typeColor = const Color(0xFF0891B2);
    } else {
      typeIcon = Icons.dinner_dining_rounded;
      final tablePrefix = isIndo ? 'Meja' : 'Table';
      final baseType = order.orderTypeDisplayFor(lang);
      typeLabel =
          (order.tableNumber != null && order.tableNumber!.trim().isNotEmpty)
              ? '$baseType • $tablePrefix ${order.tableNumber!.trim()}'
              : baseType;
      typeColor = const Color(0xFF16A34A);
    }

    final isPaidOrNotPending =
        order.isPaid || order.paymentStatus == 'paid' || order.status == 'paid';
    String? remainingTimeStr;
    if (order.isPendingPayment && !isPaidOrNotPending && !hasExpired) {
      final now = DateTime.now();
      final created = order.createdAt;
      final elapsedSec = now.difference(created).inSeconds;
      final methodUpper = order.paymentMethod.toUpperCase();
      final isQris = methodUpper.contains('QRIS') || methodUpper.contains('QR');
      final totalLimitSec = isQris ? 900 : 1800;
      final remainingSec = (totalLimitSec - elapsedSec).clamp(0, totalLimitSec);
      if (remainingSec > 0) {
        final minStr = (remainingSec ~/ 60).toString().padLeft(2, '0');
        final secStr = (remainingSec % 60).toString().padLeft(2, '0');
        remainingTimeStr = '$minStr:$secStr';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 78,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconStatus,
                          size: 22,
                          color: color,
                        ),
                      ),
                      if (remainingTimeStr != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          remainingTimeStr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${order.orderNumber.isNotEmpty ? order.orderNumber : widget.orderId}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.formattedDate,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            typeIcon,
                            size: 13,
                            color: typeColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Order Estimation Hero Card
  // ─────────────────────────────────────────────────────────────
  Widget _buildOrderEstimationCard(Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    final isDelivery = order.isDelivery;
    final isReadyOrCompleted = order.isReady ||
        order.isReadyForPickup ||
        order.isCompleted ||
        order.status == 'ready' ||
        order.status == 'ready_for_pickup' ||
        order.status == 'completed';

    final title = isReadyOrCompleted
        ? (isIndo ? 'Waktu Pesanan Siap' : 'Order Ready Time')
        : (isIndo ? 'Estimasi Pesanan Siap' : 'Estimated Ready Time');

    final isAcceptedOrProcessing = !isReadyOrCompleted &&
        (order.isAccepted ||
            order.isConfirmed ||
            order.isPreparing ||
            order.isDelivering ||
            order.status == 'accepted' ||
            order.status == 'confirmed' ||
            order.status == 'preparing' ||
            order.status == 'cooking' ||
            order.status == 'processing' ||
            order.status == 'picking_up' ||
            order.status == 'picked_up' ||
            order.status == 'in_delivery' ||
            order.status == 'out_for_delivery');

    Color accentColor;
    Color lightBg;
    Color borderColor;
    IconData cardIcon;
    String subtitle;

    if (isReadyOrCompleted) {
      accentColor = const Color(0xFF16A34A);
      lightBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFDCFCE7);
      cardIcon = isDelivery
          ? Icons.local_shipping_outlined
          : (order.isTakeAway
              ? Icons.shopping_bag_outlined
              : Icons.restaurant_rounded);
      final readyTime = order.displayReadyTime;
      subtitle = isIndo
          ? 'Pesanan telah siap pukul $readyTime WIB'
          : 'Order was ready at $readyTime';
    } else if (isAcceptedOrProcessing) {
      accentColor = const Color(0xFFDD6B20);
      lightBg = const Color(0xFFFFFBF5);
      borderColor = const Color(0xFFFFEDD5);
      cardIcon = isDelivery ? Icons.moped_rounded : Icons.soup_kitchen_rounded;
      final targetStr = order.displayTargetTime;
      if (isDelivery) {
        subtitle = isIndo
            ? 'Tiba pada pukul ±$targetStr WIB'
            : 'Estimated arrival at ±$targetStr';
      } else {
        subtitle = isIndo
            ? 'Selesai pada pukul ±$targetStr WIB'
            : 'Estimated ready at ±$targetStr';
      }
    } else {
      // Sebelum pesanan diterima (Menunggu Pembayaran / Menunggu Dikonfirmasi)
      accentColor = const Color(0xFFDD6B20);
      lightBg = const Color(0xFFFFFBF5);
      borderColor = const Color(0xFFFFEDD5);
      cardIcon = Icons.schedule_rounded;
      subtitle = isIndo
          ? 'Menunggu pesanan diterima'
          : 'Waiting for order acceptance';
    }

    return Container(
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              cardIcon,
              size: 18,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Delivery driver card (GrabExpress Info & Live Tracking)
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  // Delivery driver card (GrabExpress Info & Live Tracking)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDeliveryDriverCard(Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    final driver = order.grabDriver;
    final driverName = (driver != null &&
            driver['name'] != null &&
            driver['name'].toString().trim().isNotEmpty)
        ? driver['name'].toString().trim()
        : null;
    final driverPhone = (driver != null &&
            driver['phone'] != null &&
            driver['phone'].toString().trim().isNotEmpty)
        ? driver['phone'].toString().trim()
        : null;
    final driverPlate = (driver != null &&
            (driver['license_plate'] != null ||
                driver['licensePlate'] != null ||
                driver['vehicle_plate'] != null))
        ? (driver['license_plate'] ??
                driver['licensePlate'] ??
                driver['vehicle_plate'])
            .toString()
            .trim()
        : null;
    final driverModel = (driver != null &&
            (driver['vehicle_model'] != null ||
                driver['vehicleModel'] != null))
        ? (driver['vehicle_model'] ?? driver['vehicleModel'])
            .toString()
            .trim()
        : null;
    final hasDriver = driverName != null;
    final trackUrl = order.trackUrl;
    final hasTrackUrl = trackUrl != null && trackUrl.trim().isNotEmpty;
    final isDelivered = order.isCompleted ||
        order.status == OrderStatus.completed ||
        order.status == 'delivered' ||
        order.status == 'terkirim';
    final deliveryCompletedTime = order.updatedAt ?? order.createdAt;
    final isDeliveredOver1Hour = isDelivered &&
        DateTime.now().difference(deliveryCompletedTime).inMinutes >= 60;

    // Delivery status label & color
    String statusText;
    Color statusBgColor;
    Color statusTextColor;
    Color statusBorderColor;

    if (order.status == OrderStatus.completed) {
      statusText = isIndo ? 'Pesanan Terkirim' : 'Order Delivered';
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF15803D);
      statusBorderColor = const Color(0xFF86EFAC);
    } else if (order.status == OrderStatus.inDelivery) {
      statusText = isIndo ? 'Dalam Pengantaran' : 'In Delivery';
      statusBgColor = const Color(0xFFF3E8FF);
      statusTextColor = const Color(0xFF7E22CE);
      statusBorderColor = const Color(0xFFD8B4FE);
    } else if (order.status == OrderStatus.pickedUp) {
      statusText = isIndo ? 'Makanan Diambil Kurir' : 'Food Picked Up';
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF1D4ED8);
      statusBorderColor = const Color(0xFFBFDBFE);
    } else if (hasDriver || order.status == OrderStatus.pickingUp) {
      statusText = isIndo ? 'Kurir Menuju Resto' : 'Driver Heading to Resto';
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF15803D);
      statusBorderColor = const Color(0xFF86EFAC);
    } else {
      statusText = isIndo ? 'Mencari Driver...' : 'Finding Driver...';
      statusBgColor = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFB45309);
      statusBorderColor = const Color(0xFFFDE68A);
    }

    // Dynamic driver subtitle message
    String driverSubtitle;
    if (order.isCompleted) {
      driverSubtitle = isIndo
          ? 'Pesanan telah berhasil diantar'
          : 'Order successfully delivered';
    } else if (order.status == OrderStatus.inDelivery) {
      driverSubtitle = isIndo
          ? 'Kurir sedang dalam perjalanan mengantarkan pesanan ke lokasimu'
          : 'Driver is on the way to your location';
    } else if (order.status == OrderStatus.pickedUp) {
      driverSubtitle = isIndo
          ? 'Kurir telah mengambil pesanan dari restoran'
          : 'Driver has picked up the food from the outlet';
    } else if (hasDriver || order.status == OrderStatus.pickingUp) {
      driverSubtitle = isIndo
          ? 'Kurir sedang menuju restoran untuk mengambil pesananmu'
          : 'Driver is heading to the outlet to pick up your order';
    } else {
      driverSubtitle = isIndo
          ? 'Menghubungkan ke driver Grab terdekat di sekitar restoran'
          : 'Connecting to nearby Grab driver';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF00B14F).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF00B14F).withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B14F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GrabExpress Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusBorderColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar / Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (order.isCompleted || hasDriver)
                            ? const Color(0xFF00B14F).withValues(alpha: 0.1)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (order.isCompleted || hasDriver)
                              ? const Color(0xFF00B14F).withValues(alpha: 0.3)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Icon(
                        order.isCompleted
                            ? Icons.check_circle_rounded
                            : (hasDriver
                                ? Icons.person_rounded
                                : Icons.search_rounded),
                        color: (order.isCompleted || hasDriver)
                            ? const Color(0xFF00B14F)
                            : Colors.grey[500],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Driver info texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.isCompleted
                                ? (hasDriver
                                    ? 'Kurir Grab: $driverName'
                                    : (isIndo
                                        ? 'Kurir Grab Express'
                                        : 'GrabExpress Courier'))
                                : (hasDriver
                                    ? 'Kurir Grab: $driverName'
                                    : (order.status == OrderStatus.pickingUp
                                        ? (isIndo
                                            ? 'Kurir Menuju Restoran'
                                            : 'Driver Heading to Resto')
                                        : (order.status == OrderStatus.pickedUp ||
                                                order.status ==
                                                    OrderStatus.inDelivery
                                            ? (isIndo
                                                ? 'Kurir Mengantar Pesanan'
                                                : 'Driver Delivering Order')
                                            : (isIndo
                                                ? 'Mencari driver Grab...'
                                                : 'Finding Grab driver...')))),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: (order.isCompleted || hasDriver)
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasDriver && (driverPlate != null || driverModel != null)) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (driverModel != null && driverModel.isNotEmpty) driverModel,
                                if (driverPlate != null && driverPlate.isNotEmpty) driverPlate,
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            driverSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: order.isCompleted
                                  ? const Color(0xFF15803D)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Call button if driver has phone
                    if (driverPhone != null && driverPhone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: () async {
                          final uri = Uri.parse('tel:$driverPhone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF00B14F),
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        tooltip: isIndo ? 'Hubungi Driver' : 'Call Driver',
                      ),
                    ],
                  ],
                ),

                // Live Tracking Button (automatically hidden if delivered and over 1 hour has passed)
                if (hasTrackUrl && !isDeliveredOver1Hour) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(trackUrl);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B14F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 17),
                      label: Text(
                        isIndo
                            ? 'Lacak Posisi Driver (Live Map)'
                            : 'Track Driver Live Map',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ] else if (!order.isCompleted && !order.isCancelled) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isIndo
                                ? 'Peta Live Tracking akan aktif saat kurir menerima order.'
                                : 'Live Tracking map will be available once driver is assigned.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey[600],
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
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cancel reason card
  // ─────────────────────────────────────────────────────────────
  Widget _buildCancelReasonCard(String reason) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alasan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Progress timeline — adaptive per order type
  // ─────────────────────────────────────────────────────────────
  Widget _buildOrderTimeline(Order order, AppLanguage lang) {
    _ensureTimelineProgressAnimation();
    final timelineProgressAnimation = _timelineProgressAnimation!;
    final steps = _getTimelineSteps(order, lang);
    final isIndo = lang == AppLanguage.indonesia;

    // Find current or latest active/done step
    final latestStep = steps.lastWhere(
      (s) => (s['done'] as bool) || (s['active'] as bool),
      orElse: () => steps.first,
    );
    final latestTitle = latestStep['title'] as String;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Progres Pesanan" + Dropdown Box Button
            InkWell(
              onTap: () {
                setState(() {
                  _isTimelineExpanded = !_isTimelineExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isIndo ? 'Progres Pesanan' : 'Order Progress',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF800000), width: 1.2),
                    ),
                    child: Icon(
                      _isTimelineExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF800000),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle: Status Terbaru
            Row(
              children: [
                Text(
                  isIndo ? 'Status Terbaru: ' : 'Latest Status: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          latestTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // When expanded, show the full list of steps
            if (_isTimelineExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              const SizedBox(height: 8),
              ...List.generate(steps.length, (index) {
                final step = steps[index];
                final isDone = step['done'] as bool;
                final isNow = step['active'] as bool;
                final isLast = index == steps.length - 1;
                // Animate the already-completed connector into the current
                // status, so it feels like the progress line is filling it.
                final isFinalActive = isNow && isLast;
                final showProgressArrival = isNow &&
                    !isLast &&
                    index > 0 &&
                    (steps[index - 1]['done'] as bool);
                final isConnectorToActive =
                    isDone && !isLast && (steps[index + 1]['active'] as bool);
                final isConnectorToFinalStatus =
                    isConnectorToActive && index + 1 == steps.length - 1;
                final dotColor = (isDone || isNow)
                    ? const Color(0xFFDD2222)
                    : Colors.grey[300]!;

                return TimelineTile(
                  isFirst: index == 0,
                  isLast: isLast,
                  beforeLineStyle: LineStyle(
                    color: (isDone || isFinalActive)
                        ? const Color(0xFFDD2222)
                        : Colors.grey[300]!,
                    thickness: 2,
                  ),
                  // Do not leave a static half-red connector before the
                  // active step. The moving dot is the only red progress cue.
                  afterLineStyle: LineStyle(
                    color: isDone &&
                            (!isConnectorToActive ||
                                isConnectorToFinalStatus)
                        ? const Color(0xFFDD2222)
                        : Colors.grey[300]!,
                    thickness: 2,
                  ),
                  indicatorStyle: IndicatorStyle(
                    width: 18,
                    height: 18,
                    indicator: isFinalActive
                        ? _FinalTimelineIndicator(
                            animation: timelineProgressAnimation,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                            child: isNow
                                ? _ActiveTimelineIndicator(
                                    animation: timelineProgressAnimation,
                                    animateFill: showProgressArrival,
                                  )
                                : (isDone
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 11,
                                      )
                                    : null),
                          ),
                  ),
                  endChild: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                step['title'] as String,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: (isDone || isNow)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: (isDone || isNow)
                                      ? Colors.black87
                                      : Colors.grey[500],
                                ),
                              ),
                            ),
                            if (step['time'] != null)
                              Text(
                                step['time'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: (isDone || isNow)
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: (isDone || isNow)
                                      ? const Color(0xFFDD2222)
                                      : Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (step['sub'] != null)
                          Text(
                            step['sub'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey[500],
                            ),
                          ),
                          ],
                        ),
                      ),
                      if (showProgressArrival)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _TimelineProgressDot(
                              animation: timelineProgressAnimation,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getTimelineSteps(Order order, AppLanguage lang) {
    final sequence = _statusSequence(order);
    final currentIndex = _getCurrentStatusIndex(order, sequence);

    return sequence.map((s) {
      final stepIndex = sequence.indexOf(s);
      final isDone = (currentIndex >= 0 && stepIndex < currentIndex) ||
          order.isCompleted ||
          order.isCancelled;
      final isNow = currentIndex >= 0 && stepIndex == currentIndex;

      String? timeStr;
      if (isDone || isNow) {
        final stepTime =
            _getStepTime(s, order, sequence, stepIndex, currentIndex);
        if (stepTime != null) {
          timeStr = _formatStepTime(stepTime);
        }
      }

      return {
        'title': _stepLabel(s, order, lang),
        'sub': _stepSub(s, lang),
        'done': isDone,
        'active': isNow,
        'time': timeStr,
      };
    }).toList();
  }

  Widget _buildAdminCancelRequestCard(BuildContext context, WidgetRef ref,
      Order order, String reason, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    final isPaid = order.isPaid ||
        order.paymentStatus.toLowerCase() == 'paid' ||
        order.status.toLowerCase() == 'paid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA000).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECB3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE65100),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPaid
                      ? (isIndo ? 'Pemberitahuan dari Outlet' : 'Notice from Outlet')
                      : (isIndo
                          ? 'Permintaan Pembatalan dari Outlet'
                          : 'Cancellation Request from Outlet'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPaid
                ? (isIndo
                    ? 'Outlet menginfokan ada kendala pada pesanan Anda:'
                    : 'The outlet reported an issue with your order:')
                : (isIndo
                    ? 'Outlet meminta Anda membatalkan pesanan ini karena:'
                    : 'The outlet requested you to cancel this order due to:'),
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4E342E),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Text(
              '"$reason"',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE65100),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (isPaid) ...[
            const SizedBox(height: 10),
            Text(
              isIndo
                  ? 'Pesanan ini sudah dibayar. Silakan hubungi outlet melalui WhatsApp di bawah untuk konfirmasi penggantian menu atau bantuan pembatalan.'
                  : 'This order is already paid. Please contact the outlet via WhatsApp below to confirm item replacement or cancellation assistance.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF78350F),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (order.branchPhone != null && order.branchPhone!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsAppOutlet(context, order, lang),
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    isIndo
                        ? 'Hubungi Outlet via WhatsApp'
                        : 'Contact Outlet via WhatsApp',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCancelDialog(context, ref, order),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(
                        isIndo ? 'Batalkan Pesanan' : 'Cancel Order',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (order.branchPhone != null &&
                    order.branchPhone!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _launchWhatsAppOutlet(context, order, lang),
                      icon: const Icon(Icons.chat_rounded,
                          size: 15, color: Color(0xFF25D366)),
                      label: Text(
                        isIndo ? 'Tanya via WA' : 'Chat via WA',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF86EFAC)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _getStepTime(String stepStatus, Order order, List<String> sequence,
      int stepIndex, int currentIndex) {
    if (stepIndex > currentIndex && !order.isCompleted && !order.isCancelled) {
      return null;
    }

    final localCreated = order.createdAt.toLocal();
    final localUpdated = (order.updatedAt ?? order.createdAt).toLocal();

    if (stepIndex == 0) {
      return localCreated;
    }

    if (stepIndex == currentIndex ||
        (stepStatus == OrderStatus.completed && order.isCompleted)) {
      return localUpdated;
    }

    // Ensure strictly increasing chronological timeline across completed steps
    final activeIndex = order.isCompleted ? sequence.length - 1 : currentIndex;
    final totalDuration = localUpdated.difference(localCreated);

    if (activeIndex > 0 && totalDuration.inSeconds > 0) {
      final fraction = stepIndex / activeIndex;
      return localCreated
          .add(Duration(seconds: (totalDuration.inSeconds * fraction).toInt()));
    } else {
      // Fallback: strictly increasing 1 minute per step from created time
      return localCreated.add(Duration(minutes: stepIndex));
    }
  }

  String _formatStepTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm WIB';
  }

  int _getCurrentStatusIndex(Order order, List<String> sequence) {
    final status = order.status;
    final idx = sequence.indexOf(status);
    if (idx != -1) return idx;

    // Handle mapping aliases for delivery
    if (order.isDelivery) {
      if (status == OrderStatus.readyForPickup || status == OrderStatus.ready) {
        // Kitchen finished preparing food, food is ready for driver pickup / courier heading to outlet
        return sequence.indexOf(OrderStatus.pickingUp);
      }
    }

    if (status == OrderStatus.ready && order.isTakeAway) {
      return sequence.indexOf(OrderStatus.readyForPickup);
    }

    return -1;
  }

  List<String> _statusSequence(Order order) {
    if (order.isDelivery) {
      return [
        OrderStatus.pendingPayment,
        OrderStatus.paid,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.pickingUp,
        OrderStatus.pickedUp,
        OrderStatus.inDelivery,
        OrderStatus.completed,
      ];
    } else if (order.isTakeAway) {
      return [
        OrderStatus.pendingPayment,
        OrderStatus.paid,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.readyForPickup,
        OrderStatus.completed,
      ];
    } else {
      return [
        OrderStatus.pendingPayment,
        OrderStatus.paid,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.completed,
      ];
    }
  }

  String _stepLabel(String status, Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    switch (status) {
      case OrderStatus.pendingPayment:
        return isIndo ? 'Menunggu Pembayaran' : 'Pending Payment';
      case OrderStatus.paid:
        return isIndo ? 'Pembayaran Berhasil' : 'Payment Success';
      case OrderStatus.confirmed:
        return isIndo ? 'Pesanan Diterima' : 'Order Confirmed';
      case OrderStatus.preparing:
        return isIndo ? 'Sedang Disiapkan' : 'Preparing';
      case OrderStatus.ready:
        return isIndo ? 'Siap Disajikan' : 'Ready to Serve';
      case OrderStatus.readyForPickup:
        return order.isDelivery
            ? (isIndo
                ? 'Pesanan Siap Diambil Kurir'
                : 'Ready for Driver Pickup')
            : (isIndo ? 'Siap Diambil' : 'Ready for Pickup');
      case OrderStatus.pickingUp:
        return isIndo ? 'Kurir Menuju Restoran' : 'Courier Heading to Outlet';
      case OrderStatus.pickedUp:
        return isIndo ? 'Pesanan Diambil Kurir' : 'Picked Up by Courier';
      case OrderStatus.inDelivery:
      case OrderStatus.outForDelivery:
        return isIndo ? 'Dalam Pengiriman' : 'Out for Delivery';
      case OrderStatus.completed:
        if (order.isDelivery) {
          return isIndo ? 'Pesanan Terkirim' : 'Order Delivered';
        }
        if (order.isTakeAway) {
          return isIndo ? 'Sudah Diambil' : 'Picked Up';
        }
        return isIndo ? 'Pesanan Selesai' : 'Completed';
      default:
        return status;
    }
  }

  String? _stepSub(String status, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    switch (status) {
      case OrderStatus.pendingPayment:
        return isIndo
            ? 'Lakukan pembayaran untuk melanjutkan'
            : 'Please make payment to continue';
      case OrderStatus.paid:
        return isIndo
            ? 'Menunggu konfirmasi restoran'
            : 'Waiting for restaurant confirmation';
      case OrderStatus.confirmed:
        return isIndo
            ? 'Restoran menerima pesanan Anda'
            : 'Restaurant accepted your order';
      case OrderStatus.preparing:
        return isIndo ? 'Dapur sedang menyiapkan' : 'Kitchen is preparing';
      case OrderStatus.ready:
        return isIndo
            ? 'Makanan siap di meja Anda'
            : 'Food is ready at your table';
      case OrderStatus.readyForPickup:
        return isIndo
            ? 'Silakan ambil di outlet'
            : 'Please pick up at the outlet';
      case OrderStatus.pickingUp:
        return isIndo
            ? 'Kurir sedang dalam perjalanan ke restoran'
            : 'Courier is heading to the restaurant';
      case OrderStatus.pickedUp:
        return isIndo
            ? 'Pesanan telah diambil oleh kurir'
            : 'Order has been picked up by courier';
      case OrderStatus.inDelivery:
      case OrderStatus.outForDelivery:
        return isIndo
            ? 'Kurir sedang mengantar pesanan'
            : 'Courier is delivering your order';
      case OrderStatus.completed:
        return isIndo
            ? 'Terima kasih sudah memesan!'
            : 'Thank you for ordering!';
      default:
        return null;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildGoldPointBadge({double size = 26}) {
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
          fontSize: size * 0.58,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _launchGoogleMaps({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    Uri? uri;
    final cleanAddress = address?.trim();
    if (cleanAddress != null && cleanAddress.isNotEmpty) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanAddress)}');
    } else if (latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    }

    if (uri != null) {
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri);
        }
      } catch (e) {
        debugPrint('Failed to open Google Maps: $e');
      }
    }
  }

  Widget _buildOrderItem(
      BuildContext context, OrderDetail item, Order order) {
    final imageUrl = _resolveImageUrl(item.menuImage ?? item.productImage);
    final targetMenuId = item.targetMenuId;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (targetMenuId > 0) {
            final branchQuery =
                order.branchId > 0 ? '?branchId=${order.branchId}' : '';
            context.push('/product/$targetMenuId$branchQuery');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _imagePlaceholder(),
                        errorWidget: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Rp ${item.formattedPrice}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDD2222),
                          ),
                        ),
                        if (item.hasPromo && item.originalPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Rp ${item.formattedOriginalPrice ?? Helpers.formatNumber(item.originalPrice!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.grey.shade400,
                            ),
                          ),
                          if (item.discountPercentage != null &&
                              item.discountPercentage! > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${item.discountPercentage}%',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                    if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 13, color: Color(0xFFEA580C)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${ref.watch(appLanguageProvider) == AppLanguage.indonesia ? "Catatan Khusus" : "Special Notes"}: ${item.notes!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC2410C),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'x${item.quantity}',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
      width: 50,
      height: 50,
      color: Colors.grey[100],
      child: const Icon(Icons.fastfood, size: 22, color: Colors.grey));

  Widget _buildBranchCard(BuildContext context, Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final bName = order.branchName.trim();
                final bAddr = (order.branchAddress ?? '').trim();
                String query = bAddr;
                if (bName.isNotEmpty) {
                  if (query.isEmpty) {
                    query = bName;
                  } else if (!query.toLowerCase().contains(bName.toLowerCase())) {
                    query = '$bName, $query';
                  }
                }
                _launchGoogleMaps(
                  address: query.isNotEmpty ? query : null,
                  latitude: order.branchLat,
                  longitude: order.branchLong,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: order.brandLogo != null &&
                              order.brandLogo!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _resolveImageUrl(order.brandLogo),
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => _storeIcon(),
                            )
                          : _storeIcon(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.branchName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          if (order.branchAddress != null &&
                              order.branchAddress!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              order.branchAddress!,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.normal),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!order.isCompleted && !order.isCancelled && !order.isRejected) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    _showContactOutletPatienceDialog(context, order, lang),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                        isIndo
                            ? 'Ada kendala dengan pesanan? Hubungi Outlet'
                            : 'Need help with order? Contact Outlet',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showContactOutletPatienceDialog(
      BuildContext context, Order order, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF16A34A),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isIndo
                    ? 'Hubungi Outlet ${order.branchName}'
                    : 'Contact Outlet ${order.branchName}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Text(
                          isIndo
                              ? 'Estimasi Waktu: ${order.displayRangeTextLang(lang)}'
                              : 'Estimated Time: ${order.displayRangeTextLang(lang)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isIndo
                          ? 'Dapur kami sedang menyiapkan pesanan Anda dengan segar dan teliti. Pada jam ramai, proses penyajian membutuhkan sedikit waktu. Mohon kesediaannya menunggu ya! 🙂'
                          : 'Our kitchen is carefully preparing your meal fresh. During peak hours, preparation takes some time. Thank you for your patience! 🙂',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isIndo ? 'Baik, Saya Akan Menunggu' : 'Okay, I Will Wait',
                    style: const TextStyle(
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _launchWhatsAppOutlet(context, order, lang);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.whatsapp,
                          size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        isIndo
                            ? 'Tetap butuh bantuan mendesak? Chat via WA'
                            : 'Still need urgent help? Chat via WA',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _storeIcon() => Container(
      width: 40,
      height: 40,
      color: const Color(0xFFFFEBEE),
      child: const Icon(Icons.storefront, size: 22, color: Color(0xFFDD2222)));

  Widget _buildOrderNotesCard(String notes, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange[200]!),
      ),
      color: const Color(0xFFFFFBF5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sticky_note_2_rounded,
                color: Color(0xFFEA580C),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIndo
                        ? 'Instruksi / Catatan Tambahan'
                        : 'Order Notes / Special Instructions',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC2410C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notes.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF431407),
                      height: 1.3,
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

  Widget _buildDeliveryAddressCard(
      BuildContext context, Order order, AppLanguage lang) {
    final address = order.deliveryAddress ?? '';
    final notes = order.deliveryNotes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _launchGoogleMaps(
            address: address,
            latitude: order.deliverLat,
            longitude: order.deliverLong,
          );
        },
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFDD2222),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  if (hasNotes) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              size: 13, color: Color(0xFFEA580C)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${lang == AppLanguage.indonesia ? "Catatan Alamat/Kurir" : "Address/Courier Notes"}: ${notes.trim()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2410C),
                                height: 1.25,
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
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPaymentCard(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang,
      {bool hasExpired = false}) {
    final isExpired = hasExpired || order.isExpired;
    final isPaid = !isExpired && order.isPaymentPaid;
    final isIndo = lang == AppLanguage.indonesia;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          children: [
            if (order.totalPromoSavings > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isIndo
                            ? '🎉 Kamu hemat Rp ${Helpers.formatNumber(order.totalPromoSavings)} pada pesanan ini!'
                            : '🎉 You saved Rp ${Helpers.formatNumber(order.totalPromoSavings)} on this order!',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _paymentRow('Subtotal', order.subtotal),
            _paymentRow(isIndo ? 'Pajak' : 'Tax', order.tax),
            _paymentRow(isIndo ? 'Layanan' : 'Service Fee', order.service),
            if (order.deliveryFee > 0)
              _paymentRow(tr.get('delivery_fee', lang), order.deliveryFee),
            if (order.discount > 0)
              _paymentRow(isIndo ? 'Diskon' : 'Discount', -order.discount,
                  isDiscount: true),
            const Divider(height: 14),
            _paymentRow('Total', order.totalAmount, isTotal: true),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr.get('payment_method', lang),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.normal)),
                Text(
                  _formatPaymentMethod(order.paymentMethod, lang),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF111827)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr.get('payment_status', lang),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.normal)),
                Text(
                  isPaid
                      ? (isIndo ? 'LUNAS' : 'PAID')
                      : (isExpired
                          ? (isIndo ? 'KEDALUWARSA' : 'EXPIRED')
                          : (isIndo ? 'BELUM LUNAS' : 'UNPAID')),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            if (isPaid) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _showReceiptModal(
                    context,
                    order,
                    lang,
                    currentUserName: currentUser?.name,
                    currentUserPhone: currentUser?.phoneNumber,
                  ),
                  icon: const Icon(Icons.receipt_long_rounded,
                      size: 16, color: Color(0xFFDD2222)),
                  label: Text(
                    isIndo ? 'Lihat E-Struk Pesanan' : 'View Order E-Receipt',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFFDD2222),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: const Size(0, 38),
                    side:
                        const BorderSide(color: Color(0xFFDD2222), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    final formatted = amount.abs().toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 12.5,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isDiscount ? Colors.green[700] : const Color(0xFF111827),
              )),
          Text(
            '${isDiscount ? '-' : ''}Rp $formatted',
            style: TextStyle(
              fontSize: isTotal ? 14 : 12.5,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? const Color(0xFFDD2222)
                  : isDiscount
                      ? Colors.green[700]
                      : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPointCard(
      BuildContext context, Order order, AppLanguage lang,
      {Map<String, dynamic>? submittedReview}) {
    final isIndo = lang == AppLanguage.indonesia;
    final hasEarnedPoint =
        order.isCompleted && order.paymentStatus == 'paid' && order.point > 0;
    final hasNoPoint = order.isCancelled ||
        order.isRejected ||
        order.isPaymentFailed ||
        order.isExpired;
    final subtitle = hasEarnedPoint
        ? (isIndo
            ? 'berhasil mendapatkan +${order.point} poin.'
            : 'earned +${order.point} points.')
        : hasNoPoint
            ? (isIndo
                ? 'Pesanan ini tidak mendapatkan poin'
                : 'This order does not earn points')
            : (isIndo
                ? 'Poin akan masuk setelah pesanan selesai'
                : 'Points will be added after the order is completed');

    final isOlderThan7Days =
        DateTime.now().difference(order.createdAt).inDays > 7;
    final showArchivedReview =
        order.isCompleted && isOlderThan7Days && submittedReview != null;

    String? reviewDateStr;
    if (showArchivedReview) {
      final rawDate = submittedReview['updatedAt'] ??
          submittedReview['created_at'] ??
          submittedReview['date'] ??
          order.createdAt;
      reviewDateStr = _formatSimpleDate(rawDate);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/vouchers?tab=points'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildGoldPointBadge(size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIndo
                              ? 'Dapatkan poin dari transaksi ini'
                              : 'Earn points from this transaction',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasEarnedPoint
                                ? Colors.green[700]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showArchivedReview) ...[
                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isIndo
                            ? 'Anda sudah memberikan penilaian ($reviewDateStr)'
                            : 'You have submitted a review ($reviewDateStr)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
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
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang,
      {bool hasExpired = false, Map<String, dynamic>? submittedReview}) {
    if (order.isCompleted) {
      final reviewCard = _buildReviewPromptCard(context, ref, order, lang,
          submittedReview: submittedReview);
      final hasReviewCard = reviewCard is! SizedBox;

      return Column(
        children: [
          if (hasReviewCard) ...[
            reviewCard,
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _handleReorder(context, ref, order),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr.get('reorder_btn', lang)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    if (order.isCancelled || order.isRejected || hasExpired) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _handleReorder(context, ref, order),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr.get('reorder_btn', lang)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD2222),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    final hasActiveCancelRequest = !order.isRejected &&
        !order.isCancelled &&
        !hasExpired &&
        order.cancelReason != null &&
        order.cancelReason!.trim().isNotEmpty;

    if (hasActiveCancelRequest) {
      final isIndo = lang == AppLanguage.indonesia;
      final isOrderPaid = order.isPaid ||
          order.paymentStatus.toLowerCase() == 'paid' ||
          order.status.toLowerCase() == 'paid';

      if (isOrderPaid) {
        if (order.branchPhone != null && order.branchPhone!.isNotEmpty) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _launchWhatsAppOutlet(context, order, lang),
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 20,
                color: Colors.white,
              ),
              label: Text(
                isIndo
                    ? 'Hubungi Outlet via WhatsApp'
                    : 'Contact Outlet via WhatsApp',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      }

      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _showCancelDialog(context, ref, order),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(isIndo ? 'Batalkan Pesanan' : 'Cancel Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    final isCash = order.paymentMethod.toLowerCase() == 'cash' ||
        order.paymentMethod.toLowerCase() == 'tunai';
    final isPaidOrNotPending =
        order.isPaid || order.paymentStatus == 'paid' || order.status == 'paid';

    if (order.isPendingPayment && !isPaidOrNotPending) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (isCash) {
                  final orderNum = order.orderNumber.isNotEmpty
                      ? order.orderNumber
                      : order.id.toString();
                  context.go(
                      '/cash-payment?orderId=$orderNum&amount=${order.totalAmount}');
                } else {
                  context.go(
                      '/payment/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(tr.get('pay_now_btn', lang)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showCancelDialog(context, ref, order),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(tr.get('cancel_order_btn', lang)),
            ),
          ),
        ],
      );
    }

    final status = order.status.toLowerCase();

    if (status == 'ready' ||
        status == 'ready_for_pickup' ||
        status == 'out_for_delivery' ||
        status == 'in_delivery' ||
        status == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () async {
            final isIndo = lang == AppLanguage.indonesia;
            final confirmed = await AppDialog.showConfirm(
              context: context,
              title: isIndo
                  ? 'Konfirmasi Pesanan Diterima'
                  : 'Confirm Order Received',
              message: isIndo
                  ? 'Apakah Anda yakin sudah menerima pesanan ini dengan baik dan lengkap?'
                  : 'Are you sure you have received this order completely and in good condition?',
              confirmText: isIndo ? 'Ya, Sudah' : 'Yes',
              cancelText: isIndo ? 'Batal' : 'Cancel',
              confirmColor: const Color(0xFFDD2222),
              showIcon: false,
              type: AppDialogType.info,
            );
            if (!confirmed || !context.mounted) return;

            try {
              final userId = await ref.read(currentUserIdProvider.future);
              final targetId = order.orderNumber.isNotEmpty
                  ? order.orderNumber
                  : order.id.toString();
              await ref
                  .read(orderControllerProvider.notifier)
                  .completeOrder(targetId, userId!);
              if (context.mounted) {
                Helpers.showSnackbar(
                    context, tr.get('order_confirmed_success', lang),
                    backgroundColor: Colors.green);
                ref.invalidate(orderDetailsProvider(widget.orderId));
              }
            } catch (e) {
              if (context.mounted) {
                Helpers.showSnackbar(
                    context, '${tr.get('order_confirm_failed', lang)}: $e',
                    backgroundColor: Colors.red);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD2222),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            tr.get('order_received', lang),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Order order) {
    final lang = ref.read(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    final isOrderPaid = order.isPaid ||
        order.paymentStatus.toLowerCase() == 'paid' ||
        order.status.toLowerCase() == 'paid';
    if (isOrderPaid) {
      Helpers.showSnackbar(
        context,
        isIndo
            ? 'Pesanan sudah dibayar. Silakan hubungi outlet melalui WhatsApp untuk bantuan pembatalan atau pergantian menu.'
            : 'Order is already paid. Please contact the outlet via WhatsApp for cancellation assistance or item replacement.',
        backgroundColor: Colors.orange[800],
      );
      return;
    }

    final reasonsList = isIndo
        ? [
            if (order.cancelReason != null &&
                order.cancelReason!.trim().isNotEmpty)
              order.cancelReason!.trim(),
            'Ingin mengubah pesanan / menu',
            'Salah memilih lokasi outlet',
            'Waktu tunggu terlalu lama',
            'Lainnya',
          ]
        : [
            if (order.cancelReason != null &&
                order.cancelReason!.trim().isNotEmpty)
              order.cancelReason!.trim(),
            'Want to change order items',
            'Selected wrong outlet location',
            'Wait time is too long',
            'Other',
          ];

    String selectedReason = reasonsList.first;
    bool isCustom = false;
    final customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text(tr.get('cancel_order_btn', lang),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIndo
                      ? 'Pilih alasan pembatalan:'
                      : 'Select cancellation reason:',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      selectedReason = val;
                      isCustom = val == (isIndo ? 'Lainnya' : 'Other');
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: reasonsList.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedReason = reason;
                            isCustom = reason == (isIndo ? 'Lainnya' : 'Other');
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Radio<String>(
                                  value: reason,
                                  activeColor: const Color(0xFFDD2222),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                    horizontal: VisualDensity.minimumDensity,
                                    vertical: VisualDensity.minimumDensity,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFF334155),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customReasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: isIndo
                          ? 'Tuliskan alasan Anda...'
                          : 'Write your reason...',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFDD2222)),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr.get('no', lang),
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.normal)),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = isCustom
                    ? customReasonController.text.trim()
                    : selectedReason;
                if (isCustom && reason.isEmpty) {
                  Helpers.showSnackbar(
                      context, tr.get('cancel_reason_prompt', lang),
                      backgroundColor: Colors.orange);
                  return;
                }

                Navigator.pop(ctx);
                try {
                  final userId = await ref.read(currentUserIdProvider.future);
                  await ref
                      .read(orderControllerProvider.notifier)
                      .cancelOrder(order.id, userId!, reason);

                  if (!context.mounted) return;
                  Helpers.showSnackbar(
                      context, tr.get('order_cancelled_success_msg', lang),
                      backgroundColor: Colors.green);
                  ref.invalidate(orderDetailsProvider(widget.orderId));
                } catch (e) {
                  if (!context.mounted) return;
                  Helpers.showSnackbar(
                      context, '${tr.get('failed_cancel_order_msg', lang)}: $e',
                      backgroundColor: Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(isIndo ? 'Ya, Batalkan' : 'Yes, Cancel',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(BuildContext context, WidgetRef ref, Order order) async {
    if (context.mounted) {
      context.go('/brand-branch-selection');
    }
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final t = path.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (t.startsWith('/')) return 'https://aplikasi.mannagroup.id$t';
    return 'https://aplikasi.mannagroup.id/storage/$t';
  }

  String _formatPaymentMethod(String? method, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    switch (method?.toLowerCase()) {
      case 'qris':
        return 'QRIS';
      case 'va':
        return 'Virtual Account';
      case 'cash':
        return isIndo ? 'Tunai' : 'Cash';
      default:
        return method ?? '-';
    }
  }

  Future<void> _launchWhatsAppOutlet(
      BuildContext context, Order order, AppLanguage lang) async {
    final isIndo = lang == AppLanguage.indonesia;
    final rawPhone = order.branchPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (rawPhone.isEmpty) {
      Helpers.showSnackbar(
        context,
        isIndo
            ? 'Nomor WhatsApp outlet saat ini belum tersedia.'
            : 'Outlet WhatsApp number is currently unavailable.',
        backgroundColor: Colors.orange[800],
      );
      return;
    }

    final waNumber = rawPhone.startsWith('0')
        ? '62${rawPhone.substring(1)}'
        : (rawPhone.startsWith('62') ? rawPhone : '62$rawPhone');
    final orderCode =
        order.orderNumber.isNotEmpty ? order.orderNumber : '#${order.id}';
    final reasonText = (order.cancelReason ?? order.cancellationReason)?.trim();
    final hasCancelRequest = reasonText != null && reasonText.isNotEmpty;
    final message = isIndo
        ? (hasCancelRequest
            ? 'Halo *${order.branchName}*, saya ingin konfirmasi pesanan saya dengan nomor order *$orderCode*. Terkait kendala outlet "$reasonText", saya ingin konfirmasi menu pengganti atau bantuan pembatalan. Terima kasih!'
            : 'Halo *${order.branchName}*, saya ingin menanyakan pesanan saya dengan nomor order *$orderCode*. Mohon bantuannya ya, terima kasih!')
        : (hasCancelRequest
            ? 'Hello *${order.branchName}*, I would like to confirm my order *$orderCode*. Regarding the outlet issue "$reasonText", I would like to confirm item substitution or cancellation assistance. Thank you!'
            : 'Hello *${order.branchName}*, I would like to ask about my order *$orderCode*. Thank you for your assistance!');

    final uri = Uri.parse(
        'https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          Helpers.showSnackbar(
            context,
            isIndo
                ? 'Tidak dapat membuka aplikasi WhatsApp.'
                : 'Could not open WhatsApp app.',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showSnackbar(
          context,
          'Error WhatsApp: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Widget _buildReviewPromptCard(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang,
      {Map<String, dynamic>? submittedReview}) {
    final isIndo = lang == AppLanguage.indonesia;

    // Review feature window: automatically hidden after 7 days from order date
    final reviewDeadline = order.createdAt.add(const Duration(days: 7));
    final remainingReviewDuration = reviewDeadline.difference(DateTime.now());
    if (remainingReviewDuration.isNegative) {
      return const SizedBox.shrink();
    }

    if (submittedReview != null) {
      final rating = (submittedReview['rating'] as num?)?.toInt() ?? 5;
      final tags = (submittedReview['tags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final comment = submittedReview['comment']?.toString() ?? '';
      final rawDate = submittedReview['updatedAt'] ??
          submittedReview['created_at'] ??
          submittedReview['date'] ??
          order.createdAt;
      final dateStr = _formatSimpleDate(rawDate);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isIndo ? 'Ulasan Anda' : 'Your Review',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (comment.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '"${comment.trim()}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final int remainingDays = remainingReviewDuration.inDays;
    final int remainingHours = remainingReviewDuration.inHours % 24;
    final int remainingMinutes = remainingReviewDuration.inMinutes % 60;

    final String remainingSubtitle;
    if (remainingDays >= 1) {
      if (remainingHours > 0) {
        remainingSubtitle = isIndo
            ? 'Tersisa $remainingDays hari $remainingHours jam untuk memberi ulasan.'
            : 'You have $remainingDays days $remainingHours hours left to review.';
      } else {
        remainingSubtitle = isIndo
            ? 'Tersisa $remainingDays hari dari pesanan Anda untuk memberi ulasan.'
            : 'You have $remainingDays days left to review.';
      }
    } else if (remainingReviewDuration.inHours >= 1) {
      remainingSubtitle = isIndo
          ? 'Tersisa ${remainingReviewDuration.inHours} jam untuk memberi ulasan.'
          : 'You have ${remainingReviewDuration.inHours} hours left to review.';
    } else {
      final mins = remainingMinutes.clamp(1, 60);
      remainingSubtitle = isIndo
          ? 'Tersisa $mins menit untuk memberi ulasan.'
          : 'You have $mins minutes left to review.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndo
                          ? 'Bagaimana Pengalaman Anda?'
                          : 'How Was Your Experience?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      remainingSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showReviewModal(context, ref, order, lang),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                isIndo ? 'Beri Ulasan & Rating' : 'Rate & Review',
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewModal(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang,
      {Map<String, dynamic>? existingReview}) {
    final isIndo = lang == AppLanguage.indonesia;
    int rating = existingReview != null
        ? ((existingReview['rating'] as num?)?.toInt() ?? 5)
        : 5;
    final commentController = TextEditingController(
        text: existingReview?['comment']?.toString() ?? '');
    final List<String> quickTags = isIndo
        ? [
            'Rasa Lezat',
            'Porsi Pas',
            'Kemasan Rapi',
            'Pengiriman Cepat',
            'Pelayanan Ramah'
          ]
        : [
            'Delicious',
            'Good Portion',
            'Neat Packaging',
            'Fast Delivery',
            'Friendly Service'
          ];
    final Set<String> selectedTags =
        existingReview != null && existingReview['tags'] is List
            ? (existingReview['tags'] as List).map((e) => e.toString()).toSet()
            : {};

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final ratingLabels = isIndo
              ? [
                  '1 - Sangat Kecewa',
                  '2 - Kurang Puas',
                  '3 - Cukup Enak',
                  '4 - Enak & Puas',
                  '5 - Luar Biasa Lezat! ⭐'
                ]
              : [
                  '1 - Very Disappointed',
                  '2 - Needs Improvement',
                  '3 - Decent',
                  '4 - Delicious & Satisfied',
                  '5 - Extraordinary! ⭐'
                ];

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                  Center(
                    child: Text(
                      isIndo
                          ? (existingReview != null
                              ? 'Ubah Ulasan Pesanan'
                              : 'Beri Ulasan Pesanan')
                          : (existingReview != null
                              ? 'Edit Order Review'
                              : 'Review Your Order'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      order.branchName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        return IconButton(
                          iconSize: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () {
                            setState(() {
                              rating = starIndex;
                            });
                          },
                          icon: Icon(
                            starIndex <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: starIndex <= rating
                                ? const Color(0xFFF59E0B)
                                : Colors.grey[300],
                          ),
                        );
                      }),
                    ),
                  ),
                  Center(
                    child: Text(
                      ratingLabels[rating - 1],
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isIndo ? 'Apa yang Anda sukai?' : 'What did you like?',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFEA580C)
                              : Colors.black87,
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFFEDD5),
                        backgroundColor: Colors.grey[100],
                        checkmarkColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFFFDBA74)
                                : Colors.transparent,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isIndo
                        ? 'Tulis Ulasan & Komentar (Opsional):'
                        : 'Write Your Review (Optional):',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isIndo
                          ? 'Ceritakan rasa makanan, kemasan, atau saran untuk resto... (Opsional)'
                          : 'Tell us about the food taste, packaging, or suggestions... (Optional)',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDD2222)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setState(() => isSubmitting = true);

                              final orderKey = order.orderNumber.isNotEmpty
                                  ? order.orderNumber
                                  : order.id.toString();
                              final commentText =
                                  commentController.text.trim();
                              final reviewData = {
                                'orderId': order.id,
                                'orderNumber': order.orderNumber,
                                'rating': rating,
                                'tags': selectedTags.toList(),
                                'comment': commentText,
                                'status': 'pending',
                                'updatedAt': DateTime.now().toIso8601String(),
                              };

                              // 1. Post to backend API
                              try {
                                final apiClient = ref.read(apiClientProvider);
                                final menuIds = order.items
                                    .map((i) => i.targetMenuId > 0
                                        ? i.targetMenuId
                                        : i.menuId)
                                    .where((id) => id > 0)
                                    .toSet()
                                    .toList();
                                final payload = {
                                  if (order.id > 0) 'order_id': order.id,
                                  if (order.orderNumber.isNotEmpty)
                                    'order_number': order.orderNumber,
                                  if (menuIds.isNotEmpty)
                                    'menu_id': menuIds.first,
                                  if (menuIds.isNotEmpty)
                                    'menu_ids': menuIds,
                                  'rating': rating,
                                  'comment': commentText.isNotEmpty
                                      ? commentText
                                      : null,
                                  'tags': selectedTags.toList(),
                                };

                                final res = await apiClient.post('/reviews',
                                    data: payload);
                                if (res['success'] == true ||
                                    res['data'] != null) {
                                  if (res['data'] != null) {
                                    final remoteStatus =
                                        res['data']['status']?.toString();
                                    if (remoteStatus != null &&
                                        remoteStatus.isNotEmpty) {
                                      reviewData['status'] = remoteStatus;
                                    }
                                  }
                                } else {
                                  throw Exception(res['message']?.toString() ??
                                      'Gagal menyimpan ulasan');
                                }
                              } catch (e) {
                                debugPrint('Review submission API error: $e');
                                if (ctx.mounted) {
                                  setState(() => isSubmitting = false);
                                }
                                if (context.mounted) {
                                  Helpers.showSnackbar(
                                    context,
                                    isIndo
                                        ? 'Gagal mengirim ulasan ke server. Silakan coba lagi.'
                                        : 'Failed to submit review to server. Please try again.',
                                    backgroundColor: const Color(0xFFDC2626),
                                  );
                                }
                                return;
                              }

                              // 2. Cache in local SharedPreferences for instant responsiveness
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString('order_review_$orderKey',
                                    jsonEncode(reviewData));
                                if (order.id > 0) {
                                  await prefs.setString(
                                      'order_review_${order.id}',
                                      jsonEncode(reviewData));
                                }
                                if (order.orderNumber.isNotEmpty) {
                                  await prefs.setString(
                                      'order_review_${order.orderNumber}',
                                      jsonEncode(reviewData));
                                }
                              } catch (_) {}

                              ref.invalidate(orderReviewProvider(orderKey));

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (!context.mounted) return;
                              Helpers.showSnackbar(
                                context,
                                isIndo
                                    ? 'Ulasan Anda berhasil disimpan. Terima kasih atas masukan Anda!'
                                    : 'Your review has been saved. Thank you for your feedback!',
                                backgroundColor: const Color(0xFF16A34A),
                              );

                              // Pop-up rating Play Store setelah ulasan berhasil (rating >= 4)
                              if (rating >= 4) {
                                Future.delayed(
                                    const Duration(milliseconds: 800), () async {
                                  if (!context.mounted) return;
                                  final shouldPrompt =
                                      await AppRatingDialog.shouldShowPrompt();
                                  if (shouldPrompt && context.mounted) {
                                    AppRatingDialog.show(context);
                                  }
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD2222),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isIndo ? 'Kirim Ulasan' : 'Submit Review',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.normal),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveReceiptToGallery({
    required GlobalKey receiptKey,
    required String orderCode,
    required bool isIndo,
  }) async {
    try {
      final boundary = receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Receipt preview is not ready');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Unable to create receipt image');
      }

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      final isGranted = hasAccess || await Gal.requestAccess(toAlbum: true);
      if (!isGranted) {
        throw StateError('Gallery permission denied');
      }

      final safeOrderCode = orderCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        album: 'Delitopia',
        name: 'E_Struk_$safeOrderCode',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isIndo
              ? 'E-struk berhasil disimpan ke galeri.'
              : 'E-receipt saved to your gallery.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isIndo
              ? 'Gagal menyimpan e-struk. Periksa izin galeri Anda.'
              : 'Could not save e-receipt. Please check gallery permission.'),
          backgroundColor: const Color(0xFFDD2222),
        ),
      );
      debugPrint('Error saving receipt image: $error');
    }
  }

  void _showReceiptModal(BuildContext context, Order order, AppLanguage lang,
      {String? currentUserName, String? currentUserPhone}) {
    final isIndo = lang == AppLanguage.indonesia;
    final orderCode =
        order.orderNumber.isNotEmpty ? order.orderNumber : '#${order.id}';
    final localCreated = order.createdAt.toLocal();
    final dateStr =
        '${localCreated.day.toString().padLeft(2, '0')}/${localCreated.month.toString().padLeft(2, '0')}/${localCreated.year} ${localCreated.hour.toString().padLeft(2, '0')}:${localCreated.minute.toString().padLeft(2, '0')} WIB';
    final hasValidTable = order.isDineIn &&
        order.tableNumber != null &&
        order.tableNumber!.trim().isNotEmpty &&
        order.tableNumber!.trim() != '0';
    final methodStr = order.paymentMethod.isNotEmpty
        ? order.paymentMethod.toUpperCase()
        : 'QRIS';

    final customerName =
        (order.customerName != null && order.customerName!.trim().isNotEmpty)
            ? order.customerName!.trim()
            : (currentUserName != null && currentUserName.trim().isNotEmpty
                ? currentUserName.trim()
                : null);

    final receiptKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFFDD2222), size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isIndo ? 'E-Struk Resmi Transaksi' : 'Official E-Receipt',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              RepaintBoundary(
                key: receiptKey,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          order.branchName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (order.branchAddress != null &&
                          order.branchAddress!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Center(
                          child: Text(
                            order.branchAddress!.trim(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Divider(
                          height: 18, color: Color(0xFFCBD5E1), thickness: 1),
                      _receiptInfoRow(isIndo ? 'ID Pesanan' : 'Order ID', orderCode),
                      _receiptInfoRow(isIndo ? 'Waktu' : 'Date', dateStr),
                      _receiptInfoRow(
                          isIndo ? 'Tipe' : 'Type',
                          order.orderTypeDisplayFor(lang)),
                      if (hasValidTable)
                        _receiptInfoRow(
                            isIndo ? 'Meja' : 'Table', order.tableNumber!),
                      if (customerName != null && customerName.isNotEmpty)
                        _receiptInfoRow(
                            isIndo ? 'Pelanggan' : 'Customer', customerName),
                      if (order.isDelivery &&
                          order.deliveryAddress != null &&
                          order.deliveryAddress!.trim().isNotEmpty)
                        _receiptInfoRow(
                            isIndo ? 'Alamat Kirim' : 'Delivery Address',
                            order.deliveryAddress!.trim()),
                      _receiptInfoRow(isIndo ? 'Metode' : 'Payment', methodStr),
                      const Divider(
                          height: 18, color: Color(0xFFCBD5E1), thickness: 1),
                      Text(
                        isIndo ? 'Rincian Menu:' : 'Items Breakdown:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 7),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.productName}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Rp ${item.formattedPrice}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (item.hasPromo &&
                                        item.originalPrice != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rp ${item.formattedOriginalPrice ?? Helpers.formatNumber(item.originalPrice!)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade400,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Colors.grey.shade400,
                                        ),
                                      ),
                                      if (item.discountPercentage != null &&
                                          item.discountPercentage! > 0) ...[
                                        const SizedBox(width: 3),
                                        Text(
                                          '[-${item.discountPercentage}%]',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          )),
                      const Divider(
                          height: 18, color: Color(0xFFCBD5E1), thickness: 1),
                      _receiptTotalRow('Subtotal',
                          'Rp ${Helpers.formatNumber(order.subtotal)}'),
                      _receiptTotalRow(isIndo ? 'Pajak' : 'Tax',
                          'Rp ${Helpers.formatNumber(order.tax)}'),
                      _receiptTotalRow(isIndo ? 'Biaya Layanan' : 'Service Fee',
                          'Rp ${Helpers.formatNumber(order.service)}'),
                      if (order.deliveryFee > 0)
                        _receiptTotalRow(
                            isIndo ? 'Ongkos Kirim' : 'Delivery Fee',
                            'Rp ${Helpers.formatNumber(order.deliveryFee)}'),
                      if (order.discount > 0)
                        _receiptTotalRow(isIndo ? 'Diskon Promo' : 'Discount',
                            '-Rp ${Helpers.formatNumber(order.discount)}',
                            isDiscount: true),
                      const Divider(
                          height: 18, color: Color(0xFFCBD5E1), thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isIndo ? 'TOTAL BAYAR' : 'TOTAL PAYMENT',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Rp ${Helpers.formatNumber(order.totalAmount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: Color(0xFFDD2222),
                            ),
                          ),
                        ],
                      ),
                      if (order.totalPromoSavings > 0) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            isIndo
                                ? '* Total Hemat Promo: Rp ${Helpers.formatNumber(order.totalPromoSavings)} *'
                                : '* Total Promo Savings: Rp ${Helpers.formatNumber(order.totalPromoSavings)} *',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // STAMPEL LUNAS (INK STAMP EFFECT)
                      Center(
                        child: Transform.rotate(
                          angle: -0.10, // ~ -6 degrees
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 3),
                            decoration: BoxDecoration(
                              color: (order.isPaymentPaid
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706))
                                  .withValues(alpha: 0.08),
                              border: Border.all(
                                color: order.isPaymentPaid
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                                width: 2.2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: (order.isPaymentPaid
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706))
                                      .withValues(alpha: 0.6),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                order.isPaymentPaid
                                    ? (isIndo
                                        ? '★  L U N A S  ★'
                                        : '★  P A I D  ★')
                                    : (isIndo ? 'BELUM LUNAS' : 'UNPAID'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                  color: order.isPaymentPaid
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          isIndo
                              ? 'Terima kasih atas pesanan Anda!'
                              : 'Thank you for your order!',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side:
                        const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isIndo ? 'Tutup' : 'Close',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _saveReceiptToGallery(
                    receiptKey: receiptKey,
                    orderCode: orderCode,
                    isIndo: isIndo,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    isIndo ? 'Unduh E-Struk' : 'Download E-Receipt',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptTotalRow(String label, String value,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color:
                  isDiscount ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
