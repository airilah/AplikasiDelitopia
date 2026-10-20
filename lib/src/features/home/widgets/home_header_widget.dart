import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/feature_spotlight.dart';
import '../../../core/widgets/feature_tour_wrapper.dart';
import '../../../core/animations/animated_widgets.dart';
import '../../../shared/services/service_providers.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/auth_guard.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Shared gradient header decoration (const for zero rebuild cost)
// ──────────────────────────────────────────────────────────────────────────────
const _kHeaderGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDD2222), Color(0xFFFF6B35)],
  ),
);

// ──────────────────────────────────────────────────────────────────────────────
// HomeHeaderWidget — gradient header with user greeting + search bar floating
// Extracted from DynamicHomePage to isolate rebuild scope.
// Rebuilds ONLY when currentUserProvider or appLanguageProvider changes.
// ──────────────────────────────────────────────────────────────────────────────
class HomeHeaderWidget extends ConsumerWidget {
  final bool isGuest;
  final ScrollController? scrollController;

  const HomeHeaderWidget({
    super.key,
    required this.isGuest,
  }) : scrollController = null;

  const HomeHeaderWidget.withScroll({
    super.key,
    required this.isGuest,
    required ScrollController this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 135,
          decoration: _kHeaderGradient,
          child: Stack(
            children: [
              // Decorative circles — const, no rebuild cost
              const Positioned(
                top: -50,
                right: -50,
                child: _DecorativeCircle(size: 200),
              ),
              const Positioned(
                bottom: -30,
                left: -30,
                child: _DecorativeCircle(size: 150),
              ),
              // Header content — this is the part that watches providers
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _UserGreeting(isGuest: isGuest),
                      ),
                      const SizedBox(width: 8),
                      const _FeatureTourButtonWrapper(),
                      const SizedBox(width: 6),
                      if (isGuest)
                        _LoginButton()
                      else
                        const _NotificationBadge(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Floating search bar — overlaps header bottom
        Positioned(
          left: 18,
          right: 18,
          bottom: -24,
          child: SpotlightTarget(
            targetKey: 'home_search',
            child: HomeSearchBar(),
          ),
        ),
      ],
    );
  }
}

/// Decorative circle — pure const widget, never rebuilds
class _DecorativeCircle extends StatelessWidget {
  final double size;
  const _DecorativeCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }
}

/// User greeting text — watches currentUserProvider and appLanguageProvider.
/// By isolating this, only the greeting text rebuilds when user data arrives,
/// not the entire header.
class _UserGreeting extends ConsumerWidget {
  final bool isGuest;
  const _UserGreeting({required this.isGuest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        final displayName = isGuest
            ? tr.get('guest', lang)
            : (user?.name.trim().isNotEmpty == true)
                ? user!.name
                : tr.get('customer', lang);
        return _GreetingColumn(
          welcomeText: isGuest
              ? tr.get('welcome_guest', lang)
              : tr.get('welcome_back', lang),
          nameText: displayName,
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isGuest ? tr.get('welcome_guest', lang) : tr.get('welcome_back', lang),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 100,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
      error: (_, __) {
        String fallbackName = isGuest ? tr.get('guest', lang) : tr.get('customer', lang);
        if (!isGuest) {
          final cachedName = ref.watch(storageServiceProvider).getCachedUserName();
          if (cachedName != null && cachedName.trim().isNotEmpty) {
            fallbackName = cachedName.trim();
          }
        }
        return _GreetingColumn(
          welcomeText: isGuest ? tr.get('welcome_guest', lang) : tr.get('welcome_back', lang),
          nameText: fallbackName,
        );
      },
    );
  }
}

class _GreetingColumn extends StatelessWidget {
  final String welcomeText;
  final String nameText;
  const _GreetingColumn({required this.welcomeText, required this.nameText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          welcomeText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
        Text(
          nameText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FeatureTourButtonWrapper extends StatelessWidget {
  const _FeatureTourButtonWrapper();

  @override
  Widget build(BuildContext context) {
    return const FeatureTourButton(featureKey: 'home');
  }
}

class _LoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onPressed: () => context.go(AppRouter.login),
      scaleValue: 0.9,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.login_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Notification badge — isolated Consumer to avoid rebuilding full header row.
class _NotificationBadge extends ConsumerWidget {
  const _NotificationBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);

    return AnimatedButton(
      onPressed: () {
        final notifs = ref.read(notificationsProvider).valueOrNull ?? [];
        final now = DateTime.now();
        DateTime markTime = now;
        if (notifs.isNotEmpty) {
          final latest = notifs.map((n) => n.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
          if (latest.isAfter(markTime)) markTime = latest;
        }
        ref.read(storageServiceProvider).saveLastSeenNotificationTime(markTime);
        ref.read(lastSeenNotificationTimeProvider.notifier).state = markTime;
        context.go(AppRouter.notifications);
      },
      scaleValue: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (hasUnread)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HomeSearchBar — stateless search bar widget for home page
// Used by both HomeHeaderWidget and GuestHeader
// ──────────────────────────────────────────────────────────────────────────────
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRouter.search),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16)),
                  onTap: () => context.push(AppRouter.search),
                  child: Container(
                    height: double.infinity,
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFDD2222),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.get('search_for_food', lang),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                lang == AppLanguage.indonesia
                                    ? 'Cari makanan atau outlet...'
                                    : 'Search food or outlet...',
                                style: const TextStyle(
                                  color: Color(0xFF222222),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
            ),
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(16)),
            onTap: () {
              if (AuthGuard.requireLogin(context, ref, redirectTo: AppRouter.qrScanner)) {
                context.go(AppRouter.qrScanner);
              }
            },
            child: const SizedBox(
              width: 54,
              height: 54,
              child: Center(
                child: _QrButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFDD2222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.qr_code_scanner_rounded,
        color: Colors.white,
        size: 21,
      ),
    );
  }
}
