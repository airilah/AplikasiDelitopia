import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/dynamic_widget_builder.dart';
import '../../../core/widgets/feature_tour_wrapper.dart';
import '../../../shared/services/ui_schema_provider.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/models/product_model.dart' as models;
import '../widgets/home_header_widget.dart';
import '../widgets/popup_banner_dialog.dart';
import '../../../core/localization/app_language.dart';


class DynamicHomePage extends ConsumerStatefulWidget {
  const DynamicHomePage({super.key});

  @override
  ConsumerState<DynamicHomePage> createState() => _DynamicHomePageState();
}

class _DynamicHomePageState extends ConsumerState<DynamicHomePage> {
  static bool _hasShownPopupThisSession = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Show popup after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPopup();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndShowPopup() async {
    if (_hasShownPopupThisSession) return;

    try {
      final banners = await ref.read(bannersProvider.future);
      if (!mounted || _hasShownPopupThisSession || banners.isEmpty) return;

      // Find all banners with popup
      final popupBanners = banners.where((b) => b.hasPopup).toList();

      if (popupBanners.isNotEmpty) {
        _hasShownPopupThisSession = true;
        _showBannerPopupSlides(popupBanners);
      }
    } catch (_) {}
  }

  void _showBannerPopupSlides(List<models.Banner> popupBanners) {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => PopupBannerDialog(banners: popupBanners));
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(storageServiceProvider).getAuthToken();
    final isGuest = token == null || token.isEmpty;

    final schemaAsync = ref.watch(uiSchemaProvider);

    return FeatureTourWrapper(
        featureKey: 'home',
        enabled: !schemaAsync.isLoading && !schemaAsync.hasError,
        scrollController: _scrollController,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: schemaAsync.when(
            data: (schema) {
              // Sort sections by order
              final sections = List.from(schema.homePage.sections)
                ..sort((a, b) => a.order.compareTo(b.order));

              return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(uiSchemaProvider);
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(userPointsBalanceProvider);
                    ref.invalidate(bannersProvider);
                    ref.invalidate(brandsProvider);
                    ref.invalidate(branchesProvider);
                    ref.invalidate(nearbyBranchesProvider);
                    ref.invalidate(popularProductsProvider);
                    ref.invalidate(showcaseProductsProvider);
                    try {
                      await Future.wait([
                        ref.read(bannersProvider.future),
                        ref.read(brandsProvider.future),
                        ref.read(uiSchemaProvider.future),
                      ]);
                    } catch (_) {}
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header & Floating Overlapping Search Bar
                        // Extracted to HomeHeaderWidget to isolate rebuild scope.
                        // Previously: 400 lines of inline widget code.
                        HomeHeaderWidget(isGuest: isGuest),

                        const SizedBox(height: 28),

                        ...sections
                            .where((section) => section.visible)
                            .map((section) => DynamicWidgetBuilder(
                                  key: ValueKey(section.id ??
                                      '${section.type}_${section.order}'),
                                  schema: section,
                                )),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ));
            },
            loading: () => Scaffold(
              backgroundColor: Colors.grey[50],
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header shimmer
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFDD2222).withValues(alpha: 0.3),
                            const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 120,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Content shimmer
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Brands shimmer
                          Container(
                            width: 100,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(
                              4,
                              (index) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  width: 140,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Banner shimmer
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ref.watch(appLanguageProvider) == AppLanguage.indonesia
                        ? 'Gagal memuat halaman'
                        : 'Failed to load page',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(uiSchemaProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(tr.get('retry', ref.watch(appLanguageProvider))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

}


