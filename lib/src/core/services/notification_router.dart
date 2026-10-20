import '../routes/app_router.dart';

/// Single routing policy for FCM, local notifications, snackbars, and inbox items.
class NotificationRouter {
  NotificationRouter._();

  static void open({
    String? actionUrl,
    String? category,
    String? templateKey,
    String? type,
    String? orderId,
    String? statusOrder,
  }) {
    AppRouter.router.push(resolve(
      actionUrl: actionUrl,
      category: category,
      templateKey: templateKey,
      type: type,
      orderId: orderId,
      statusOrder: statusOrder,
    ));
  }

  static String resolve({
    String? actionUrl,
    String? category,
    String? templateKey,
    String? type,
    String? orderId,
    String? statusOrder,
  }) {
    final template = (templateKey ?? '').toLowerCase();
    final normalizedCategory = (category ?? type ?? '').toLowerCase();
    final validOrderId = orderId?.trim();

    if (validOrderId != null &&
        validOrderId.isNotEmpty &&
        (template.contains('courier') ||
            ['allocated', 'driver_allocated', 'picking_up', 'in_delivery']
                .contains((statusOrder ?? '').toLowerCase()))) {
      return '/track-order/$validOrderId';
    }

    final normalizedAction = _normalizeAction(actionUrl);
    if (normalizedAction != null) return normalizedAction;

    if (validOrderId != null && validOrderId.isNotEmpty) {
      return '/orders/$validOrderId';
    }

    if (template.contains('point') || normalizedCategory == 'points') {
      return '/vouchers?tab=points';
    }
    if (template == 'level_up') return '/profile';
    if (template == 'near_upgrade' || template == 'reengagement') {
      return '/navigation?index=1';
    }
    if (normalizedCategory == 'voucher') return '/vouchers?tab=my';
    if (normalizedCategory == 'promo' || normalizedCategory == 'marketing') {
      return '/navigation?index=0';
    }

    return '/notifications';
  }

  static String? _normalizeAction(String? rawAction) {
    var action = rawAction?.trim();
    if (action == null || action.isEmpty || !action.startsWith('/')) {
      return null;
    }

    // Migrate legacy template routes that do not exist in AppRouter.
    if (action == '/promos') action = '/navigation?index=0';
    if (action == '/profile/points') action = '/vouchers?tab=points';
    if (action == '/profile/level') action = '/profile';

    const allowedRoots = [
      '/navigation',
      '/orders',
      '/track-order',
      '/payment',
      '/vouchers',
      '/profile',
      '/notifications',
      '/menu',
      '/product',
      '/help',
    ];
    return allowedRoots.any((root) => action!.startsWith(root)) ? action : null;
  }
}
