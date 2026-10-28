import 'package:flutter/material.dart' hide Banner;
import 'dart:math' as math;
import '../../features/voucher/models/voucher_model.dart';
import '../utils/brand_name_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/ui_schema_model.dart';
import '../../shared/models/brand_model.dart';
import '../../shared/services/service_providers.dart';
import '../../shared/services/pos_service.dart' as pos;
import '../../shared/models/user_voucher_model.dart' as pos_models;
import '../../features/voucher/controllers/voucher_controller.dart' as voucher_ctrl;
import '../../features/menu/views/brand_branch_selection_view.dart';
import '../routes/app_router.dart';
import '../services/storage_service.dart';
import '../utils/auth_guard.dart';
import '../animations/animated_widgets.dart';
import '../animations/shimmer_loading.dart';
import '../localization/app_language.dart';
import 'cached_image.dart';
import 'feature_spotlight.dart';
import '../../features/home/widgets/home_banner_carousel.dart';
import '../../features/home/widgets/popup_banner_dialog.dart';
import '../../shared/models/menu_model.dart';
import '../../shared/widgets/price_display_widget.dart';

/// Dynamic widget builder that renders widgets based on schema
/// Note: Widgets fetch their own data from existing APIs (bannersProvider, brandsProvider, etc.)
/// Only the LAYOUT configuration (order, visibility, properties) comes from the schema
class DynamicWidgetBuilder extends ConsumerStatefulWidget {
  final WidgetSchema schema;

  const DynamicWidgetBuilder({
    super.key,
    required this.schema,
  });

  @override
  ConsumerState<DynamicWidgetBuilder> createState() =>
      _DynamicWidgetBuilderState();
}

class _DynamicWidgetBuilderState extends ConsumerState<DynamicWidgetBuilder> {
  WidgetSchema get schema => widget.schema;

  String _text(String key, {String? fallback}) {
    return tr.get(key, ref.watch(appLanguageProvider), fallback: fallback);
  }

  String _localizedSectionTitle(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('brand') || normalized.contains('favorit')) {
      return _text('favorite_brand', fallback: title);
    }
    if (normalized.contains('nearby') ||
        normalized.contains('outlet') ||
        normalized.contains('location') ||
        normalized.contains('lokasi')) {
      return _text('nearby_outlets', fallback: title);
    }
    if (normalized.contains('popular') || normalized.contains('populer')) {
      return _text('popular_menu', fallback: title);
    }
    if (normalized.contains('voucher')) {
      return _text('active_voucher', fallback: title);
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    if (!schema.visible) {
      return const SizedBox.shrink();
    }

    switch (schema.type) {
      case 'banner_carousel':
        return _buildBannerCarousel(context, ref);
      case 'featured_brands':
        return SpotlightTarget(
          targetKey: 'home_brands',
          child: _buildFeaturedBrands(context, ref));
      case 'points_card':
        return SpotlightTarget(
          targetKey: 'home_points_card',
          child: _buildPointsCard(context, ref));
      case 'vouchers_card':
        return SpotlightTarget(
          targetKey: 'home_vouchers_card',
          child: _buildVouchersCard(context, ref));
      case 'points_vouchers_row':
        return SpotlightTarget(
          targetKey: 'home_points_card',
          child: _buildPointsVouchersRow(context, ref));
      case 'nearest_location':
        return _buildNearestLocation(context, ref);
      case 'popular_items':
        return SpotlightTarget(
          targetKey: 'home_popular',
          child: _buildPopularItems(context, ref));
      case 'vouchers_list':
        return _buildVouchersList(context, ref);
      case 'section_header':
        return _buildSectionHeader(context);
      case 'spacer':
        return _buildSpacer();
      case 'container':
        return _buildContainer(context, ref);
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildBannerCarousel(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(bannersProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return HomeBannerCarousel(
          banners: banners,
          onTap: (banner) {
            if (banner is Banner && banner.hasPopup) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => PopupBannerDialog(
                  banners: banners.where((b) => b.hasPopup).toList(),
                  initialPage: banners.where((b) => b.hasPopup).toList().indexWhere((b) => b.id == banner.id),
                ),
              );
            } else {
              if (banner.linkType == 'product' && banner.linkId != null) {
                context.push('/product/${banner.linkId}');
              } else if (banner.linkType == 'category' && banner.linkId != null) {
                context.go('${AppRouter.navigation}?index=1');
              } else {
                context.go('${AppRouter.navigation}?index=1');
              }
            }
          },
        );
      },
      loading: () => AspectRatio(
        aspectRatio: 750 / 360,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFDD2222),
            strokeWidth: 2,
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink());
  }

  Widget _buildFeaturedBrands(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsProvider);
    final maxItems = schema.properties['max_items'] as int? ?? 8;
    final showAsGrid = schema.properties['show_as_grid'] as bool? ?? false;

    return brandsAsync.when(
      data: (brands) {
        if (brands.isEmpty) return _buildBrandShortcutCard(context, ref);

        final displayBrands = schema.properties.containsKey('max_items')
            ? brands.take(maxItems).toList()
            : brands;
        final colors = [
          const Color(0xFFDD2222),
          const Color(0xFF2E7D32),
          const Color(0xFFFF6B35),
          const Color(0xFF1976D2),
          const Color(0xFF9C27B0),
          const Color(0xFFE91E63),
          const Color(0xFF00BCD4),
          const Color(0xFFFF5722),
        ];

        if (showAsGrid) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int i = 0; i < displayBrands.length; i++)
                  _buildBrandCard(
                    context,
                    displayBrands[i],
                    colors[i % colors.length],
                    isHorizontal: false,
                  ),
              ],
            ));
        }

        // Horizontal scrollable list
        return SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayBrands.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                  right: index < displayBrands.length - 1 ? 12 : 0),
              child: _buildBrandCard(
                context,
                displayBrands[index],
                colors[index % colors.length],
                isHorizontal: true,
              ),
            ),
          ));
      },
      loading: () => SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 4,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(right: index < 3 ? 12 : 0),
            child: const BrandCardShimmer(),
          ),
        ),
      ),
      error: (_, __) => _buildBrandShortcutCard(context, ref));
  }

  Widget _buildBrandShortcutCard(BuildContext context, WidgetRef ref) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    if (!isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedCard(
          onTap: () => ref.invalidate(brandsProvider),
          child: _buildCompactShortcut(
            icon: Icons.refresh_rounded,
            title: isIndo ? 'Koneksi lambat memuat brand' : 'Slow connection loading brands',
            subtitle: isIndo ? 'Ketuk di sini untuk memuat ulang brand' : 'Tap here to reload brands',
            color: const Color(0xFFDD2222),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedCard(
        onTap: () => context.go(AppRouter.login),
        child: _buildCompactShortcut(
          icon: Icons.store_mall_directory_rounded,
          title: isIndo ? 'Masuk untuk melihat brand' : 'Login to view brands',
          subtitle: isIndo ? 'Brand favorit dan outlet akan tampil setelah login' : 'Favorite brands and outlets will appear after login',
          color: const Color(0xFFDD2222),
        ),
      ));
  }

  Widget _buildBrandCard(BuildContext context, dynamic brand, Color color,
      {bool isHorizontal = false}) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isHorizontal) {
      // Horizontal card - square design with animation
      return AnimatedCard(
        onTap: () => context.go(AppRouter.brandBranchSelection,
            extra: {'brandId': brand.id.toString()}),
        child: Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CachedBrandLogo(
                imageUrl: brand.logo,
                heroTag: 'brand-logo-${brand.id}',
                size: 44,
                backgroundColor: color.withValues(alpha: 0.1),
                iconColor: color,
                isCircular: false,
                borderRadius: 12,
              ),
              const SizedBox(height: 5),
              Text(
                brand.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ));
    }

    // Grid card - original design with animation
    return AnimatedCard(
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
            CachedBrandLogo(
              imageUrl: brand.logo,
              heroTag: 'brand-logo-${brand.id}',
              size: 54,
              backgroundColor: color.withValues(alpha: 0.1),
              iconColor: color,
              isCircular: false,
              borderRadius: 12,
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

  Widget _buildPointsVouchersRow(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 94,
        child: Row(
          children: [
            Expanded(child: _buildPointsCard(context, ref)),
            const SizedBox(width: 5),
            Expanded(child: _buildVouchersCard(context, ref)),
          ],
        ),
      ));
  }

  Widget _buildPointsCard(BuildContext context, WidgetRef ref) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        final displayPoints = isGuest ? 0 : (user?.point ?? 0);
        final formattedPoints = displayPoints.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},');

        return AnimatedCard(
          onTap: () {
            if (isGuest) {
              AuthGuard.showLoginRequiredDialog(context,
                  redirectTo: AppRouter.navigation);
            } else {
              context.go('${AppRouter.vouchers}?tab=2');
            }
          },
          child: Container(
            height: 94,
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
                        color: Colors.white, size: 20),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _text('active'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text('your_points'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _text('points_available'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formattedPoints,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ));
      },
      loading: () => Container(
        height: 94,
        padding: const EdgeInsets.all(10),
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
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (_, __) => Container(
        height: 80,
        padding: const EdgeInsets.all(10),
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
                const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _text('active'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('your_points'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _text('points_available'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isGuest ? '0' : '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
  }

  Widget _buildVouchersCard(BuildContext context, WidgetRef ref) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;
    final availableAsync = ref.watch(availableVouchersProvider);
    final categorizedAsync = ref.watch(voucher_ctrl.categorizedVouchersProvider);

    final availableCount = availableAsync.valueOrNull?.length;
    final categorizedCount = categorizedAsync.valueOrNull != null
        ? ((categorizedAsync.valueOrNull!['auto_granted']?.length ?? 0) +
            (categorizedAsync.valueOrNull!['point_redemption']?.length ?? 0) +
            (categorizedAsync.valueOrNull!['cash_purchase']?.length ?? 0))
        : null;

    final totalVoucherCount = availableCount ?? categorizedCount ?? 0;

    return AnimatedCard(
      onTap: () {
        if (isGuest) {
          AuthGuard.showLoginRequiredDialog(context,
              redirectTo: AppRouter.navigation);
        } else {
          context.go(AppRouter.vouchers);
        }
      },
      child: Container(
        height: 94,
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
                    color: Colors.white, size: 20),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _text('available'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('vouchers'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _text('tap_to_redeem'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (availableAsync.isLoading && categorizedAsync.isLoading && totalVoucherCount == 0)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      (availableAsync.hasError && categorizedAsync.hasError && !isGuest && totalVoucherCount == 0)
                          ? '-'
                          : '$totalVoucherCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearestLocation(BuildContext context, WidgetRef ref) {
    final nearbyBranchesAsync = ref.watch(nearbyBranchesProvider);
    final maxItems = schema.properties['max_items'] as int? ?? 3;

    return nearbyBranchesAsync.when(
      data: (branches) {
        final displayBranches = branches.take(maxItems).toList();

        if (displayBranches.isEmpty) return _buildLocationShortcutCard(context, ref);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: displayBranches.map((branchWithDistance) {
            final branch = branchWithDistance.branch;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
              child: AnimatedCard(
                onTap: () {
                  ref.read(selectedBrandProvider.notifier).state = Brand(
                    id: branch.brandId,
                    name: branch.brandName,
                    logo: branch.brandLogo ?? '',
                    service: 0,
                    tax: 0,
                    category: const []);

                  ref.read(selectedBranchProvider.notifier).state = branch;
                  context.go(
                      '/menu?brandId=${branch.brandId}&branchId=${branch.id}');
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
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDD2222).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: CachedImage(
                            imageUrl: branch.brandLogo ?? '',
                            fit: BoxFit.contain,
                            errorWidget: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.restaurant_rounded,
                                color: Color(0xFFDD2222),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch.brandName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                    branch.displayAddress,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF334155),
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
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 2.5),
                                Text(
                                  branch.rating > 0
                                      ? branch.rating.toStringAsFixed(1)
                                      : '4.8',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '•',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 12.5,
                                  color: Color(0xFF475569),
                                ),
                                const SizedBox(width: 3.5),
                                Expanded(
                                  child: Text(
                                    '${branchWithDistance.formattedDistance} ${_text('from_your_location')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
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
                  ),
                ),
              ));
          }).toList());
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildLocationShortcutCard(context, ref));
  }

  Widget _buildLocationShortcutCard(BuildContext context, WidgetRef ref) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;

    if (!isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedCard(
          onTap: () => ref.invalidate(nearbyBranchesProvider),
          child: _buildCompactShortcut(
            icon: Icons.refresh_rounded,
            title: isIndo ? 'Koneksi lambat memuat outlet' : 'Slow connection loading outlets',
            subtitle: isIndo ? 'Ketuk di sini untuk memuat ulang outlet terdekat' : 'Tap here to reload nearby outlets',
            color: const Color(0xFFDD2222),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedCard(
        onTap: () => context.go(AppRouter.login),
        child: _buildCompactShortcut(
          icon: Icons.location_on_rounded,
          title: isIndo ? 'Masuk untuk melihat outlet' : 'Login to view outlets',
          subtitle: isIndo ? 'Outlet terdekat akan tampil setelah lokasi tersedia' : 'Nearest outlets will appear once location is available',
          color: const Color(0xFFDD2222),
        ),
      ));
  }

  Widget _buildCompactShortcut({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: color, size: 18),
        ],
      ));
  }

  Widget _buildPopularItems(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(showcaseProductsProvider(
      const ShowcaseProductsRequest(newLimit: 15, popularLimit: 15, limit: 30),
    ));
    final maxItems = schema.properties['max_items'] as int? ?? 4;
    final columns = schema.properties['columns'] as int? ?? 2;

    return productsAsync.when(
      data: (showcase) {
        final List<Product> sourceList = showcase.popularMenus.isNotEmpty
            ? showcase.popularMenus
            : showcase.combined;

        // Prioritize Menu Baru and Menu Populer first, filled by monthly best sellers
        final products = List<Product>.from(sourceList);
        products.sort((a, b) {
          final aPri = (a.isNew ? 2 : (a.isPopular ? 1 : 0));
          final bPri = (b.isNew ? 2 : (b.isPopular ? 1 : 0));
          if (aPri != bPri) return bPri.compareTo(aPri);
          return 0;
        });

        final displayProducts = products.take(maxItems).toList();
        if (displayProducts.isEmpty) return _buildPopularEmptyState(context);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio:
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.05
                      ? 0.60
                      : 0.63,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: displayProducts.length,
            itemBuilder: (context, index) {
              return _buildProductCard(displayProducts[index]);
            },
          ));
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridShimmer(
          crossAxisCount: columns,
          itemCount: maxItems,
        ),
      ),
      error: (_, __) => _buildPopularEmptyState(
            context,
            isError: true,
            onRetry: () => ref.invalidate(showcaseProductsProvider),
          ));
  }

  Widget _buildPopularEmptyState(BuildContext context,
      {bool isError = false, VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
      child: AnimatedCard(
        onTap: onRetry ?? () => context.go(AppRouter.brandBranchSelection),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isError
                    ? Icons.refresh_rounded
                    : Icons.restaurant_menu_outlined,
                color: isError
                    ? const Color(0xFFDD2222)
                    : Colors.grey.shade400,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                isError
                    ? _text('slow_connection_reload')
                    : _text('no_popular_menus'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isError
                      ? const Color(0xFFDD2222)
                      : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ));
  }


  Widget _buildProductCard(
    dynamic product, {
    bool forcePopular = false,
    bool forceNew = false,
  }) {
    String formattedPrice = '';
    if (product is Product) {
      formattedPrice = product.formattedPrice;
    } else {
      try {
        final double rawPrice = (product.price as num?)?.toDouble() ?? 0.0;
        formattedPrice =
            'Rp ${rawPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
      } catch (_) {
        formattedPrice = 'Rp 0';
      }
    }

    final bool isNew = forceNew ||
        (product is Product
            ? product.isNew
            : (product.isNew == true ||
                product.showcaseType == 'new' ||
                (product.type?.toString().toLowerCase().contains('baru') ?? false) ||
                (product.tipe?.toString().toLowerCase().contains('baru') ?? false)));

    final bool isPopular = !isNew &&
        (forcePopular ||
            (product is Product
                ? product.isPopular
                : (product.isPopular == true ||
                    product.showcaseType == 'popular' ||
                    (product.type?.toString().toLowerCase().contains('populer') ?? false) ||
                    (product.tipe?.toString().toLowerCase().contains('populer') ?? false))));

    return AnimatedCard(
      onTap: () async {
        int? branchId = product.branchId;
        final nearestBranch = await ref.read(nearestBranchForBrandProvider(product.brandId).future);
        if (nearestBranch != null) {
          branchId = nearestBranch.id;
        }
        if (mounted) {
          context.push(
            branchId == null
                ? '/product/${product.id}'
                : '/product/${product.id}?branchId=$branchId');
        }
      },
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedImage(
                        imageUrl: product.image ?? '',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        heroTag: 'product_photo_${product.id}',
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(16)),
                        placeholderColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _text('new'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isPopular)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _text('popular'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Nama Brand
                  if ((product.brandName ?? '').isNotEmpty) ...[
                    Text(
                      formatBrandName(product.brandName!),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  // 2. Nama Menu
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                      color: Color(0xFF0F172A),
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
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        (product.reviewCount > 0 && product.rating != null && (product.rating as num) > 0)
                            ? (product.rating as num).toDouble().toStringAsFixed(1)
                            : '0.0',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.formattedSoldFor(ref.watch(appLanguageProvider)),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 4. Harga Menu
                  if (product is Product)
                    PriceDisplayWidget.fromProduct(
                      product: product,
                      fontSize: 15,
                      priceColor: const Color(0xFFDD2222),
                    )
                  else if (product is Menu)
                    PriceDisplayWidget.fromMenu(
                      menu: product,
                      fontSize: 15,
                      priceColor: const Color(0xFFDD2222),
                    )
                  else
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFFDD2222),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ));
  }

  Widget _buildSectionHeader(BuildContext context) {
    final rawTitle = schema.properties['title'] as String? ?? '';
    final title = _localizedSectionTitle(rawTitle);
    final showSeeAll = schema.properties['show_see_all'] as bool? ?? false;
    final seeAllRoute = schema.properties['see_all_route'] as String?;
    String? rawIcon = schema.properties['icon'] as String?;

    // Default star icon for Brand Favorit if not explicitly specified
    if (rawIcon == null &&
        (rawTitle.toLowerCase().contains('brand') ||
            rawTitle.toLowerCase().contains('favorit'))) {
      rawIcon = 'star';
    }

    return SlideFadeIn(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: (rawTitle.toLowerCase().contains('voucher') || title.toLowerCase().contains('voucher')) ? 15 : 10,
          bottom: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (rawIcon != null) ...[
                  Icon(
                    _getIconData(rawIcon),
                    color: const Color(0xFFDD2222),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            if (showSeeAll)
              TextButton(
                onPressed: () {
                  final isAuthed = AuthGuard.isAuthenticated(ref);
                  final normalizedRaw = rawTitle.toLowerCase();
                  final normalizedTitle = title.toLowerCase();
                  final targetRoute = seeAllRoute?.toLowerCase() ?? '';

                  final isVoucherSection = normalizedRaw.contains('voucher') ||
                      normalizedTitle.contains('voucher') ||
                      targetRoute.contains('voucher');

                  if (isVoucherSection) {
                    if (!isAuthed) {
                      AuthGuard.showLoginRequiredDialog(context,
                          redirectTo: AppRouter.navigation);
                      return;
                    }
                    context.go(seeAllRoute ?? AppRouter.vouchers);
                    return;
                  }

                  if (seeAllRoute != null) {
                    if (targetRoute.contains('voucher') && !isAuthed) {
                      AuthGuard.showLoginRequiredDialog(context,
                          redirectTo: AppRouter.navigation);
                      return;
                    }
                    context.go(seeAllRoute);
                  } else if (normalizedRaw.contains('popular') ||
                      normalizedRaw.contains('populer')) {
                    context.go('/navigation?index=1');
                  } else if (normalizedRaw.contains('brand')) {
                    context.go(AppRouter.brandBranchSelection);
                  } else if (normalizedRaw.contains('location') ||
                      normalizedRaw.contains('lokasi')) {
                    context.go(AppRouter.brandBranchSelection);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDD2222),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(_text('see_all'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
              ),
          ],
        ),
      ));
  }

  Widget _buildSpacer() {
    final height = (schema.properties['height'] as num?)?.toDouble() ?? 24.0;
    return SizedBox(height: height);
  }

  Widget _buildContainer(BuildContext context, WidgetRef ref) {
    final padding = schema.style?['padding'] as num? ?? 0;

    return Padding(
      padding: EdgeInsets.all(padding.toDouble()),
      child: schema.children != null
          ? Column(
              children: schema.children!
                  .map((child) => DynamicWidgetBuilder(
                        key: ValueKey(child.id ?? '${child.type}_${child.order}'),
                        schema: child,
                      ))
                  .toList(),
            )
          : const SizedBox.shrink());
  }

  Widget _buildVouchersList(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(availableVouchersProvider);
    final myVouchersAsync = ref.watch(pos.myVouchersProvider);
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    if (isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: vouchersAsync.when(
          data: (vouchers) {
            final displayVouchers = vouchers.take(2).toList();
            if (displayVouchers.isEmpty) {
              return _buildVoucherShortcutCard(
                title: _text('view_vouchers'),
                subtitle: _text('choose_available_voucher'),
                icon: Icons.confirmation_number_outlined,
                color: const Color(0xFFDD2222),
                route: AppRouter.vouchers,
              );
            }

            return Column(
              children: [
                for (int i = 0; i < displayVouchers.length; i++) ...[
                  _buildUnclaimedVoucherItem(displayVouchers[i]),
                  if (i < displayVouchers.length - 1)
                    const SizedBox(height: 12),
                ],
              ]);
          },
          loading: () => const ListItemShimmer(),
          error: (_, __) => _buildVoucherShortcutCard(
            title: _text('view_vouchers'),
            subtitle: _text('login_to_view_active_vouchers'),
            icon: Icons.confirmation_number_outlined,
            color: const Color(0xFFDD2222),
            route: AppRouter.vouchers,
          ),
        ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: vouchersAsync.when(
        data: (vouchers) => myVouchersAsync.when(
          data: (myVoucherResponse) {
            final claimedVouchers = myVoucherResponse?.vouchers ?? [];
            final claimedVoucherIds =
                claimedVouchers.map((voucher) => voucher.voucher.id).toSet();
            final unclaimedVouchers = vouchers
                .where((voucher) => !claimedVoucherIds.contains(voucher.id))
                .toList();

            final cards = <Widget>[];

            if (unclaimedVouchers.isNotEmpty) {
              final displayUnclaimed = unclaimedVouchers.take(2).toList();
              for (var voucher in displayUnclaimed) {
                cards.add(_buildUnclaimedVoucherItem(voucher));
              }
            } else if (claimedVouchers.isNotEmpty) {
              final claimed = claimedVouchers.firstWhere(
                (voucher) => voucher.isActive,
                orElse: () => claimedVouchers.first);
              cards.add(_buildClaimedVoucherItem(claimed));
            }

            if (cards.isEmpty) {
              return _buildVoucherShortcutCard(
                title: _text('view_vouchers'),
                subtitle: _text('find_vouchers_to_claim'),
                icon: Icons.confirmation_number_outlined,
                color: const Color(0xFFDD2222),
                route: AppRouter.vouchers);
            }

            if (unclaimedVouchers.isEmpty && claimedVouchers.isNotEmpty) {
              return _buildAllVouchersClaimedPremiumBanner(claimedVouchers);
            }

            return Column(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1) const SizedBox(height: 12),
                ],
              ]);
          },
          loading: () => const ListItemShimmer(),
          error: (_, __) => _buildVoucherListFromAvailableOnly(vouchers),
        ),
        loading: () => Column(
          children: List.generate(
            2,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 0 ? 12 : 0),
              child: const ListItemShimmer(),
            ),
          ),
        ),
        error: (error, stack) => _buildVoucherShortcutCard(
          title: _text('view_vouchers'),
          subtitle: _text('login_to_view_active_vouchers'),
          icon: Icons.confirmation_number_outlined,
          color: const Color(0xFFDD2222),
          route: AppRouter.vouchers,
        ),
      ));
  }

  Widget _buildVoucherListFromAvailableOnly(List<dynamic> vouchers) {
    if (vouchers.isEmpty) {
      return _buildVoucherShortcutCard(
        title: _text('view_vouchers'),
        subtitle: _text('open_voucher_list'),
        icon: Icons.confirmation_number_outlined,
        color: const Color(0xFFDD2222),
        route: AppRouter.vouchers);
    }

    return _buildUnclaimedVoucherItem(vouchers.first);
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

  Widget _buildUnclaimedVoucherItem(dynamic voucher) {
    if (voucher is Voucher) {
      final lang = ref.watch(appLanguageProvider);
      return _buildVoucherItem(
        title: voucher.voucherName,
        brandName: voucher.displayBrandName,
        endDate: voucher.endDate,
        type: voucher.voucherType,
        route: AppRouter.vouchers,
        discountAmount: voucher.discountAmount?.toInt(),
        discountPercentage: voucher.discountPercentage?.toDouble(),
        benefitSummary: voucher.getBenefitSummary(lang),
        acquisitionType: voucher.acquisitionType,
        isFree: voucher.isFreeVoucher,
        isBirthday: voucher.voucherType.toLowerCase() == 'birthday' ||
            voucher.acquisitionType == 'birthday',
        isOutletQr: voucher.isOutletQrVoucher,
        points: voucher.point,
        price: voucher.price,
        isLimitedStock: voucher.isLimitedStock,
        isSoldOut: voucher.isSoldOut,
        remainingStock: voucher.remainingStock,
      );
    }

    return _buildVoucherItem(
      title: voucher.name,
      brandName: (voucher.brandName != null && voucher.brandName.toString().isNotEmpty)
          ? voucher.brandName.toString()
          : 'Delitopia',
      endDate: voucher.endDate,
      type: voucher.type,
      discountAmount: voucher.discountAmount is int
          ? voucher.discountAmount
          : (voucher.discountAmount is double
              ? (voucher.discountAmount as double).toInt()
              : null),
      discountPercentage: voucher.discountPercentage is double
          ? voucher.discountPercentage
          : (voucher.discountPercentage is int
              ? (voucher.discountPercentage as int).toDouble()
              : null),
      route: AppRouter.vouchers,
      isFree: true,
    );
  }

  Widget _buildClaimedVoucherItem(pos_models.UserVoucher voucher) {
    return _buildVoucherItem(
      title: voucher.voucher.voucherName,
      brandName: voucher.voucher.displayBrandName,
      endDate: voucher.expiryDate,
      type: voucher.voucher.voucherType,
      discountAmount: voucher.voucher.discountAmount?.toInt(),
      discountPercentage: voucher.voucher.discountPercentage?.toDouble(),
      benefitSummary: voucher.voucher.discountText,
      route: '${AppRouter.vouchers}?tab=my',
      isFree: true,
    );
  }

  Widget _buildAllVouchersClaimedPremiumBanner(List<pos_models.UserVoucher> claimedVouchers) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;
    final route = '${AppRouter.vouchers}?tab=my';

    return AnimatedCard(
      onTap: () {
        if (isGuest) {
          AuthGuard.showLoginRequiredDialog(context, redirectTo: AppRouter.navigation);
        } else {
          context.go(route);
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
            // Left: Standard Voucher Leading Template
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
            // Middle: Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('all_vouchers_claimed_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _text('all_vouchers_claimed_subtitle'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: Clean Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
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
    required IconData icon,
    required Color color,
    required String route,
  }) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    return AnimatedCard(
      onTap: () {
        if (isGuest) {
          AuthGuard.showLoginRequiredDialog(context,
              redirectTo: AppRouter.navigation);
        } else {
          context.go(route);
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
                    isGuest ? _text('login') : _text('see_all'),
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

  Widget _buildVoucherItem({
    required String title,
    required String brandName,
    dynamic endDate,
    required String type,
    required String route,
    int? discountAmount,
    double? discountPercentage,
    String? benefitSummary,
    String? acquisitionType,
    bool isFree = false,
    bool isBirthday = false,
    bool isOutletQr = false,
    int points = 0,
    double price = 0,
    bool isLimitedStock = false,
    bool isSoldOut = false,
    int? remainingStock,
  }) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;
    final typeLower = type.toLowerCase();

    IconData icon;
    String shortLabel = '';
    Color accentColor;

    if (typeLower == 'birthday' || typeLower == 'bday') {
      icon = Icons.cake_rounded;
      shortLabel = 'BDAY';
      accentColor = const Color(0xFFDB2777); // Rose
    } else if (typeLower == 'buy_1_get_1' || typeLower == 'buy 1 get 1' || typeLower == 'b1g1') {
      icon = Icons.card_giftcard_rounded;
      shortLabel = 'B1G1';
      accentColor = const Color(0xFFD97706); // Amber Gold
    } else if (typeLower == 'free_menu' || typeLower == 'free_item' || typeLower == 'freemenu') {
      icon = Icons.restaurant_rounded;
      shortLabel = 'FREE';
      accentColor = const Color(0xFF4F46E5); // Slate Indigo
    } else if (typeLower == 'free_delivery' || typeLower == 'delivery' || typeLower == 'ongkir') {
      icon = Icons.delivery_dining_rounded;
      shortLabel = isIndo ? 'ONGKIR' : 'SHIPPING';
      accentColor = const Color(0xFF0284C7); // Sky Ocean
    } else if (discountAmount != null && discountAmount > 0) {
      icon = Icons.local_offer_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      final rb = (discountAmount / 1000).round();
      shortLabel = '${rb}K';
    } else if (discountPercentage != null && discountPercentage > 0) {
      icon = Icons.percent_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      shortLabel = '${discountPercentage.toInt()}%';
    } else if (points > 0) {
      icon = Icons.stars_rounded;
      shortLabel = '${points}P';
      accentColor = const Color(0xFFEA580C); // Warm Orange
    } else if (price > 0) {
      icon = Icons.payments_rounded;
      shortLabel = 'DEAL';
      accentColor = const Color(0xFF059669); // Emerald
    } else {
      icon = Icons.local_offer_rounded;
      accentColor = const Color(0xFFDC2626); // Delitopia Crimson
      shortLabel = 'PROMO';
    }

    // Determine corner ribbon text & color (matching vouchers_view.dart)
    String cornerText = '';
    Color cornerColor = accentColor;

    if (isBirthday) {
      cornerText = 'Birth';
      cornerColor = const Color(0xFFDB2777);
    } else if (isOutletQr) {
      cornerText = 'Scan';
      cornerColor = const Color(0xFF2563EB);
    } else if (points > 0) {
      cornerText = '${points}P';
      cornerColor = const Color(0xFFEA580C);
    } else if (isFree || (price == 0 && points == 0 && !isOutletQr && !isBirthday)) {
      cornerText = 'Free';
      cornerColor = accentColor;
    } else if (price > 0) {
      cornerText = 'Rp';
      cornerColor = const Color(0xFF059669);
    }

    // Frosted Neutral Glass (#F8FAFC) with soft accent-tinted border & icon
    const frostedNeutralBg = Color(0xFFF8FAFC);
    final formattedDate = _formatVoucherExpiryDate(endDate, lang);
    final displayBrandAndDate = formattedDate.isNotEmpty
        ? '$brandName - ${tr.get('valid_until_short', lang)} $formattedDate'
        : brandName;

    // Benefit text fallback if not provided
    final String displayBenefit;
    if (benefitSummary != null && benefitSummary.trim().isNotEmpty) {
      displayBenefit = benefitSummary.trim();
    } else if (discountPercentage != null && discountPercentage > 0) {
      displayBenefit = isIndo ? 'Diskon ${discountPercentage.toInt()}%' : '${discountPercentage.toInt()}% Discount';
    } else if (discountAmount != null && discountAmount > 0) {
      displayBenefit = isIndo ? 'Potongan Rp ${(discountAmount / 1000).round()}rb' : 'Rp ${(discountAmount / 1000).round()}k Off';
    } else if (typeLower == 'free_menu' || typeLower == 'free_item') {
      displayBenefit = isIndo ? 'Gratis Menu Pilihan' : 'Free Selected Menu';
    } else if (typeLower == 'buy_1_get_1' || typeLower == 'b1g1') {
      displayBenefit = isIndo ? 'Beli 1 Gratis 1' : 'Buy 1 Get 1';
    } else if (typeLower == 'free_delivery' || typeLower == 'ongkir') {
      displayBenefit = isIndo ? 'Gratis Ongkir' : 'Free Delivery';
    } else {
      displayBenefit = isIndo ? 'Voucher Spesial' : 'Special Voucher';
    }

    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    const size = 52.0;
    final leadingBorderRadius = BorderRadius.circular(13);

    return AnimatedCard(
      onTap: () {
        if (isGuest) {
          AuthGuard.showLoginRequiredDialog(context,
              redirectTo: AppRouter.navigation);
        } else {
          context.go(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Left: Thematic Leading with Icon & Corner Ribbon
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: frostedNeutralBg,
                borderRadius: leadingBorderRadius,
                border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: leadingBorderRadius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center icon and short label
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: accentColor, size: 19),
                        const SizedBox(height: 2),
                        Text(
                          shortLabel,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),

                    // Top-left diagonal ribbon (clipped inside border)
                    if (cornerText.isNotEmpty)
                      Positioned(
                        top: 4.6,
                        left: -20.2,
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: Container(
                            width: 58.0,
                            height: 12.5,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cornerColor,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              cornerText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 6.9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.15,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Title, Brand & Expiry Date, and Benefit Summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSoldOut) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            isIndo ? 'HABIS' : 'SOLD OUT',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayBrandAndDate,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.normal,
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
                  if (isLimitedStock && !isSoldOut && remainingStock != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Text(
                        isIndo
                            ? '🔥 Sisa $remainingStock Kuota'
                            : '🔥 $remainingStock Left',
                        style: const TextStyle(
                          color: Color(0xFFC2410C),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Chevron Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'location_on':
        return Icons.location_on;
      case 'star':
        return Icons.star;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_fire_department':
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.widgets;
    }
  }
}
