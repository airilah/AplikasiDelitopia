import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../shared/services/pos_service.dart' as pos;
import '../../../shared/services/service_providers.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../menu/controllers/favorite_controller.dart';
import '../../order/controllers/order_controller.dart';
import '../../voucher/controllers/voucher_controller.dart' as vouchers;

void refreshAuthScopedProviders(WidgetRef ref) {
  ref.invalidate(currentUserProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(cartProvider);
  ref.invalidate(favoritesProvider);
  ref.invalidate(isFavoriteProvider);
  ref.invalidate(userPointsBalanceProvider);
  ref.invalidate(pos.myVouchersProvider);
  ref.invalidate(vouchers.myVouchersProvider);
  ref.invalidate(vouchers.userPointsProvider);
  ref.invalidate(vouchers.pointsHistoryProvider);

  // Login has already stored the user ID and JWT, so repair/register FCM now.
  ref.read(pushNotificationServiceProvider).uploadToken();
}
