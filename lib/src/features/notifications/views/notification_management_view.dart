import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../controllers/notification_preferences_controller.dart';

class NotificationManagementView extends ConsumerWidget {
  const NotificationManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/settings',
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/notifications',
            color: Colors.white,
          ),
          title: Text(tr.get('notification_settings_title', lang)), backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Push Notifications
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                    title: Text(
                      lang == AppLanguage.indonesia ? 'Notifikasi Push' : 'Push Notifications',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text(tr.get('receive_notif_device', lang)),
                    trailing: Switch(
                      value: settings.enabled,
                      activeThumbColor: const Color(0xFFDD2222),
                      onChanged: controller.setEnabled,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Email Notifications
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.email,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                    title: Text(
                      lang == AppLanguage.indonesia ? 'Notifikasi Email' : 'Email Notifications',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(tr.get('receive_notif_email', lang)),
                    trailing: Switch(
                      value: settings.emailEnabled,
                      activeThumbColor: const Color(0xFFDD2222),
                      onChanged:
                          settings.enabled ? controller.setEmailEnabled : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                lang == AppLanguage.indonesia ? 'Tipe Notifikasi' : 'Notification Types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),

            // Notification Types
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildNotificationToggle(
                    context: context,
                    ref: ref,
                    icon: Icons.shopping_bag,
                    title: lang == AppLanguage.indonesia ? 'Pembaruan Pesanan' : 'Order Updates',
                    subtitle: lang == AppLanguage.indonesia ? 'Dapatkan notifikasi status pesanan Anda' : 'Get notified about your order status',
                    value: settings.orderUpdates,
                    enabled: settings.enabled,
                    onChanged: controller.setOrderUpdates,
                  ),
                  const Divider(height: 1),
                  _buildNotificationToggle(
                    context: context,
                    ref: ref,
                    icon: Icons.local_shipping,
                    title: lang == AppLanguage.indonesia ? 'Pembaruan Pengiriman' : 'Delivery Updates',
                    subtitle: lang == AppLanguage.indonesia ? 'Lacak pengiriman Anda secara real-time' : 'Track your delivery in real-time',
                    value: settings.deliveryUpdates,
                    enabled: settings.enabled,
                    onChanged: controller.setDeliveryUpdates,
                  ),
                  const Divider(height: 1),
                  _buildNotificationToggle(
                    context: context,
                    ref: ref,
                    icon: Icons.card_giftcard,
                    title: lang == AppLanguage.indonesia ? 'Hadiah & Voucher' : 'Rewards & Vouchers',
                    subtitle: lang == AppLanguage.indonesia ? 'Info poin dan voucher baru' : 'Updates on points and new vouchers',
                    value: settings.rewards,
                    enabled: settings.enabled,
                    onChanged: controller.setRewards,
                  ),
                  const Divider(height: 1),
                  _buildNotificationToggle(
                    context: context,
                    ref: ref,
                    icon: Icons.restaurant_menu,
                    title: lang == AppLanguage.indonesia ? 'Menu Baru' : 'New Menu Items',
                    subtitle: lang == AppLanguage.indonesia ? 'Jadilah yang pertama tahu menu baru kami' : 'Be the first to know about new dishes',
                    value: settings.newMenuItems,
                    enabled: settings.enabled,
                    onChanged: controller.setNewMenuItems,
                  ),
                  const Divider(height: 1),
                  _buildNotificationToggle(
                    context: context,
                    ref: ref,
                    icon: Icons.local_offer,
                    title: tr.get('promotions', lang),
                    subtitle: lang == AppLanguage.indonesia ? 'Diskon dan penawaran khusus' : 'Special deals and discounts',
                    value: settings.promotions,
                    enabled: settings.enabled,
                    onChanged: controller.setPromotions,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == AppLanguage.indonesia ? 'Tentang Notifikasi' : 'About Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang == AppLanguage.indonesia
                              ? 'Anda dapat mengatur izin notifikasi di pengaturan perangkat Anda. Beberapa notifikasi penting (seperti konfirmasi pesanan) tidak dapat dinonaktifkan.'
                              : 'You can manage notification permissions in your device settings. Some critical notifications (like order confirmations) cannot be disabled.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ));
  }

  Widget _buildNotificationToggle({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: enabled ? const Color(0xFFDD2222) : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? null : Colors.grey,
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFFDD2222),
      onChanged: enabled ? onChanged : null);
  }
}
