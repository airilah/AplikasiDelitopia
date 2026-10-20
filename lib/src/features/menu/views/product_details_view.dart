import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/animations/shimmer_loading.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/localization/app_language.dart';
import 'package:go_router/go_router.dart';
import '../controllers/menu_controller.dart';
import '../controllers/favorite_controller.dart';
import '../../favorites/controllers/favorite_controller.dart'
    as profile_favorites;
import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_model.dart';
import '../views/brand_branch_selection_view.dart';
import '../../../shared/models/brand_model.dart';
import '../../../shared/models/branch_model.dart';
import '../../../shared/models/menu_model.dart';
import '../../../shared/services/service_providers.dart'
    show branchesProvider, userPositionProvider, locationServiceProvider;
import '../../../shared/services/location_service.dart' show BranchWithDistance;
import '../../../shared/widgets/price_display_widget.dart';

class ProductDetailsView extends ConsumerStatefulWidget {
  final String productId;
  final String? branchId;

  const ProductDetailsView({
    super.key,
    required this.productId,
    this.branchId,
  });

  @override
  ConsumerState<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends ConsumerState<ProductDetailsView> {
  int _quantity = 1;
  final _notesController = TextEditingController();
  bool _isAddingToCart = false;
  Branch? _activeBranch;
  double? _activeBranchDistance;
  bool _hasInitializedBranch = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final productId = int.tryParse(widget.productId) ?? 0;

    if (productId <= 0) {
      return BackButtonWrapper(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const AppBackButton(color: Colors.black87),
            title: Text(
              lang == AppLanguage.indonesia ? 'Detail Menu' : 'Product Details',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    lang == AppLanguage.indonesia
                        ? 'Menu tidak ditemukan'
                        : 'Menu not found',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final detailKey = ProductDetailsKey(
      menuId: productId,
      branchId: widget.branchId);
    final productAsync = ref.watch(productDetailsProvider(detailKey));
    final reviewsKey = MenuReviewsKey(menuId: productId);
    final reviewsAsync = ref.watch(menuReviewsProvider(reviewsKey));

    return BackButtonWrapper(
      child: Scaffold(
        body: productAsync.when(
          data: (product) {
            if (!_hasInitializedBranch) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _initActiveBranch(product);
              });
            }

            return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: const Color(0xFFDD2222),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const AppBackButton(color: Colors.black87),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base pure white background
                      Container(color: Colors.white),

                      // Full uncropped photo seamlessly blending into pure white background
                      if (product.photo.isNotEmpty)
                        Positioned.fill(
                          child: CachedImage(
                            imageUrl: product.photo,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            heroTag: 'product_photo_${product.id}',
                            placeholderColor: Colors.white,
                            errorWidget: Container(
                              color: Colors.white,
                              child: const Center(
                                child: Icon(
                                  Icons.fastfood,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.white,
                          child: const Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      // Favorite button
                      Positioned(
                        top: 50,
                        right: 16,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final favoriteMenuId = product.menuTemplateId ?? product.id;
                            final isFavAsync =
                                ref.watch(isFavoriteProvider(favoriteMenuId));
                            return isFavAsync.when(
                              data: (isFav) => CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : Colors.black,
                                  ),
                                  onPressed: () async {
                                    if (!AuthGuard.requireLogin(context, ref)) {
                                      return;
                                    }

                                    try {
                                      final isNowFavorite = await ref
                                          .read(favoriteControllerProvider.notifier)
                                          .toggleFavorite(
                                            favoriteMenuId,
                                            product.name,
                                            product.price,
                                            menuTemplateId: product.menuTemplateId ?? productId,
                                            branchId: _effectiveBranchId(product));
                                      ref.invalidate(
                                          profile_favorites.favoritesProvider);
                                      ref.invalidate(isFavoriteProvider(favoriteMenuId));

                                      if (context.mounted) {
                                        final isId = ref.read(appLanguageProvider) == AppLanguage.indonesia;
                                        Helpers.showCustomAlert(
                                          context,
                                          isNowFavorite
                                              ? (isId ? 'Menu ditambahkan ke favorit' : 'Menu added to favorites')
                                              : (isId ? 'Menu dihapus dari favorit' : 'Menu removed from favorites'),
                                          isSuccess: isNowFavorite,
                                          bottomOffset: 12,
                                          includeBottomPadding: false,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Helpers.showCustomAlert(
                                          context,
                                          _friendlyFavoriteError(e),
                                          isSuccess: false,
                                          duration: const Duration(seconds: 2),
                                          bottomOffset: 12,
                                          includeBottomPadding: false,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              loading: () => const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (_, __) => CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.favorite_border,
                                    color: Colors.black,
                                  ),
                                  onPressed: () {},
                                ),
                              ));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Availability
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: product.canBeOrdered
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.canBeOrdered
                                  ? (lang == AppLanguage.indonesia ? 'Tersedia' : 'Available')
                                  : product.unavailableLabelFor(lang),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: product.canBeOrdered
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Category
                      if (product.category.isNotEmpty) ...[
                        Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Rating & Sold Count right below Category - Clickable to Reviews
                      InkWell(
                        onTap: () {
                          final templateId = product.menuTemplateId ?? product.id;
                          context.push(
                            '/product-reviews/$templateId?name=${Uri.encodeComponent(product.name)}',
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: reviewsAsync.maybeWhen(
                            data: (reviewsData) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  reviewsData.totalReviews > 0
                                      ? reviewsData.averageRating.toStringAsFixed(1)
                                      : '5.0',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${reviewsData.totalReviews} ${lang == AppLanguage.indonesia ? 'Ulasan' : 'Reviews'})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '•',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  product.formattedSoldFor(lang),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                            orElse: () => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 4),
                                const Text(
                                  '5.0',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '•',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  product.formattedSoldFor(lang),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Baris Outlet Cabang (Tepat di atas harga)
                      _buildBranchBar(context, lang, product),

                      const SizedBox(height: 12),

                      // Price
                      PriceDisplayWidget.fromMenu(
                        menu: product,
                        fontSize: 22,
                        priceColor: const Color(0xFFDD2222),
                        showBadge: true,
                      ),

                      const SizedBox(height: 14),

                      // Description
                      if (product.description.isNotEmpty) ...[
                        Text(
                          lang == AppLanguage.indonesia ? 'Deskripsi' : 'Description',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: const Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Special Notes
                      Text(
                        '${tr.get('special_notes', lang)} (${tr.get('optional', lang)})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: tr.get('special_notes_hint', lang),
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('${tr.get('something_went_wrong', lang)}: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(
                    productDetailsProvider(detailKey),
                  ),
                  child: Text(tr.get('retry', lang)),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: productAsync.when(
          data: (product) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity Selector - Fixed 48px Height
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.add),
                          onPressed: product.canBeOrdered
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Add to Cart Button - Fixed 48px Height
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: product.canBeOrdered && !_isAddingToCart
                            ? () => _addToCart(product)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: product.canBeOrdered
                              ? const Color(0xFFDD2222)
                              : Colors.grey[200],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[200],
                        ),
                        child: _isAddingToCart
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                product.canBeOrdered
                                    ? tr.get('add_to_cart', lang)
                                    : product.unavailableLabelFor(lang),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: product.canBeOrdered ? Colors.white : Colors.grey[600],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          loading: () => _buildLoadingSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ));
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFFDD2222),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const AppBackButton(color: Colors.black87),
              ),
            ),
            flexibleSpace: const FlexibleSpaceBar(
              background: ShimmerLoading(
                width: double.infinity,
                height: 280,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(width: 200, height: 24),
                  SizedBox(height: 10),
                  ShimmerLoading(width: 120, height: 16),
                  SizedBox(height: 18),
                  ShimmerLoading(width: 160, height: 28),
                  SizedBox(height: 24),
                  ShimmerLoading(width: double.infinity, height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(dynamic product) async {
    final lang = ref.read(appLanguageProvider);

    if (product is Menu && !product.canBeOrdered) {
      if (mounted) {
        Helpers.showWarning(
          context,
          tr.get('menu_unavailable', lang),
          bottomOffset: 12,
          includeBottomPadding: false,
        );
      }
      return;
    }

    if (!AuthGuard.requireLogin(context, ref)) {
      return;
    }

    // Cek jam operasional
    final currentBranch = _activeBranch ?? ref.read(selectedBranchProvider);
    if (currentBranch != null && !currentBranch.isOpenNow) {
      if (mounted) {
        await AppDialog.showAlert(
          context: context,
          title: tr.get('branch_closed_title', lang),
          message: tr.get('branch_closed_message', lang),
          buttonText: tr.get('understand', lang),
          type: AppDialogType.warning,
        );
      }
      return;
    }

    final targetBranchId = _effectiveBranchId(product);
    if (targetBranchId == null) {
      Helpers.showCustomAlert(
        context,
        tr.get('branch_menu_not_found', lang),
        isSuccess: false);
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final canContinue = await _confirmBranchChangeIfNeeded(targetBranchId);
      if (!canContinue) {
        return;
      }

      await _syncSelectedBranch(targetBranchId, product);

      final request = AddToCartRequest(
        branchMenuItemId: product.branchMenuItemId,
        templateCode: (product.templateCode != null && product.templateCode!.isNotEmpty)
            ? product.templateCode
            : product.code,
        menuId: product.id > 0 ? product.id : null,
        quantity: _quantity,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        branchId: targetBranchId);

      await ref.read(cartControllerProvider.notifier).addToCart(request);

      if (mounted) {
        Helpers.showCustomAlert(
          context,
          tr.get('added_to_cart', lang),
          isSuccess: true,
          bottomOffset: 12,
          includeBottomPadding: false,
          action: SnackBarAction(
            label: tr.get('view', lang),
            textColor: Colors.white,
            onPressed: () => context.go('/navigation?index=2'),
          ));

        // Reset quantity and notes
        setState(() {
          _quantity = 1;
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showCustomAlert(
          context,
          '${tr.get('failed_add_to_cart', lang)}: ${e.toString().replaceAll('Exception: ', '')}',
          isSuccess: false,
          bottomOffset: 12,
          includeBottomPadding: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  int? _effectiveBranchId(dynamic product) {
    if (_activeBranch != null) {
      return _activeBranch!.id;
    }
    final fromRoute = int.tryParse(widget.branchId ?? '');
    return fromRoute ?? product.branchesId as int?;
  }

  Future<void> _initActiveBranch(Menu product) async {
    if (_hasInitializedBranch) return;
    _hasInitializedBranch = true;

    try {
      final branches = await ref.read(branchesProvider.future);
      final brandBranches =
          branches.where((b) => b.brandId == product.brandId).toList();
      if (brandBranches.isEmpty) return;

      final routeBranchId = int.tryParse(widget.branchId ?? '');
      Branch? matchedBranch;
      if (routeBranchId != null) {
        matchedBranch = brandBranches.cast<Branch?>().firstWhere(
              (b) => b?.id == routeBranchId,
              orElse: () => null,
            );
      }

      final pos = await ref.read(userPositionProvider.future);
      if (pos != null) {
        final locService = ref.read(locationServiceProvider);
        final sorted =
            await locService.getBranchesByDistance(brandBranches, pos);
        if (!mounted) return;
        if (matchedBranch != null) {
          final found =
              sorted.where((bw) => bw.branch.id == matchedBranch!.id);
          setState(() {
            _activeBranch = matchedBranch;
            _activeBranchDistance =
                found.isNotEmpty ? found.first.distance : null;
          });
        } else if (sorted.isNotEmpty) {
          setState(() {
            _activeBranch = sorted.first.branch;
            _activeBranchDistance = sorted.first.distance;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _activeBranch = matchedBranch ?? brandBranches.first;
        });
      }
    } catch (_) {
      // Fallback silent
    }
  }

  Widget _buildBranchBar(BuildContext context, AppLanguage lang, Menu product) {
    final branch = _activeBranch;
    final isOpen = branch?.isOpenNow ?? true;
    final outletName =
        branch?.outlet ?? product.branchesOutlet ?? (lang == AppLanguage.indonesia ? 'Pilih Outlet' : 'Select Outlet');
    final locationName =
        branch?.location ?? product.branchesLocation ?? '';
    final distanceText = _activeBranchDistance != null
        ? (_activeBranchDistance! < 1
            ? '${(_activeBranchDistance! * 1000).round()} m'
            : '${_activeBranchDistance!.toStringAsFixed(1)} km')
        : null;

    final fullOutletLabel = locationName.isNotEmpty
        ? '$outletName, $locationName'
        : outletName;

    return InkWell(
      onTap: () => _showBranchPickerBottomSheet(context, lang, product),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Status Dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isOpen
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOpen
                  ? (lang == AppLanguage.indonesia ? 'Buka' : 'Open')
                  : (lang == AppLanguage.indonesia ? 'Tutup' : 'Closed'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOpen
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 8),

            // Outlet Name & Location
            Expanded(
              child: Text(
                fullOutletLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Distance
            if (distanceText != null) ...[
              Text(
                distanceText,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Dropdown Chevron
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBranchPickerBottomSheet(
    BuildContext context,
    AppLanguage lang,
    Menu product,
  ) async {
    final branches = await ref.read(branchesProvider.future);
    final brandBranches =
        branches.where((b) => b.brandId == product.brandId).toList();

    if (brandBranches.isEmpty) {
      if (context.mounted) {
        Helpers.showCustomAlert(
          context,
          lang == AppLanguage.indonesia
              ? 'Tidak ada cabang lain untuk brand ini'
              : 'No other branches for this brand',
          isSuccess: false,
          bottomOffset: 12,
          includeBottomPadding: false,
        );
      }
      return;
    }

    final pos = await ref.read(userPositionProvider.future);
    List<BranchWithDistance> sortedBranches = [];
    if (pos != null) {
      final locService = ref.read(locationServiceProvider);
      sortedBranches =
          await locService.getBranchesByDistance(brandBranches, pos);
    } else {
      sortedBranches = brandBranches
          .map((b) => BranchWithDistance(branch: b, distance: double.infinity))
          .toList();
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == AppLanguage.indonesia
                                    ? 'Pilih Cabang Outlet'
                                    : 'Select Branch Outlet',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lang == AppLanguage.indonesia
                                    ? 'Urutan terdekat dari lokasimu saat ini'
                                    : 'Sorted nearest to your current location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Branch List
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.60,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sortedBranches.length,
                        itemBuilder: (context, index) {
                          final item = sortedBranches[index];
                          final branch = item.branch;
                          final isSelected = branch.id ==
                              (_activeBranch?.id ?? product.branchesId);
                          final isOpen = branch.isOpenNow;
                          final showDistance = !item.distance.isInfinite;
                          final isTerdekat = index == 0 && showDistance;

                          return Container(
                            margin: EdgeInsets.only(
                              top: isTerdekat ? 10 : 0,
                              bottom: 14,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 2,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: isSelected
                                        ? const BorderSide(
                                            color: Color(0xFFDD2222), width: 1.8)
                                        : (isTerdekat
                                            ? const BorderSide(
                                                color: Color(0xFFDD2222), width: 1.2)
                                            : BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _activeBranch = branch;
                                        _activeBranchDistance =
                                            item.distance.isInfinite
                                                ? null
                                                : item.distance;
                                      });
                                      Navigator.pop(ctx);
                                      Helpers.showCustomAlert(
                                        context,
                                        lang == AppLanguage.indonesia
                                            ? 'Cabang diubah ke ${branch.outlet}'
                                            : 'Branch changed to ${branch.outlet}',
                                        isSuccess: true,
                                        bottomOffset: 12,
                                        includeBottomPadding: false,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  branch.outlet
                                                      .replaceAll('TOMOKO', 'Tomoko')
                                                      .replaceAll('AH BANG', 'Ah Bang'),
                                                  style: TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected
                                                        ? const Color(0xFFDD2222)
                                                        : const Color(0xFF111827),
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle_rounded
                                                    : Icons.radio_button_unchecked_rounded,
                                                color: isSelected
                                                    ? const Color(0xFFDD2222)
                                                    : Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (branch.address != null &&
                                                    branch.address!.trim().isNotEmpty)
                                                ? branch.address!.trim()
                                                : branch.location,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF334155),
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          // Row: Open Hours & Distance
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 13.5,
                                                color: isOpen
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFDC2626),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isOpen
                                                    ? (lang == AppLanguage.indonesia
                                                        ? 'Buka'
                                                        : 'Open')
                                                    : (lang == AppLanguage.indonesia
                                                        ? 'Tutup'
                                                        : 'Closed'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isOpen
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(0xFFDC2626),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '(${branch.openingHours.length >= 5 ? branch.openingHours.substring(0, 5) : branch.openingHours} - ${branch.closingHours.length >= 5 ? branch.closingHours.substring(0, 5) : branch.closingHours} WIB)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (showDistance) ...[
                                                const SizedBox(width: 6),
                                                const Text('•',
                                                    style: TextStyle(
                                                        color: Color(0xFF94A3B8),
                                                        fontSize: 11)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  item.distance < 1
                                                      ? '${(item.distance * 1000).round()} m'
                                                      : '${item.distance.toStringAsFixed(1)} km',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFFDD2222),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Map Link
                                          InkWell(
                                            onTap: () async {
                                              final addressQuery =
                                                  (branch.address?.isNotEmpty ?? false)
                                                      ? '${branch.outlet}, ${branch.address}'
                                                      : branch.location;
                                              final Uri mapUri = Uri.parse(
                                                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addressQuery)}');
                                              try {
                                                if (await canLaunchUrl(mapUri)) {
                                                  await launchUrl(mapUri,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                }
                                              } catch (_) {}
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.map_outlined,
                                                    size: 14,
                                                    color: Color(0xFF111827),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    tr.get('view_location_on_map',
                                                        lang),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF111827),
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // TERDEKAT badge overlay
                                if (isTerdekat)
                                  Positioned(
                                    top: -10,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDD2222),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        tr.get('nearest', lang),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.normal,
                                          letterSpacing: 0.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _friendlyFavoriteError(Object error) {
    final lang = ref.read(appLanguageProvider);
    final raw = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Failed to toggle favorite: ', '')
        .replaceAll('Failed to add favorite: ', '')
        .trim();

    if (raw.toLowerCase().contains('selected menu id is invalid') ||
        raw.toLowerCase().contains('menu id')) {
      return lang == AppLanguage.indonesia
          ? 'Menu belum bisa ditambahkan. Silakan refresh lalu coba lagi.'
          : 'Menu cannot be added yet. Please refresh and try again.';
    }

    if (raw.isEmpty) {
      return lang == AppLanguage.indonesia
          ? 'Gagal memperbarui favorit.'
          : 'Failed to update favorites.';
    }

    return raw.length > 90 ? '${raw.substring(0, 90)}...' : raw;
  }

  Future<bool> _confirmBranchChangeIfNeeded(int targetBranchId) async {
    final cart = await ref.read(cartProvider.future);
    if (cart.items.isEmpty) {
      return true;
    }

    final cartBranchId = cart.branchId;
    if (cartBranchId == null || cartBranchId == targetBranchId) {
      return true;
    }

    if (!mounted) return false;

    final lang = ref.read(appLanguageProvider);
    final shouldClear = await AppDialog.showConfirm(
      context: context,
      title: tr.get('change_branch_dialog_title', lang),
      message: tr.get('change_branch_dialog_desc', lang),
      confirmText: tr.get('yes_clear_cart', lang),
      cancelText: tr.get('cancel', lang),
      type: AppDialogType.danger,
    );

    if (shouldClear != true) {
      return false;
    }

    await ref.read(cartControllerProvider.notifier).clearCart();
    ref.invalidate(cartProvider);

    if (mounted) {
      Helpers.showCustomAlert(
        context,
        tr.get('cart_cleared', lang),
        isSuccess: true,
        duration: const Duration(seconds: 2),
        bottomOffset: 12,
        includeBottomPadding: false,
      );
    }

    return true;
  }

  Future<void> _syncSelectedBranch(int branchId, dynamic product) async {
    final currentBranch = ref.read(selectedBranchProvider);
    if (currentBranch?.id == branchId) {
      return;
    }

    try {
      final branches = await ref.read(branchesProvider.future);
      final matchingBranches = branches.where((item) => item.id == branchId);
      final branch = matchingBranches.isEmpty ? null : matchingBranches.first;
      if (branch == null) return;

      ref.read(selectedBranchProvider.notifier).state = branch;
      ref.read(selectedBrandProvider.notifier).state = Brand(
        id: branch.brandId,
        name: branch.brandName.isNotEmpty
            ? branch.brandName
            : (product.brandName?.toString() ?? ''),
        logo: branch.brandLogo ?? '',
        service: 0,
        tax: 0,
        category: const []);
    } catch (_) {
      // The cart request still carries branchId even if local branch metadata fails to load.
    }
  }
}
