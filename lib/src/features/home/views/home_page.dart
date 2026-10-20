import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/brand_name_formatter.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/feature_tour_wrapper.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/services/pos_service.dart' as pos;
import '../../../shared/services/location_service.dart';
import '../../../shared/models/product_model.dart' as models;
import '../../../shared/models/voucher_model.dart';
import '../../../shared/models/user_voucher_model.dart' as pos_models;
import '../../../shared/models/brand_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import '../../voucher/controllers/voucher_controller.dart' as voucher_ctrl;
import '../widgets/popup_banner_dialog.dart';
import '../../../shared/widgets/price_display_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static bool _hasShownPopupThisSession = false;

  @override
  void initState() {
    super.initState();
    // Show popup after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPopup();
    });
  }

  void _checkAndShowPopup() async {
    if (_hasShownPopupThisSession) return;

    final bannersAsync = ref.read(bannersProvider);
    bannersAsync.whenData((banners) {
      if (!mounted || _hasShownPopupThisSession || banners.isEmpty) return;

      // Find all banners with popup
      final popupBanners = banners.where((b) => b.hasPopup).toList();

      if (popupBanners.isNotEmpty) {
        _hasShownPopupThisSession = true;
        _showBannerPopupSlides(popupBanners);
      }
    });
  }

  void _showBannerPopupSlides(List<models.Banner> popupBanners) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PopupBannerDialog(banners: popupBanners));
  }

  @override
  Widget build(BuildContext context) {
    return FeatureTourWrapper(
      featureKey: 'home',
      enabled: true,
      child: Scaffold(
        body: RefreshIndicator(
          color: const Color(0xFFDD2222),
          onRefresh: () async {
            ref.invalidate(brandsProvider);
            ref.invalidate(bannersProvider);
            ref.invalidate(branchesProvider);
            ref.invalidate(nearbyBranchesProvider);
            ref.invalidate(currentUserProvider);
            ref.invalidate(availableVouchersProvider);
            ref.invalidate(pos.myVouchersProvider);
            try {
              await Future.wait([
                ref.read(brandsProvider.future),
                ref.read(bannersProvider.future),
              ]);
            } catch (_) {}
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern App Bar with Gradient
              Container(
                height: 132,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFDD2222),
                      Color(0xFFFF6B35),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final userAsync =
                                          ref.watch(currentUserProvider);
                                      final token = ref
                                          .watch(storageServiceProvider)
                                          .getAuthToken();
                                      final isGuest =
                                          token == null || token.isEmpty;
                                      final lang =
                                          ref.watch(appLanguageProvider);

                                      return userAsync.when(
                                        data: (user) {
                                          final displayName = isGuest
                                              ? tr.get('guest', lang)
                                              : (user?.name.trim().isNotEmpty ==
                                                      true)
                                                  ? user!.name
                                                  : tr.get('customer', lang);
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isGuest
                                                    ? tr.get(
                                                        'welcome_guest', lang)
                                                    : tr.get(
                                                        'welcome_back', lang),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ]);
                                        },
                                        error: (error, stack) {
                                           String fallbackName = isGuest
                                               ? tr.get('guest', lang)
                                               : tr.get('customer', lang);
                                           if (!isGuest) {
                                             final cachedName = ref
                                                 .watch(storageServiceProvider)
                                                 .getCachedUserName();
                                             if (cachedName != null &&
                                                 cachedName.trim().isNotEmpty) {
                                               fallbackName = cachedName.trim();
                                             }
                                           }
                                           return Column(
                                             crossAxisAlignment:
                                                 CrossAxisAlignment.start,
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               Text(
                                                 isGuest
                                                     ? tr.get(
                                                         'welcome_guest', lang)
                                                     : tr.get(
                                                         'welcome_back', lang),
                                                 style: TextStyle(
                                                   color: Colors.white
                                                       .withValues(alpha: 0.9),
                                                   fontSize: 11,
                                                 ),
                                               ),
                                               Text(
                                                 fallbackName,
                                                 style: const TextStyle(
                                                   color: Colors.white,
                                                   fontSize: 18,
                                                   fontWeight: FontWeight.bold,
                                                 ),
                                               ),
                                             ],
                                           );
                                         },
                                        loading: () => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isGuest
                                                  ? tr.get(
                                                      'welcome_guest', lang)
                                                  : tr.get(
                                                      'welcome_back', lang),
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.9),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 100,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Consumer(
                                  builder: (context, ref, child) {
                                    final hasUnread = ref.watch(hasUnreadNotificationsProvider);

                                    return GestureDetector(
                                      onTap: () {
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
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.notifications_rounded,
                                                color: Colors.white,
                                                size: 22),
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
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
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

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _buildHomeSearchAction(context),
              ),

              const SizedBox(height: 6),

              // Featured Brands Section - Grid Layout at Top
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.get('favorite_brand', ref.watch(appLanguageProvider)),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, child) {
                        final brandsAsync = ref.watch(brandsProvider);

                        return brandsAsync.when(
                          data: (brands) {
                            if (brands.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            // Show all brands dynamically
                            final displayBrands = brands;
                            final colors = [
                              const Color(0xFFDD2222),
                              const Color(0xFF2E7D32),
                              const Color(0xFFFF6B35),
                              const Color(0xFF1976D2),
                              const Color(0xFF8E24AA),
                              const Color(0xFFD81B60),
                              const Color(0xFF00897B),
                              const Color(0xFFF4511E),
                            ];

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (int i = 0; i < displayBrands.length; i++)
                                  _buildBrandCardFromApi(
                                    displayBrands[i],
                                    colors[i % colors.length],
                                  ),
                              ]);
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: Color(0xFFDD2222),
                              ),
                            ),
                          ),
                          error: (error, stack) => const SizedBox.shrink());
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Nearest Location Section
              Consumer(
                builder: (context, ref, child) {
                  final brandsAsync = ref.watch(brandsProvider);

                  return brandsAsync.when(
                    data: (brands) {
                      if (brands.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFFDD2222),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr.get('nearby_outlets', ref.watch(appLanguageProvider)),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => context
                                      .go(AppRouter.brandBranchSelection),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDD2222),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(tr.get('see_all', ref.watch(appLanguageProvider)),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.normal)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Show each brand with its nearest branch
                          ...brands.take(4).map((brand) =>
                              _buildBrandWithNearestLocation(brand, ref)),
                        ]);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stack) => const SizedBox.shrink());
                },
              ),

              const SizedBox(height: 32),

              // Points & Vouchers Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 110,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPointsCard(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildVouchersCard(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Promotional Banners with Image Placeholders
              Consumer(
                builder: (context, ref, child) {
                  final bannersAsync = ref.watch(bannersProvider);

                  return bannersAsync.when(
                    data: (banners) {
                      if (banners.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return SizedBox(
                        height: 240,
                        child: PageView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: banners.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildPromoBanner(banners[index]),
                          ),
                        ));
                    },
                    loading: () => SizedBox(
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFFDD2222),
                        ),
                      ),
                    ),
                    error: (error, stack) => SizedBox(
                      height: 240,
                      child: Center(
                        child: Text(
                          tr.get('unable_to_load_banners', ref.watch(appLanguageProvider)),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ));
                },
              ),

              const SizedBox(height: 32),

              // Restaurants Near You Section
              Consumer(
                builder: (context, ref, child) {
                  final nearbyBranchesAsync = ref.watch(nearbyBranchesProvider);

                  return nearbyBranchesAsync.when(
                    data: (nearbyBranches) {
                      if (nearbyBranches.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.near_me,
                                      color: Color(0xFFDD2222),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr.get('nearby_outlets', ref.watch(appLanguageProvider)),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => context
                                      .go(AppRouter.brandBranchSelection),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDD2222),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(tr.get('see_all', ref.watch(appLanguageProvider)),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.normal)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: nearbyBranches.length > 3
                                  ? 3
                                  : nearbyBranches.length,
                              itemBuilder: (context, index) {
                                final branchWithDistance =
                                    nearbyBranches[index];
                                return _buildNearbyRestaurantCard(
                                  branchWithDistance,
                                  context,
                                  ref);
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ]);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stack) => const SizedBox.shrink());
                },
              ),

              // Popular Items Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFDD2222),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr.get('popular_menu', ref.watch(appLanguageProvider)),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/navigation?index=1'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDD2222),
                      ),
                      child: Row(
                        children: [
                          Text(tr.get('see_all', ref.watch(appLanguageProvider)),
                              style: const TextStyle(fontWeight: FontWeight.normal)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer(
                  builder: (context, ref, child) {
                    final productsAsync = ref.watch(showcaseProductsProvider(
                      const ShowcaseProductsRequest(
                          newLimit: 15, popularLimit: 15, limit: 30),
                    ));

                    return productsAsync.when(
                      data: (showcase) {
                        final List<models.Product> sourceList = showcase.popularMenus.isNotEmpty
                            ? showcase.popularMenus
                            : showcase.combined;

                        final products = List<models.Product>.from(sourceList);
                        products.sort((a, b) {
                          final aPri = (a.isNew ? 2 : (a.isPopular ? 1 : 0));
                          final bPri = (b.isNew ? 2 : (b.isPopular ? 1 : 0));
                          if (aPri != bPri) return bPri.compareTo(aPri);
                          return 0;
                        });

                        final displayProducts = products.take(4).toList();
                        if (displayProducts.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.67,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: displayProducts.length,
                          itemBuilder: (context, index) =>
                              _buildProductCardFromApi(displayProducts[index]));
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: Color(0xFFDD2222),
                          ),
                        ),
                      ),
                      error: (error, stack) => const SizedBox.shrink());
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Active Vouchers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer(
                  builder: (context, ref, child) {
                    final vouchersAsync = ref.watch(availableVouchersProvider);
                    final lang = ref.watch(appLanguageProvider);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tr.get('active_voucher', lang),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                if (!AuthGuard.isAuthenticated(ref)) {
                                  AuthGuard.showLoginRequiredDialog(context,
                                      redirectTo: AppRouter.navigation);
                                } else {
                                  context.push(AppRouter.vouchers);
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFDD2222),
                              ),
                              child: Row(
                                children: [
                                  Text(tr.get('see_all', lang),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.normal)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        vouchersAsync.when(
                          data: (vouchers) {
                            final myVouchersAsync =
                                ref.watch(pos.myVouchersProvider);
                            return myVouchersAsync.when(
                              data: (myVouchersResponse) {
                                final activeClaimedVouchers =
                                    (myVouchersResponse?.vouchers ??
                                            <pos_models.UserVoucher>[])
                                        .where((v) => v.isActive)
                                        .toList();

                                // 1. If user has active claimed vouchers, show active vouchers (up to 2)
                                if (activeClaimedVouchers.isNotEmpty) {
                                  final displayList =
                                      activeClaimedVouchers.take(2).toList();
                                  return Column(
                                    children: [
                                      for (int i = 0; i < displayList.length; i++) ...[
                                        _buildClaimedVoucherItem(displayList[i]),
                                        if (i < displayList.length - 1)
                                          const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                                }

                                // 2. If no claimed vouchers, show available vouchers to claim (up to 2)
                                if (vouchers.isNotEmpty) {
                                  final displayList = vouchers.take(2).toList();
                                  return Column(
                                    children: [
                                      for (int i = 0; i < displayList.length; i++) ...[
                                        _buildVoucherItemFromApi(displayList[i]),
                                        if (i < displayList.length - 1)
                                          const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                                }

                                return _buildVoucherShortcutCard(
                                  title: tr.get('view_vouchers', lang),
                                  subtitle:
                                      tr.get('choose_available_voucher', lang),
                                  route: AppRouter.vouchers,
                                  color: const Color(0xFFDD2222),
                                  icon: Icons.confirmation_number_outlined,
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFDD2222),
                                  ),
                                ),
                              ),
                              error: (_, __) => vouchers.isNotEmpty
                                  ? _buildVoucherItemFromApi(vouchers.first)
                                  : _buildVoucherShortcutCard(
                                      title: tr.get('view_vouchers', lang),
                                      subtitle:
                                          tr.get('open_voucher_list', lang),
                                      route: AppRouter.vouchers,
                                      color: const Color(0xFFDD2222),
                                      icon: Icons.confirmation_number_outlined,
                                    ),
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: Color(0xFFDD2222),
                              ),
                            ),
                          ),
                          error: (error, stack) => _buildVoucherShortcutCard(
                            title: tr.get('view_vouchers', lang),
                            subtitle:
                                tr.get('login_to_view_active_vouchers', lang),
                            route: AppRouter.vouchers,
                            color: const Color(0xFFDD2222),
                            icon: Icons.confirmation_number_outlined,
                          ),
                        ),
                      ]);
                  },
                ),
              ),

              const SizedBox(height: 120), // Bottom padding for nav bar
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildPointsCard() {
    return Consumer(
      builder: (context, ref, child) {
        final lang = ref.watch(appLanguageProvider);
        final userAsync = ref.watch(currentUserProvider);

        return userAsync.when(
          data: (user) => GestureDetector(
            onTap: () {
              if (!AuthGuard.isAuthenticated(ref)) {
                AuthGuard.showLoginRequiredDialog(context,
                    redirectTo: AppRouter.navigation);
              } else {
                context.push('${AppRouter.vouchers}?tab=2');
              }
            },
            child: Container(
              height: 110,
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
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: Colors.white, size: 18),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr.get('active', lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.get('your_points', lang),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        (user?.point ?? 0).toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        tr.get('points_available', lang),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          loading: () => GestureDetector(
            onTap: () => context.push('${AppRouter.vouchers}?tab=2'),
            child: Container(
              height: 110,
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
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
          error: (error, stack) => GestureDetector(
            onTap: () => context.push('${AppRouter.vouchers}?tab=2'),
            child: Container(
              height: 110,
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
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: Colors.white, size: 18),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr.get('active', lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.get('your_points', lang),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                      const Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        tr.get('points_available', lang),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeSearchAction(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    return Container(
      height: 58,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFDD2222),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              const SizedBox(height: 2),
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
          Container(width: 1, height: 34, color: Colors.grey.shade200),
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(16)),
            onTap: () {
              if (AuthGuard.requireLogin(context, ref, redirectTo: AppRouter.qrScanner)) {
                context.go(AppRouter.qrScanner);
              }
            },
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDD2222),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ));
  }

  Widget _buildVouchersCard() {
    final lang = ref.watch(appLanguageProvider);
    final availableAsync = ref.watch(availableVouchersProvider);
    final categories =
        ref.watch(voucher_ctrl.categorizedVouchersProvider).asData?.value ??
            const {};
    final categorizedCount = (categories['auto_granted']?.length ?? 0) +
        (categories['point_redemption']?.length ?? 0) +
        (categories['cash_purchase']?.length ?? 0);
    final totalVoucherCount = availableAsync.valueOrNull?.length ?? categorizedCount;

    return GestureDetector(
      onTap: () {
        if (!AuthGuard.isAuthenticated(ref)) {
          AuthGuard.showLoginRequiredDialog(context,
              redirectTo: AppRouter.navigation);
        } else {
          context.go(AppRouter.vouchers);
        }
      },
      child: Container(
        height: 110,
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
              color: const Color(0xFFDD2222).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded,
                    color: Colors.white, size: 18),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$totalVoucherCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.get('vouchers', lang),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                  ),
                ),
                Text(
                  tr.get('available', lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                Text(
                  tr.get('tap_to_redeem', lang),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
  }

  Widget _buildPromoBanner(models.Banner banner) {
    return GestureDetector(
      onTap: () {
        // Handle banner tap based on link type
        if (banner.linkType == 'product' && banner.linkId != null) {
          // Navigate to product detail
          context.push('/product/${banner.linkId}');
        } else if (banner.linkType == 'category' && banner.linkId != null) {
          // Navigate to category menu
          context.go('${AppRouter.navigation}?index=1');
        } else {
          // Default to menu
          context.go('${AppRouter.navigation}?index=1');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner image from API
              CachedImage(
                imageUrl: banner.image,
                fit: BoxFit.cover,
                errorWidget: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDD2222),
                        Color(0xFFB01C1C),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_rounded,
                            size: 48, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (banner.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            banner.description!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
  }

  String _formatVoucherExpiryDate(dynamic dateInput, AppLanguage lang) {
    if (dateInput == null) return '';
    try {
      DateTime date;
      if (dateInput is DateTime) {
        date = dateInput.toLocal();
      } else if (dateInput is String) {
        if (dateInput.isEmpty) return '';
        date = DateTime.parse(dateInput).toLocal();
      } else {
        return '';
      }
      final months = lang == AppLanguage.english
          ? [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ]
          : [
              'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
              'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
            ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateInput.toString();
    }
  }

  Widget _buildVoucherItemFromApi(Voucher voucher) {
    return _buildElegantHomeVoucherCard(
      title: voucher.name,
      brandName: voucher.displayBrandName,
      endDate: voucher.endDate,
      type: voucher.type,
      benefitText: voucher.description,
      discountAmount: voucher.discountAmount?.toInt(),
      discountPercentage: voucher.discountPercentage?.toDouble(),
      onTap: () => context.go(AppRouter.vouchers),
    );
  }

  Widget _buildClaimedVoucherItem(pos_models.UserVoucher voucher) {
    return _buildElegantHomeVoucherCard(
      title: voucher.voucher.voucherName,
      brandName: voucher.voucher.displayBrandName,
      endDate: voucher.expiryDate,
      type: voucher.voucher.voucherType,
      benefitText: voucher.voucher.description,
      discountAmount: voucher.voucher.discountAmount?.toInt(),
      discountPercentage: voucher.voucher.discountPercentage?.toDouble(),
      onTap: () => context.go('${AppRouter.vouchers}?tab=my'),
    );
  }

  Widget _buildElegantHomeVoucherCard({
    required String title,
    required String brandName,
    dynamic endDate,
    required String type,
    required VoidCallback onTap,
    String? benefitText,
    int? discountAmount,
    double? discountPercentage,
  }) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    IconData icon;
    String badgeLabel;
    String tagLabel = isIndo ? 'GRATIS' : 'FREE';
    Color accentColor;

    switch (type.toLowerCase()) {
      case 'birthday':
      case 'bday':
        icon = Icons.cake_rounded;
        badgeLabel = 'BDAY';
        tagLabel = isIndo ? 'GRATIS' : 'FREE';
        accentColor = const Color(0xFFDB2777); // Rose
        break;
      case 'buy_1_get_1':
      case 'buy 1 get 1':
      case 'b1g1':
        icon = Icons.card_giftcard_rounded;
        badgeLabel = 'B1G1';
        tagLabel = isIndo ? 'GRATIS' : 'FREE';
        accentColor = const Color(0xFFD97706); // Amber Gold
        break;
      case 'free_menu':
      case 'free_item':
      case 'freemenu':
        icon = Icons.restaurant_rounded;
        badgeLabel = 'FREE';
        tagLabel = isIndo ? 'GRATIS' : 'FREE';
        accentColor = const Color(0xFF4F46E5); // Slate Indigo
        break;
      case 'free_delivery':
      case 'delivery':
      case 'ongkir':
        icon = Icons.delivery_dining_rounded;
        badgeLabel = isIndo ? 'ONGKIR' : 'SHIPPING';
        tagLabel = isIndo ? 'GRATIS' : 'FREE';
        accentColor = const Color(0xFF0284C7); // Sky Ocean
        break;
      case 'discount_percentage':
      case 'percentage':
      case 'percentage_off':
        icon = Icons.percent_rounded;
        badgeLabel = discountPercentage != null && discountPercentage > 0
            ? '${discountPercentage.toInt()}%'
            : '%';
        tagLabel = isIndo ? 'DISKON' : 'DISCOUNT';
        accentColor = const Color(0xFFDC2626); // Crimson Red
        break;
      default:
        if (discountPercentage != null && discountPercentage > 0) {
          icon = Icons.percent_rounded;
          badgeLabel = '${discountPercentage.toInt()}%';
          tagLabel = isIndo ? 'DISKON' : 'DISCOUNT';
          accentColor = const Color(0xFFDC2626);
        } else {
          icon = Icons.local_offer_rounded;
          badgeLabel = discountAmount != null && discountAmount > 0
              ? '${(discountAmount / 1000).round()}K'
              : (isIndo ? 'DISKON' : 'DISCOUNT');
          tagLabel = isIndo ? 'DISKON' : 'DISCOUNT';
          accentColor = const Color(0xFFDC2626);
        }
    }

    // Match the card hierarchy used in the "Voucher Saya" page.
    const frostedNeutralBg = Color(0xFFF8FAFC);
    final formattedDate = _formatVoucherExpiryDate(endDate, ref.watch(appLanguageProvider));
    final displayBrandAndDate = formattedDate.isNotEmpty ? '$brandName - s.d $formattedDate' : brandName;
    final displayBenefit = benefitText != null && benefitText.trim().isNotEmpty
        ? benefitText.trim()
        : tagLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Left: Rounded Square Frosted Neutral Box with Accent Icon & Text
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: frostedNeutralBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accentColor, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Title, brand/date, and voucher benefit.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayBrandAndDate,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    displayBenefit,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherShortcutCard({
    required String title,
    required String subtitle,
    required String route,
    required Color color,
    required IconData icon,
  }) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;
    final lang = ref.watch(appLanguageProvider);

    return GestureDetector(
      onTap: () {
        if (isGuest) {
          AuthGuard.showLoginRequiredDialog(context,
              redirectTo: AppRouter.navigation);
        } else {
          context.push(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.confirmation_number_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PROMO',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isGuest ? tr.get('login', lang) : tr.get('see_all', lang),
                    style: const TextStyle(
                      color: Color(0xFFDD2222),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFDD2222),
                    size: 9,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyRestaurantCard(
    BranchWithDistance branchWithDistance,
    BuildContext context,
    WidgetRef ref,
  ) {
    final branch = branchWithDistance.branch;

    return GestureDetector(
      onTap: () {
        // Set the selected branch and brand
        ref.read(selectedBrandProvider.notifier).state = Brand(
          id: branch.brandId,
          name: branch.brandName,
          logo: branch.brandLogo ?? '',
          service: 0,
          tax: 0,
          category: []);

        ref.read(selectedBranchProvider.notifier).state = branch;

        // Navigate to menu
        context.go('/menu?brandId=${branch.brandId}&branchId=${branch.id}');
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Logo / Image
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFDD2222).withValues(alpha: 0.8),
                    const Color(0xFFFF6B35)
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  // Brand Logo
                  if (branch.brandLogo != null && branch.brandLogo!.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CachedImage(
                          imageUrl: branch.brandLogo!,
                          height: 50,
                          width: 80,
                          fit: BoxFit.contain,
                          errorWidget: const Icon(
                            Icons.restaurant,
                            size: 40,
                            color: Color(0xFFDD2222),
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                  // Distance Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            branch.rating > 0 ? branch.rating.toStringAsFixed(1) : '4.8',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('•',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 9)),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.near_me,
                            size: 11,
                            color: Color(0xFFDD2222),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${branchWithDistance.formattedDistance} ${tr.get('from_your_location', ref.watch(appLanguageProvider))}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDD2222),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Open/Closed Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: branch.isOpenNow ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        branch.isOpenNow
                            ? (ref.watch(appLanguageProvider) == AppLanguage.indonesia ? 'BUKA' : 'OPEN')
                            : (ref.watch(appLanguageProvider) == AppLanguage.indonesia ? 'TUTUP' : 'CLOSED'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Restaurant Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Name
                  Text(
                    branch.brandName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Outlet Address
                  Text(
                    branch.displayAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          branch.location,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Opening Hours
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${branch.openingHours.length >= 5 ? branch.openingHours.substring(0, 5) : branch.openingHours} - ${branch.closingHours.length >= 5 ? branch.closingHours.substring(0, 5) : branch.closingHours} WIB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
  }

  // API-based widget builders
  Widget _buildBrandCardFromApi(Brand brand, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () => context.go(AppRouter.brandBranchSelection,
          extra: {'brandId': brand.id.toString()}),
      child: Container(
        width: (screenWidth - 52) / 2, // 2 columns with spacing
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: brand.logo.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedImage(
                        imageUrl: brand.logo,
                        width: 54,
                        height: 54,
                        fit: BoxFit.contain,
                        placeholderColor: color.withValues(alpha: 0.1),
                        errorWidget: Icon(Icons.restaurant_rounded,
                            color: color, size: 26),
                      ),
                    )
                  : Icon(Icons.restaurant_rounded, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    brand.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    brand.category.isNotEmpty ? brand.category.first : 'Food',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
  }

  Widget _buildProductCardFromApi(models.Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final branchId = product.branchId;
            context.push(
              branchId == null
                  ? '/product/${product.id}'
                  : '/product/${product.id}?branchId=$branchId');
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedImage(
                      imageUrl: product.image ?? '',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      placeholderColor: Colors.grey.shade100,
                    ),
                  ),
                ),
              ),
              // Details
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Brand Name
                      if ((product.brandName ?? '').isNotEmpty) ...[
                        Text(
                          formatBrandName(product.brandName!),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      // 2. Menu Name
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // 3. Rate Terjual
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating > 0
                                ? product.rating.toStringAsFixed(1)
                                : '5.0',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('•',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 9)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.formattedSoldFor(ref.watch(appLanguageProvider)),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // 4. Harga Menu
                      PriceDisplayWidget.fromProduct(
                        product: product,
                        fontSize: 13,
                        priceColor: const Color(0xFFDD2222),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
  }

  Widget _buildBrandWithNearestLocation(Brand brand, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      child: Consumer(
        builder: (context, ref, child) {
          final branchesAsync =
              ref.watch(branchesByBrandProvider(brand.id.toString()));

          return branchesAsync.when(
            data: (branches) {
              if (branches.isEmpty) {
                return const SizedBox.shrink();
              }

              // Get first branch (nearest)
              final nearestBranch = branches.first;

              return GestureDetector(
                onTap: () {
                  ref.read(selectedBrandProvider.notifier).state = brand;
                  ref.read(selectedBranchProvider.notifier).state =
                      nearestBranch;
                  context.go(
                      '/menu?brandId=${brand.id}&branchId=${nearestBranch.id}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Brand Logo
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: brand.logo.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(6),
                                child: CachedImage(
                                  imageUrl: brand.logo,
                                  fit: BoxFit.contain,
                                  errorWidget: const Icon(
                                    Icons.restaurant_rounded,
                                    color: Color(0xFFDD2222),
                                    size: 26,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.restaurant_rounded,
                                color: Color(0xFFDD2222),
                                size: 26,
                              ),
                      ),
                      const SizedBox(width: 14),
                      // Branch Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brand.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4.5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 13.5,
                                  color: Color(0xFFDD2222),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    nearestBranch.displayAddress,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF475569),
                                      height: 1.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4.5),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: nearestBranch.isOpenNow
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  nearestBranch.isOpenNow
                                      ? (ref.watch(appLanguageProvider) == AppLanguage.indonesia ? 'Sedang Buka' : 'Open Now')
                                      : (ref.watch(appLanguageProvider) == AppLanguage.indonesia ? 'Tutup' : 'Closed'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: nearestBranch.isOpenNow
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${nearestBranch.openingHours.length >= 5 ? nearestBranch.openingHours.substring(0, 5) : nearestBranch.openingHours} - ${nearestBranch.closingHours.length >= 5 ? nearestBranch.closingHours.substring(0, 5) : nearestBranch.closingHours} WIB',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Arrow Icon
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ));
            },
            loading: () => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            error: (_, __) => const SizedBox.shrink());
        },
      ));
  }
}
