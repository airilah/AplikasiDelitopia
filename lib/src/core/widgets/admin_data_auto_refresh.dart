import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/menu/views/menu_view.dart';
import '../../features/order/controllers/order_controller.dart' as order;
import '../../features/voucher/controllers/voucher_controller.dart' as voucher;
import '../../shared/services/pos_service.dart' as pos;
import '../../shared/services/service_providers.dart' as services;
import '../../shared/services/ui_schema_provider.dart';
import '../../shared/models/user_model.dart';
import '../services/push_notification_service.dart';
import '../services/active_order_tracker.dart';

/// Keeps app data in sync with changes made from Delitopia Admin.
class AdminDataAutoRefresh extends ConsumerStatefulWidget {
  final Widget child;
  final Duration refreshInterval;

  const AdminDataAutoRefresh({
    super.key,
    required this.child,
    this.refreshInterval = const Duration(minutes: 5),
  });

  @override
  ConsumerState<AdminDataAutoRefresh> createState() =>
      _AdminDataAutoRefreshState();
}

class _AdminDataAutoRefreshState extends ConsumerState<AdminDataAutoRefresh>
    with WidgetsBindingObserver {
  static const _minimumRefreshGap = Duration(seconds: 30);

  Timer? _timer;
  DateTime? _lastRefreshAt;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    
    // Initialize push notifications and active order tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).initialize();
      final user = ref.read(services.currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(activeOrderTrackerProvider).startTracking(user.id);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminDataAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      // Refresh rotated/missing tokens whenever the user returns to the app.
      ref.read(pushNotificationServiceProvider).uploadToken();
      _refreshAdminDrivenData(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      widget.refreshInterval,
      (_) => _refreshAdminDrivenData());
  }

  void _refreshAdminDrivenData({bool force = false}) {
    if (!mounted || _lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _minimumRefreshGap) {
      return;
    }

    _lastRefreshAt = now;

    ref
      ..invalidate(uiSchemaProvider)
      ..invalidate(services.currentUserProvider)
      ..invalidate(services.bannersProvider)
      ..invalidate(services.categoriesProvider)
      ..invalidate(services.popularProductsProvider)
      ..invalidate(services.showcaseProductsProvider)
      ..invalidate(services.availableVouchersProvider)
      ..invalidate(services.userVouchersProvider)
      ..invalidate(services.brandsProvider)
      ..invalidate(services.branchesProvider)
      ..invalidate(services.branchesByBrandProvider)
      ..invalidate(services.menusProvider)
      ..invalidate(services.popularMenusProvider)
      ..invalidate(services.menusByCategoryProvider)
      ..invalidate(services.menusByBrandProvider)
      ..invalidate(services.notificationsProvider)
      ..invalidate(services.qrCodesProvider)
      ..invalidate(services.nearbyBranchesProvider)
      ..invalidate(services.userPointsBalanceProvider)
      ..invalidate(menusByBrandBranchProvider)
      ..invalidate(voucher.availableVouchersProvider)
      ..invalidate(voucher.myVouchersProvider)
      ..invalidate(voucher.myVouchersByStatusProvider)
      ..invalidate(voucher.myActiveVouchersProvider)
      ..invalidate(voucher.pointRedemptionVouchersProvider)
      ..invalidate(voucher.cashPurchaseVouchersProvider)
      ..invalidate(voucher.categorizedVouchersProvider)
      ..invalidate(voucher.userPointsProvider)
      ..invalidate(voucher.pointsHistoryProvider)
      ..invalidate(pos.memberProfileProvider)
      ..invalidate(pos.myVouchersProvider)
      ..invalidate(order.orderHistoryProvider)
      ..invalidate(order.activeOrdersProvider)
      ..invalidate(order.completedOrdersProvider)
      ..invalidate(order.orderDetailsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to user changes to manage tracking and FCM token
    ref.listen<AsyncValue<User?>>(services.currentUserProvider, (previous, next) {
      final user = next.valueOrNull;
      final prevUser = previous?.valueOrNull;
      if (user != null && prevUser?.id != user.id) {
        ref.read(pushNotificationServiceProvider).uploadToken();
        ref.read(activeOrderTrackerProvider).startTracking(user.id);
      } else if (user == null && prevUser != null) {
        ref.read(activeOrderTrackerProvider).stopTracking();
      }
    });

    return widget.child;
  }
}
