import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/animations/animated_widgets.dart';
import '../../../core/localization/app_language.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/services/pos_service.dart' as pos;
import '../../cart/controllers/cart_controller.dart';
import '../../menu/controllers/favorite_controller.dart';
import '../../voucher/controllers/voucher_controller.dart' as vouchers;
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';
import 'change_password_view.dart';

/// Tracks which account action reminder cards the user has chosen to dismiss ("Nanti") during the session
final dismissedProfileCardsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: userAsync.when(
          data: (user) => user != null
              ? _buildProfileContent(context, ref, user)
              : _buildGuestView(context, lang),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFDD2222)),
          ),
          error: (error, stack) => _buildErrorView(context, ref, lang),
        ),
      ));
  }

  Widget _buildGuestView(BuildContext context, AppLanguage lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            lang == AppLanguage.indonesia ? 'Silakan Login' : 'Please Login',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lang == AppLanguage.indonesia
                ? 'Masuk untuk mengakses profil Anda'
                : 'Login to access your profile',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                context.go(AuthGuard.loginLocation(AppRouter.profile)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(lang == AppLanguage.indonesia ? 'Masuk' : 'Login', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ));
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, AppLanguage lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            lang == AppLanguage.indonesia ? 'Gagal memuat profil' : 'Failed to load profile',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(currentUserProvider);
            },
            child: Text(tr.get('retry', lang)),
          ),
        ],
      ));
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, user) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 112;
    final lang = ref.watch(appLanguageProvider);
    final hasPhone =
        user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty;
    final dismissedCards = ref.watch(dismissedProfileCardsProvider);
    final isNameEmpty = user.name.trim().isEmpty || user.name.trim().toLowerCase() == 'tanpa nama';
    final showCompleteProfileCard = (!user.profileCompleted || isNameEmpty) && !dismissedCards.contains('complete_profile');
    final showPhoneCard = !hasPhone && !dismissedCards.contains('phone');
    final showEmailCard = !user.emailVerified && !dismissedCards.contains('email');
    final showPasswordCard = !user.hasPassword && !dismissedCards.contains('password');
    final hasAnyActionCard = showCompleteProfileCard || showPhoneCard || showEmailCard || showPasswordCard;

    return RefreshIndicator(
      color: const Color(0xFFDD2222),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(userPointsBalanceProvider);
        try {
          await ref.read(currentUserProvider.future);
        } catch (_) {}
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: Column(
          children: [
            _buildProfileHeader(
              context,
              user: user,
              lang: lang,
              headerHeight: headerHeight,
              hasPhone: hasPhone,
            ),

            if (showCompleteProfileCard)
              _buildAccountActionCard(
                context,
                lang: lang,
                icon: Icons.person_add_alt_1_outlined,
                title: lang == AppLanguage.indonesia
                    ? 'Lengkapi Data Profil'
                    : 'Complete Your Profile',
                subtitle: lang == AppLanguage.indonesia
                    ? 'Lengkapi nama dan tanggal lahir untuk kemudahan pesanan & bonus promo'
                    : 'Complete your name & birthday for smoother orders & exclusive rewards',
                actionLabel: lang == AppLanguage.indonesia
                    ? 'Lengkapi Sekarang'
                    : 'Complete Now',
                onTap: () => context.go(
                  '?phone=',
                ),
                onDismiss: () {
                  ref.read(dismissedProfileCardsProvider.notifier).update(
                    (set) => {...set, 'complete_profile'},
                  );
                },
              ),

            if (showPhoneCard)
              _buildAccountActionCard(
                context,
                lang: lang,
                icon: Icons.phone_iphone_rounded,
                title: tr.get('phone_not_verified', lang),
                subtitle: tr.get('phone_not_verified_sub', lang),
                actionLabel: tr.get('add_phone_number', lang),
                onTap: () => context.go(AppRouter.addPhoneNumber),
                onDismiss: () {
                  ref.read(dismissedProfileCardsProvider.notifier).update(
                    (set) => {...set, 'phone'},
                  );
                },
              ),

            if (showEmailCard)
              _buildAccountActionCard(
                context,
                lang: lang,
                icon: Icons.mark_email_unread_outlined,
                title: tr.get('email_not_verified', lang),
                subtitle: tr.get('email_not_verified_sub', lang),
                actionLabel: tr.get('verify_email', lang),
                onTap: () => context.go(AppRouter.emailVerification),
                onDismiss: () {
                  ref.read(dismissedProfileCardsProvider.notifier).update(
                    (set) => {...set, 'email'},
                  );
                },
              ),

            if (showPasswordCard)
              _buildAccountActionCard(
                context,
                lang: lang,
                icon: Icons.lock_outline,
                title: tr.get('no_password', lang),
                subtitle: tr.get('no_password_sub', lang),
                actionLabel: tr.get('create_password_btn', lang),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordView(),
                  ),
                ),
                onDismiss: () {
                  ref.read(dismissedProfileCardsProvider.notifier).update(
                    (set) => {...set, 'password'},
                  );
                },
              ),

            if (!hasAnyActionCard)
              const SizedBox(height: 12),

            // Compact Side-by-Side Quick Action Bar (Points & Member QR)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Slim Points Card
                  Expanded(
                    child: AnimatedCard(
                      onTap: () => context.go('${AppRouter.vouchers}?tab=2'),
                      child: Container(
                        height: 70,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.stars_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tr.get('my_points', lang),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${user.point}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Slim Member QR Card
                  Expanded(
                    child: AnimatedCard(
                      onTap: () => context.go(AppRouter.memberQr),
                      child: Container(
                        height: 70,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFDD2222), Color(0xFFB01C1C)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDD2222)
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 70, 69, 69).withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.qr_code_2_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tr.get('member_qr', lang),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tr.get('show_qr', lang),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Group 1: Akun & Transaksi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: tr.get('edit_profile', lang),
                      subtitle: tr.get('edit_profile_sub', lang),
                      onTap: () => context.go(AppRouter.editProfile),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      title: tr.get('order_history', lang),
                      subtitle: tr.get('order_history_sub', lang),
                      onTap: () => context.go(AppRouter.orderHistory),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_outlined,
                      title: tr.get('addresses', lang),
                      subtitle: tr.get('addresses_sub', lang),
                      onTap: () => context.go(AppRouter.addressList),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_giftcard_outlined,
                      title: tr.get('vouchers_rewards', lang),
                      subtitle: tr.get('vouchers_rewards_sub', lang),
                      onTap: () => context.go(AppRouter.vouchers),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.favorite_outline_rounded,
                      title: tr.get('favorites', lang),
                      subtitle: tr.get('favorites_sub', lang),
                      onTap: () => context.go(AppRouter.favorites),
                      trailing: ref.watch(favoritesProvider).when(
                        data: (favs) => favs.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDD2222),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${favs.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        loading: () => null,
                        error: (_, __) => null,
                      ),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: tr.get('notifications', lang),
                      subtitle: tr.get('notifications_sub', lang),
                      onTap: () => context.go(AppRouter.notifications),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Group 2: Bantuan & Informasi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: tr.get('help_center', lang),
                      subtitle: tr.get('help_center_sub', lang),
                      onTap: () => context.go(AppRouter.helpCenter),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: tr.get('about_us', lang),
                      subtitle: tr.get('about_us_sub', lang),
                      onTap: () => context.go(AppRouter.aboutUs),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: tr.get('privacy_policy', lang),
                      subtitle: tr.get('privacy_policy_sub', lang),
                      onTap: () => context.go(AppRouter.privacyPolicy),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Group 3: Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD6D6)),
                ),
                child: _buildMenuItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: tr.get('logout', lang),
                  subtitle: tr.get('logout_sub', lang),
                  onTap: () => _showLogoutDialog(context, ref),
                  textColor: const Color(0xFFDD2222),
                  iconColor: const Color(0xFFDD2222),
                  iconBgColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Delitopia v${AppConstants.appVersion}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ));
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required dynamic user,
    required AppLanguage lang,
    required double headerHeight,
    required bool hasPhone,
  }) {
    const avatarSize = 92.0;
    final avatarTop = headerHeight - 46;

    return SizedBox(
      height: headerHeight + 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: headerHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDD2222), Color(0xFFB91C1C)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -66,
                  right: -34,
                  child: Container(
                    width: 188,
                    height: 188,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -72,
                  left: -54,
                  child: Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr.get('profile_title', lang),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () => context.go(AppRouter.settings),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 26,
            top: avatarTop,
            child: _buildProfileAvatar(context, user, lang, avatarSize),
          ),
          Positioned(
            left: 128,
            right: 22,
            top: headerHeight - 30,
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.05,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            left: 128,
            right: 22,
            top: headerHeight + 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: hasPhone
                      ? null
                      : () => context.go(AppRouter.addPhoneNumber),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasPhone
                                ? _maskPhoneNumber(user.phoneNumber!)
                                : tr.get('add_phone_number', lang),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: hasPhone
                                  ? const Color(0xFF222222)
                                  : const Color(0xFFDD2222),
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w700,
                          height: 1.15,
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
        ],
      ));
  }

  Widget _buildProfileAvatar(
    BuildContext context,
    dynamic user,
    AppLanguage lang,
    double size,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: user.photo != null && user.photo!.isNotEmpty
              ? CachedCircularImage(
                  imageUrl: user.photo!,
                  size: size - 5,
                )
              : CircleAvatar(
                  radius: (size - 5) / 2,
                  backgroundColor: const Color(0xFFF2F2F2),
                  child: Icon(
                    Icons.person,
                    size: 46,
                    color: Colors.grey.shade400,
                  ),
                ),
        ),
      ]);
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final lang = ref.watch(appLanguageProvider);
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: tr.get('logout_confirm_title', lang),
      message: tr.get('logout_confirm_msg', lang),
      confirmText: tr.get('logout', lang),
      cancelText: tr.get('cancel', lang),
      type: AppDialogType.danger,
    );

    if (!confirmed || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final storageService = ref.read(storageServiceProvider);

    try {
      await authService.logout();
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
        context.go(AppRouter.navigation);
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showSnackbar(
            context, '${tr.get('logout_failed', lang)}: $e');
      }
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    Color? iconBgColor,
    Widget? trailing,
  }) {
    final effectiveIconColor = iconColor ?? const Color(0xFFDD2222);
    final effectiveBgColor = iconBgColor ?? const Color(0xFFFFF1F1);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor ?? const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF374151),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          if (trailing != null) const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
      onTap: onTap);
  }

  Widget _buildAccountActionCard(
    BuildContext context, {
    required AppLanguage lang,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0E0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDD2222).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFDD2222), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF202124),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  tr.get('later', lang),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD2222),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ));
  }

  String _maskPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;

    final localNumber =
        digits.startsWith('62') ? '0${digits.substring(2)}' : digits;
    if (localNumber.length <= 7) return localNumber;

    return '${localNumber.substring(0, 4)}********${localNumber.substring(localNumber.length - 3)}';
  }
}
