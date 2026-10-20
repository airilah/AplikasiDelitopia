import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/feature_tour_wrapper.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/services/pos_service.dart' as pos;
import '../../notifications/controllers/notification_preferences_controller.dart';
import '../../auth/services/auth_service.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../menu/controllers/favorite_controller.dart';
import '../../voucher/controllers/voucher_controller.dart' as vouchers;
import 'change_password_view.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String _language = 'Indonesia';
  String _theme = 'Light';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Sync local _language state from the global language provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLang = ref.read(appLanguageProvider);
      if (mounted) {
        setState(() {
          _language = currentLang.label;
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? AppLanguage.indonesia.label;
      _theme = prefs.getString('theme') ?? 'Light';
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final lang = ref.watch(appLanguageProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final notificationController =
        ref.read(notificationPreferencesProvider.notifier);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(
            tr.get('settings_title', lang),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
          backgroundColor: const Color(0xFFDD2222),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notifications Section
              _buildSection(tr.get('section_notifications', lang)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_active_outlined,
                        title: tr.get('enable_notifications', lang),
                        subtitle: tr.get('enable_notifications_sub', lang),
                        value: notificationPrefs.enabled,
                        onChanged: notificationController.setEnabled,
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildSwitchTile(
                        icon: Icons.local_shipping_outlined,
                        title: tr.get('order_updates', lang),
                        subtitle: tr.get('order_updates_sub', lang),
                        value: notificationPrefs.orderUpdates,
                        enabled: notificationPrefs.enabled,
                        onChanged: notificationController.setOrderUpdates,
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildSwitchTile(
                        icon: Icons.local_offer_outlined,
                        title: tr.get('promotions', lang),
                        subtitle: tr.get('promotions_sub', lang),
                        value: notificationPrefs.promotions,
                        enabled: notificationPrefs.enabled,
                        onChanged: notificationController.setPromotions,
                      ),
                    ],
                  ),
                ),
              ),

              // Sounds & Vibration Section
              _buildSection(tr.get('section_sound', lang)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.volume_up_outlined,
                        title: tr.get('sound', lang),
                        subtitle: tr.get('sound_sub', lang),
                        value: notificationPrefs.sound,
                        enabled: notificationPrefs.enabled,
                        onChanged: notificationController.setSound,
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildSwitchTile(
                        icon: Icons.vibration_outlined,
                        title: tr.get('vibration', lang),
                        subtitle: tr.get('vibration_sub', lang),
                        value: notificationPrefs.vibration,
                        enabled: notificationPrefs.enabled,
                        onChanged: notificationController.setVibration,
                      ),
                    ],
                  ),
                ),
              ),

              // Preferences Section
              _buildSection(tr.get('section_preferences', lang)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildNavTile(
                        icon: Icons.language_outlined,
                        title: tr.get('language', lang),
                        subtitle: _language,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(tr.get('language', lang)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLanguageOption('English'),
                                  _buildLanguageOption('Indonesia'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildNavTile(
                        icon: Icons.palette_outlined,
                        title: tr.get('theme', lang),
                        subtitle: _theme,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(tr.get('theme', lang)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildThemeOption('Light'),
                                  _buildThemeOption('Dark'),
                                  _buildThemeOption('System'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Account Section
              _buildSection(tr.get('section_account', lang)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildNavTile(
                        icon: Icons.lock_reset_outlined,
                        title: user?.hasPassword == true
                            ? tr.get('change_password', lang)
                            : tr.get('create_password', lang),
                        subtitle: user?.hasPassword == true
                            ? tr.get('change_password_sub', lang)
                            : tr.get('create_password_sub', lang),
                        onTap: () {
                          if (user != null && !user.emailVerified) {
                            context.go(AppRouter.emailVerification);
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChangePasswordView(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      const ResetOnboardingTile(),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildNavTile(
                        icon: Icons.delete_forever_outlined,
                        title: tr.get('delete_account', lang),
                        subtitle: tr.get('delete_account_sub', lang),
                        titleColor: const Color(0xFFDD2222),
                        iconColor: const Color(0xFFDD2222),
                        iconBgColor: const Color(0xFFFFF0F0),
                        onTap: () => _showDeleteAccountDialog(context, user?.id, lang),
                      ),
                    ],
                  ),
                ),
              ),

              // Support & Legal Section
              _buildSection(tr.get('section_support', lang)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _buildNavTile(
                        icon: Icons.help_outline_rounded,
                        title: tr.get('help_center', lang),
                        subtitle: tr.get('help_center_sub', lang),
                        onTap: () => context.go(AppRouter.helpCenter),
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildNavTile(
                        icon: Icons.support_agent_outlined,
                        title: tr.get('contact_us', lang),
                        subtitle: tr.get('contact_us_sub', lang),
                        onTap: () => context.go(AppRouter.helpCenter),
                      ),
                      const Divider(height: 1, indent: 58, endIndent: 16),
                      _buildNavTile(
                        icon: Icons.privacy_tip_outlined,
                        title: tr.get('privacy_policy', lang),
                        subtitle: tr.get('privacy_policy_sub', lang),
                        onTap: () => context.go(AppRouter.privacyPolicy),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Delitopia v${AppConstants.appVersion}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
            color: Color(0xFFDD2222),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? const Color(0xFFDD2222) : Colors.grey;
    final effectiveBg =
        enabled ? const Color(0xFFFFF1F1) : Colors.grey.shade100;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: effectiveColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: enabled ? const Color(0xFF242424) : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFFDD2222),
      activeTrackColor: const Color(0xFFFFD6D6),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
    Color? iconBgColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBgColor ?? const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? const Color(0xFFDD2222), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: titleColor ?? const Color(0xFF242424),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLanguageOption(String language) {
    final isSelected = _language == language;

    return ListTile(
      title: Text(language),
      trailing: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? const Color(0xFFDD2222) : Colors.grey.shade400,
      ),
      onTap: () {
        setState(() {
          _language = language;
        });
        _savePreference('language', language);
        // Also update the app-wide language provider reactively
        ref.read(appLanguageProvider.notifier).setLanguage(language);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildThemeOption(String theme) {
    final isSelected = _theme == theme;

    return ListTile(
      title: Text(theme),
      trailing: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? const Color(0xFFDD2222) : Colors.grey.shade400,
      ),
      onTap: () {
        setState(() {
          _theme = theme;
        });
        _savePreference('theme', theme);
        Navigator.pop(context);
      },
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context, int? userId, AppLanguage lang) async {
    if (userId == null) {
      Helpers.showSnackbar(context, tr.get('login_required_desc', lang));
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: tr.get('delete_account_confirm_title', lang),
      message: tr.get('delete_account_confirm_msg', lang),
      confirmText: tr.get('delete_account_btn', lang),
      cancelText: tr.get('cancel', lang),
      type: AppDialogType.danger,
    );

    if (!confirmed || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final storageService = ref.read(storageServiceProvider);

    try {
      await authService.deleteAccount(userId);
      await storageService.deleteAuthToken();
      await storageService.deleteUserId();

      if (context.mounted) {
        ref.invalidate(currentUserProvider);
        ref.invalidate(cartProvider);
        ref.invalidate(favoritesProvider);
        ref.invalidate(isFavoriteProvider);
        ref.invalidate(userPointsBalanceProvider);
        ref.invalidate(pos.myVouchersProvider);
        ref.invalidate(vouchers.myVouchersProvider);
        ref.invalidate(vouchers.userPointsProvider);
        ref.invalidate(vouchers.pointsHistoryProvider);

        Helpers.showSnackbar(
          context,
          tr.get('delete_account_success', lang),
        );
        context.go(AppRouter.navigation);
      }
    } catch (e) {
      if (context.mounted) {
        final errorMsg =
            e.toString().replaceAll('Exception: ', '').trim();
        Helpers.showSnackbar(
          context,
          errorMsg.isNotEmpty
              ? errorMsg
              : tr.get('delete_account_failed', lang),
        );
      }
    }
  }
}
