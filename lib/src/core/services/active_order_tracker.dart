import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/order/controllers/order_controller.dart';
import '../../features/order/models/order_model.dart';
import '../../shared/services/service_providers.dart';

final activeOrderTrackerProvider = Provider<ActiveOrderTracker>((ref) {
  return ActiveOrderTracker(ref);
});

class ActiveOrderTracker {
  final Ref _ref;
  final Map<int, String> _lastKnownStatuses = {};
  int? _trackingUserId;
  bool _hasSeededInitialOrders = false;
  ProviderSubscription<AsyncValue<List<Order>>>? _ordersSub;

  ActiveOrderTracker(this._ref);

  void startTracking(int userId) {
    if (_trackingUserId == userId && _ordersSub != null) {
      return;
    }
    stopTracking();
    _trackingUserId = userId;
    _hasSeededInitialOrders = false;
    _lastKnownStatuses.clear();

    _ordersSub = _ref.listen<AsyncValue<List<Order>>>(
      activeOrdersProvider(userId),
      (previous, next) {
        final orders = next.valueOrNull;
        if (orders == null) return;

        // Seed current state silently so reopening the app never replays alerts.
        if (!_hasSeededInitialOrders) {
          for (final order in orders) {
            _lastKnownStatuses[order.id] = order.status;
          }
          _hasSeededInitialOrders = true;
          return;
        }

        for (final order in orders) {
          final previousStatus = _lastKnownStatuses[order.id];
          if (previousStatus != order.status) {
            _lastKnownStatuses[order.id] = order.status;
            // FCM owns foreground alerts and sound. Polling only refreshes inbox data.
            _ref.invalidate(notificationsProvider);
          }
        }

        final activeIds = orders.map((order) => order.id).toSet();
        _lastKnownStatuses.removeWhere((id, _) => !activeIds.contains(id));
      },
      fireImmediately: true,
    );
  }

  void stopTracking() {
    _ordersSub?.close();
    _ordersSub = null;
    _trackingUserId = null;
    _hasSeededInitialOrders = false;
    _lastKnownStatuses.clear();
  }
}
