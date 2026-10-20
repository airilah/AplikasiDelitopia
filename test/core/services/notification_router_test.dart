import 'package:flutter_test/flutter_test.dart';
import 'package:delitopia_v2/src/core/services/notification_router.dart';

void main() {
  group('NotificationRouter.resolve', () {
    test('courier events open tracking before a generic action URL', () {
      expect(
        NotificationRouter.resolve(
          actionUrl: '/orders/ORD-10',
          templateKey: 'order_courier_allocated',
          orderId: 'ORD-10',
        ),
        '/track-order/ORD-10',
      );
    });

    test('legacy and category routes are normalized', () {
      expect(
        NotificationRouter.resolve(actionUrl: '/promos'),
        '/navigation?index=0',
      );
      expect(
        NotificationRouter.resolve(category: 'points'),
        '/vouchers?tab=points',
      );
      expect(
        NotificationRouter.resolve(category: 'voucher'),
        '/vouchers?tab=my',
      );
    });

    test('external or unknown actions fall back to the inbox', () {
      expect(
        NotificationRouter.resolve(actionUrl: 'https://example.com'),
        '/notifications',
      );
    });
  });
}
