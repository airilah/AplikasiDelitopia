import 'package:flutter/material.dart';
import '../../../core/utils/brand_name_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/services/service_providers.dart';
import '../../../shared/models/menu_model.dart';
import '../../../shared/models/branch_model.dart';
import '../../../shared/models/product_model.dart' as models;
import '../../../core/widgets/cached_image.dart';
import 'brand_branch_selection_view.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_model.dart';
import '../../../shared/services/location_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/price_display_widget.dart';
import '../../../shared/models/table_session_model.dart';

// Menu key for provider - using string to avoid map reference issues
class MenuKey {
  final String brandId;
  final String branchId;

  const MenuKey(this.brandId, this.branchId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuKey &&
          runtimeType == other.runtimeType &&
          brandId == other.brandId &&
          branchId == other.branchId;

  @override
  int get hashCode => brandId.hashCode ^ branchId.hashCode;
}

// Provider for menus by brand and branch
final menusByBrandBranchProvider =
    FutureProvider.family<List<Menu>, MenuKey>((ref, key) async {
  final menuService = ref.watch(menuServiceProvider);
  return menuService.getMenuByBranchAndBrand(
    type: 'brand',
    data: key.brandId,
    branchId: key.branchId);
});

class MenuView extends ConsumerStatefulWidget {
  final String? brandId;
  final String? branchId;
  final String? categoryId;
  final String? tableNumber;
  final String? zone;

  const MenuView({
    super.key,
    this.brandId,
    this.branchId,
    this.categoryId,
    this.tableNumber,
    this.zone,
  });

  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView> {
  final _searchController = TextEditingController();
  final _categoryScrollController = ScrollController();
  String? _selectedCategory;
  String? _activeBranchId;

  @override
  void initState() {
    super.initState();
    _activeBranchId = widget.branchId;

    if (widget.tableNumber != null && widget.branchId != null) {
      final bId = int.tryParse(widget.branchId!);
      if (bId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(tableSessionProvider.notifier).state = TableSession(
            branchId: bId,
            brandId: widget.brandId != null ? int.tryParse(widget.brandId!) : null,
            tableNumber: widget.tableNumber!,
            zone: widget.zone,
            isLockedFromQr: true,
          );
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant MenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.branchId != oldWidget.branchId && widget.branchId != null) {
      _activeBranchId = widget.branchId;
    }
  }

  void _changeCategory(String category, List<String> categories) {
    setState(() {
      _selectedCategory = category;
    });
    final index = categories.indexOf(category);
    if (index >= 0 && _categoryScrollController.hasClients) {
      const estimatedTabWidth = 110.0;
      final targetOffset = (index * estimatedTabWidth) -
          (MediaQuery.of(context).size.width / 2) +
          (estimatedTabWidth / 2);
      _categoryScrollController.animateTo(
        targetOffset.clamp(
            0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _checkAndClearCartIfNeeded(Menu menu) async {
    final lang = ref.read(appLanguageProvider);

    try {
      final cart = await ref.read(cartProvider.future);

      // If cart is empty, no need to check
      if (cart.items.isEmpty) return;

      final newBranchId = menu.branchesId;
      // Only compare when we have a definitive cart branch_id from the API.
      // If cart.branchId is null we cannot prove a conflict – allow adding.
      final cartBranchId = cart.branchId;
      if (cartBranchId == null ||
          newBranchId == null ||
          cartBranchId == newBranchId) {
        return;
      }

      // Branch mismatch confirmed — ask the user
      if (!mounted) return;
      final shouldClear = await AppDialog.showConfirm(
        context: context,
        title: tr.get('change_branch_dialog_title', lang),
        message: tr.get('change_branch_dialog_desc', lang),
        confirmText: tr.get('yes_clear_cart', lang),
        cancelText: tr.get('cancel', lang),
        type: AppDialogType.danger,
      );

      if (shouldClear == true) {
        await ref.read(cartControllerProvider.notifier).clearCart();
        ref.invalidate(cartProvider);
        if (mounted) {
          Helpers.showWarning(context, tr.get('cart_cleared', lang));
        }
      } else {
        throw Exception('User cancelled');
      }
    } catch (e) {
      rethrow;
    }
  }

  void _addToCart(Menu menu) async {
    final lang = ref.read(appLanguageProvider);
    if (!menu.canBeOrdered) {
      if (mounted) {
        Helpers.showWarning(context, tr.get('menu_unavailable', lang),
            bottomOffset: 62);
      }
      return;
    }

    // Cek jam operasional
    final currentBranch = ref.read(selectedBranchProvider);
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

    final currentUri = GoRouterState.of(context).uri.toString();
    final redirectTo = currentUri == AppRouter.navigation
        ? '${AppRouter.navigation}?index=1'
        : currentUri;
    if (!AuthGuard.requireLogin(context, ref, redirectTo: redirectTo)) {
      return;
    }

    try {
      // Check if cart needs to be cleared due to branch change
      await _checkAndClearCartIfNeeded(menu);

      final request = AddToCartRequest(
        branchMenuItemId: menu.branchMenuItemId,
        templateCode: (menu.templateCode != null && menu.templateCode!.isNotEmpty)
            ? menu.templateCode
            : menu.code,
        menuId: menu.id > 0 ? menu.id : null,
        quantity: 1,
        branchId: menu.branchesId);

      await ref.read(cartControllerProvider.notifier).addToCart(request);

      // Update selectedBranchProvider so product_details_view stays in sync
      if (menu.branchesId != null) {
        final currentSelected = ref.read(selectedBranchProvider);
        if (currentSelected?.id != menu.branchesId) {
          try {
            final branches = await ref.read(branchesProvider.future);
            final matched = branches.where((b) => b.id == menu.branchesId);
            if (matched.isNotEmpty) {
              ref.read(selectedBranchProvider.notifier).state = matched.first;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        Helpers.showCustomAlert(
          context,
          tr.get('menu_added_to_cart', lang).replaceAll('{name}', menu.name),
          isSuccess: true,
          bottomOffset: 62,
          action: SnackBarAction(
            label: tr.get('view', lang).toUpperCase(),
            textColor: Colors.white,
            onPressed: () => context.go('/navigation?index=2'),
          ));
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('User cancelled')) return;
        final cleanMsg = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Failed to add to cart: ', '')
            .trim();
        final displayMsg = cleanMsg.isNotEmpty && !cleanMsg.contains('Instance of')
            ? '${tr.get('failed_add_to_cart', lang)}: $cleanMsg'
            : tr.get('invalid_menu_add_to_cart', lang);
        Helpers.showError(context, displayMsg, bottomOffset: 62);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Map<String, List<Menu>> _groupMenusByCategory(List<Menu> menus) {
    final grouped = <String, List<Menu>>{};

    for (var menu in menus) {
      if (!grouped.containsKey(menu.category)) {
        grouped[menu.category] = [];
      }
      grouped[menu.category]!.add(menu);
    }

    // Urutkan item di setiap kategori agar menu yang memiliki harga promo muncul paling atas
    for (final categoryList in grouped.values) {
      categoryList.sort((a, b) {
        final aPromo = a.hasPromo ? 1 : 0;
        final bPromo = b.hasPromo ? 1 : 0;
        if (aPromo != bPromo) {
          return bPromo.compareTo(aPromo); // promo first
        }
        return 0;
      });
    }

    return grouped;
  }

  List<String> _getSortedCategories(Map<String, List<Menu>> groupedMenus) {
    final categories = groupedMenus.keys.toList();

    // Sort: PROMO first, then alphabetically
    categories.sort((a, b) {
      if (a.toUpperCase().contains('PROMO')) return -1;
      if (b.toUpperCase().contains('PROMO')) return 1;
      return a.compareTo(b);
    });

    return categories;
  }

  List<Menu> _filterMenusBySearch(List<Menu> menus) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return menus;

    return menus
        .where((m) =>
            m.name.toLowerCase().contains(query) ||
            m.description.toLowerCase().contains(query) ||
            m.category.toLowerCase().contains(query))
        .toList();
  }

  Branch? _resolveSelectedBranch(
      Branch? selectedBranch, List<Branch>? branches, [String? targetBranchId]) {
    final searchId = targetBranchId ?? _activeBranchId ?? widget.branchId;
    if (selectedBranch != null &&
        selectedBranch.id.toString() == searchId) {
      return selectedBranch;
    }

    if (branches == null || branches.isEmpty) return selectedBranch;

    for (final branch in branches) {
      if (branch.id.toString() == searchId) {
        return branch;
      }
    }

    return selectedBranch ?? branches.first;
  }

  String _resolveActiveCategory(List<String> categories) {
    if (_selectedCategory != null && categories.contains(_selectedCategory)) {
      return _selectedCategory!;
    }

    if (widget.categoryId != null) {
      for (final category in categories) {
        if (category.toLowerCase() == widget.categoryId!.toLowerCase()) {
          return category;
        }
      }
    }

    return categories.first;
  }

  String _formatDistanceKm(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    // Check if brand and branch are selected
    if (widget.brandId == null || widget.branchId == null) {
      return BackButtonWrapper(
        backRoute: '${AppRouter.navigation}?index=0',
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'MENU',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: const Color(0xFFDD2222),
            foregroundColor: Colors.white,
          ),
          body: _buildThreeTabsMenuView(lang),
        ),
      );
    }

    final effectiveBranchId = _activeBranchId ?? widget.branchId!;
    final selectedBranch = ref.watch(selectedBranchProvider);

    final menusAsync = ref.watch(menusByBrandBranchProvider(
      MenuKey(widget.brandId!, effectiveBranchId),
    ));

    return BackButtonWrapper(
      backRoute: '/brand-branch-selection',
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: menusAsync.when(
          data: (menus) {
            if (menus.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(tr.get('no_menu_items', lang)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.refresh(menusByBrandBranchProvider(
                        MenuKey(widget.brandId!, effectiveBranchId),
                      )),
                      child: Text(tr.get('refresh', lang)),
                    ),
                  ],
                ),
              );
            }

            if (menus.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  AppImageCache.precacheMultiple(
                    context,
                    menus.map((m) => m.photo),
                    limit: 15,
                  );
                }
              });
            }

            final filteredMenus = _filterMenusBySearch(menus);
            final groupedMenus = _groupMenusByCategory(filteredMenus);
            final sortedCategories = _getSortedCategories(groupedMenus);

            // Remove empty categories (e.g., PROMO if no promo items)
            final nonEmptyCategories = sortedCategories
                .where((cat) => groupedMenus[cat]?.isNotEmpty ?? false)
                .toList();
            final selectedCategory = filteredMenus.isEmpty
                ? null
                : _resolveActiveCategory(nonEmptyCategories);
            final visibleMenus = selectedCategory == null
                ? <Menu>[]
                : groupedMenus[selectedCategory] ?? <Menu>[];
            final branchesAsync =
                ref.watch(branchesByBrandProvider(widget.brandId!));
            final branches = branchesAsync.maybeWhen(
              data: (value) => value,
              orElse: () => null);
            final branch = _resolveSelectedBranch(selectedBranch, branches, effectiveBranchId);
            final positionAsync = ref.watch(userPositionProvider);
            final distanceLabel = positionAsync.maybeWhen(
              data: (position) {
                if (position == null ||
                    branch == null ||
                    branch.latitude == 0 ||
                    branch.longitude == 0) {
                  return null;
                }

                final locationService = ref.read(locationServiceProvider);
                final distanceKm = locationService.calculateDistance(
                  position.latitude,
                  position.longitude,
                  branch.latitude,
                  branch.longitude);

                return _formatDistanceKm(distanceKm);
              },
              loading: () => branch == null ? null : 'Menghitung jarak...',
              orElse: () => null);
            final brandName =
                branch?.brandName ?? (menus.isNotEmpty ? menus.first.brandName : null) ?? 'Menu';

            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if (selectedCategory == null ||
                        nonEmptyCategories.length <= 1) {
                      return;
                    }
                    final velocity = details.primaryVelocity ?? 0;
                    final currentIndex =
                        nonEmptyCategories.indexOf(selectedCategory);
                    if (velocity < -200) {
                      // Geser ke kiri -> pindah ke kategori sebelah kanan
                      if (currentIndex < nonEmptyCategories.length - 1) {
                        _changeCategory(
                          nonEmptyCategories[currentIndex + 1],
                          nonEmptyCategories,
                        );
                      }
                    } else if (velocity > 200) {
                      // Geser ke kanan -> pindah ke kategori sebelah kiri
                      if (currentIndex > 0) {
                        _changeCategory(
                          nonEmptyCategories[currentIndex - 1],
                          nonEmptyCategories,
                        );
                      }
                    }
                  },
                  child: RefreshIndicator(
                    color: const Color(0xFFDD2222),
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      ref.invalidate(menusByBrandBranchProvider(
                        MenuKey(widget.brandId!, effectiveBranchId),
                      ));
                      try {
                        await ref.read(menusByBrandBranchProvider(
                          MenuKey(widget.brandId!, effectiveBranchId),
                        ).future);
                      } catch (_) {}
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      slivers: [
                        _buildMenuHeader(),

                        SliverToBoxAdapter(
                          child: _buildOutletInfoCard(
                              brandName, branch, distanceLabel, branches, menus),
                        ),

                        // Table Session Banner
                        Consumer(
                          builder: (context, ref, _) {
                            final session = ref.watch(tableSessionProvider);
                            if (session != null &&
                                session.tableNumber.isNotEmpty &&
                                (session.branchId.toString() == effectiveBranchId ||
                                    effectiveBranchId.isEmpty)) {
                              return SliverToBoxAdapter(
                                child: _buildTableSessionBanner(session, lang),
                              );
                            }
                            return const SliverToBoxAdapter(child: SizedBox.shrink());
                          },
                        ),

                        // Search Bar
                        SliverToBoxAdapter(
                          child: _buildSearchBar(),
                        ),

                        // Menu Items by Category
                        if (filteredMenus.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    tr.get('no_items_found', lang),
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          SliverToBoxAdapter(
                            child: _buildCategoryTabs(
                              nonEmptyCategories,
                              selectedCategory!,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 10),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildMenuItemRow(visibleMenus[index]),
                              childCount: visibleMenus.length,
                            ),
                          ),
                        ],

                        // Bottom padding for floating cart button
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 80),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Cart Button (Gojek style)
                Consumer(
                  builder: (context, ref, child) {
                    if (!AuthGuard.isAuthenticated(ref)) {
                      return const SizedBox.shrink();
                    }

                    final cartAsync = ref.watch(cartProvider);

                    return cartAsync.when(
                      data: (cart) {
                        if (cart.itemCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          bottom: 16 + MediaQuery.of(context).padding.bottom,
                          left: 14,
                          right: 14,
                          child: Material(
                            elevation: 10,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () {
                                if (!AuthGuard.requireLogin(
                                  context,
                                  ref,
                                  redirectTo: AppRouter.cart,
                                )) {
                                  return;
                                }

                                context.go(AppRouter.cart);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFDD2222),
                                      Color(0xFFB91111)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    // Shopping bag icon with badge
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.shopping_bag_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            constraints: const BoxConstraints(
                                                minWidth: 16, minHeight: 16),
                                            child: Center(
                                              child: Text(
                                                '${cart.itemCount}',
                                                style: const TextStyle(
                                                  color: Color(0xFFDD2222),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Item count & Total Price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${cart.itemCount} ${lang == AppLanguage.indonesia ? 'barang' : 'items'}',
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withValues(alpha: 0.9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Rp ${cart.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Button "Lihat Keranjang"
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tr.get('view_cart', ref.watch(appLanguageProvider)),
                                            style: const TextStyle(
                                              color: Color(0xFFDD2222),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFFDD2222),
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ));
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink());
                  },
                ),
              ]);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    ErrorHandler.getUserFriendlyMessage(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => ref.refresh(menusByBrandBranchProvider(
                      MenuKey(widget.brandId!, effectiveBranchId),
                    )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(tr.get('retry', lang)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
  }

  Widget _buildTableSessionBanner(TableSession session, AppLanguage lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      lang == AppLanguage.indonesia
                          ? 'Dine In Meja ${session.tableNumber}'
                          : 'Dine In Table ${session.tableNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    if (session.zone != null && session.zone!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          session.zone!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tr.get('table_session_banner_desc', lang),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              ref.read(tableSessionProvider.notifier).state = null;
              context.push(AppRouter.qrScanner);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeTabsMenuView(AppLanguage lang) {
    final showcaseAsync = ref.watch(
      showcaseProductsProvider(
        const ShowcaseProductsRequest(newLimit: 15, popularLimit: 15, limit: 30),
      ),
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Global Search Bar di atas Rekomendasi
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InkWell(
              onTap: () => context.push(AppRouter.search),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFDD2222),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang == AppLanguage.indonesia
                            ? 'Cari menu atau outlet favorit...'
                            : 'Search favorite menu or outlet...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pinned Tab Bar Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: const Color(0xFFDD2222),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    text: lang == AppLanguage.indonesia
                        ? 'Rekomendasi'
                        : 'Recommended',
                  ),
                  Tab(
                    text: lang == AppLanguage.indonesia
                        ? 'Terlaris'
                        : 'Best Seller',
                  ),
                  Tab(
                    text: lang == AppLanguage.indonesia
                        ? 'Top Rating'
                        : 'Top Rated',
                  ),
                ],
              ),
            ),
          ),

          // TabBarView Content
          Expanded(
            child: showcaseAsync.when(
              data: (showcase) {
                return TabBarView(
                  children: [
                    _buildProductTabContent(
                      products: showcase.recommendedMenus,
                      fallback: showcase.popularMenus,
                      tabType: 'recommended',
                      lang: lang,
                    ),
                    _buildProductTabContent(
                      products: showcase.bestSellerMenus,
                      fallback: showcase.popularMenus,
                      tabType: 'best_seller',
                      lang: lang,
                    ),
                    _buildProductTabContent(
                      products: showcase.topRatedMenus,
                      fallback: showcase.popularMenus,
                      tabType: 'top_rated',
                      lang: lang,
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFDD2222)),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      lang == AppLanguage.indonesia
                          ? 'Gagal memuat menu'
                          : 'Failed to load menu',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.refresh(
                        showcaseProductsProvider(
                          const ShowcaseProductsRequest(
                              newLimit: 15, popularLimit: 15, limit: 30),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD2222),
                      ),
                      child: Text(
                        lang == AppLanguage.indonesia ? 'Coba Lagi' : 'Retry',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTabContent({
    required List<models.Product> products,
    required List<models.Product> fallback,
    required String tabType,
    required AppLanguage lang,
  }) {
    final rawList = products.isNotEmpty ? products : fallback;
    final List<models.Product> list = List.from(rawList);

    // Di tab Rekomendasi, pastikan menu dengan label Menu Baru dan Populer selalu muncul teratas
    if (tabType == 'recommended') {
      list.sort((a, b) {
        final aPriority = (a.isNew ? 2 : (a.isPopular ? 1 : 0));
        final bPriority = (b.isNew ? 2 : (b.isPopular ? 1 : 0));
        if (aPriority != bPriority) {
          return bPriority.compareTo(aPriority);
        }
        return 0; // pertahankan urutan relatif
      });
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu_rounded,
                size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Belum ada menu di kategori ini'
                  : 'No menus in this category yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFDD2222),
      backgroundColor: Colors.white,
      onRefresh: () async {
        ref.invalidate(showcaseProductsProvider(
          const ShowcaseProductsRequest(
              newLimit: 15, popularLimit: 15, limit: 30),
        ));
      },
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: _computeCardAspectRatio(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final product = list[index];
          return _buildSmartMenuProductCard(product, tabType, lang);
        },
      ),
    );
  }

  double _computeCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    if (textScale >= 1.2 || width < 360) {
      return 0.60;
    } else if (textScale > 1.05 || width <= 375) {
      return 0.62;
    }
    return 0.64;
  }

  Widget _buildSmartMenuProductCard(
    models.Product product,
    String tabType,
    AppLanguage lang,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () async {
          int? targetBranchId = product.branchId;
          final nearestBranch = ref
              .read(nearestBranchForBrandProvider(product.brandId))
              .valueOrNull;
          if (nearestBranch != null) {
            targetBranchId = nearestBranch.id;
          } else {
            final asyncBranch = await ref.read(
                nearestBranchForBrandProvider(product.brandId).future);
            if (asyncBranch != null) targetBranchId = asyncBranch.id;
          }

          if (mounted) {
            context.push(
              targetBranchId == null
                  ? '/product/${product.id}'
                  : '/product/${product.id}?branchId=$targetBranchId',
            );
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo with optional Badge (Menu Baru & Populer)
              AspectRatio(
                aspectRatio: 1.2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedImage(
                      imageUrl: product.image ?? '',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      heroTag: 'product_photo_${product.id}_$tabType',
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      errorWidget: Container(
                        color: const Color(0xFFFFF1F1),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            color: Color(0xFFDD2222),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    if (product.isNew)
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
                                tr.get('new', lang),
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
                    else if (product.isPopular)
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
                                tr.get('popular_badge', lang),
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

              // Details - Rapat tanpa space kosong
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((product.brandName ?? '').isNotEmpty) ...[
                      Text(
                        formatBrandName(product.brandName!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Rating & Sold
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating > 0
                              ? product.rating.toStringAsFixed(1)
                              : '5.0',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('•',
                            style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.formattedSoldFor(lang),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Alamat Outlet (2 Baris) - Tidak akan hilang walau sinyal lambat
                    Consumer(
                      builder: (context, ref, _) {
                        final nearestBranch = ref
                            .watch(nearestBranchForBrandProvider(product.brandId))
                            .valueOrNull;
                        final allBranches =
                            ref.watch(branchesProvider).valueOrNull;
                        final fallbackBranch = allBranches
                            ?.where((b) => b.brandId == product.brandId)
                            .firstOrNull;

                        final addressText = (nearestBranch != null &&
                                nearestBranch.displayAddress.trim().isNotEmpty)
                            ? nearestBranch.displayAddress.trim()
                            : (fallbackBranch != null &&
                                    fallbackBranch.displayAddress.trim().isNotEmpty)
                                ? fallbackBranch.displayAddress.trim()
                                : (product.branchAddress ??
                                    (product.branchesLocation ?? ''));

                        if (addressText.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 11,
                                color: Color(0xFFDD2222),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                addressText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF475569),
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    // Price - Rapat langsung di bawah alamat
                    PriceDisplayWidget.fromProduct(
                      product: product,
                      fontSize: 15,
                      priceColor: const Color(0xFFDD2222),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    final lang = ref.watch(appLanguageProvider);
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFDD2222),
      foregroundColor: Colors.white,
      leading: const AppBackButton(
        backRoute: '/brand-branch-selection',
        color: Colors.white,
      ),
      centerTitle: true,
      title: Text(
        tr.get('nav_menu', lang).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ));
  }

  Future<void> _showBranchPickerModal(
    BuildContext context,
    List<Branch>? branches,
    Branch? currentBranch,
  ) async {
    final lang = ref.read(appLanguageProvider);
    final brandId = widget.brandId;
    if (brandId == null) return;

    List<Branch> brandBranches = branches ?? [];
    if (brandBranches.isEmpty) {
      try {
        final loaded = await ref.read(branchesByBrandProvider(brandId).future);
        brandBranches = loaded;
      } catch (_) {}
    }

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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      final b = item.branch;
                      final isSelected = b.id.toString() ==
                          (_activeBranchId ?? currentBranch?.id.toString() ?? widget.branchId);
                      final isOpen = b.isOpenNow;
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
                                    _activeBranchId = b.id.toString();
                                  });
                                  ref.read(selectedBranchProvider.notifier).state = b;
                                  Navigator.pop(ctx);
                                  Helpers.showCustomAlert(
                                    context,
                                    lang == AppLanguage.indonesia
                                        ? 'Outlet diubah ke ${b.outlet}'
                                        : 'Outlet changed to ${b.outlet}',
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
                                              b.outlet
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
                                        (b.address != null &&
                                                b.address!.trim().isNotEmpty)
                                            ? b.address!.trim()
                                            : b.location,
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
                                              '(${b.openingHours.length >= 5 ? b.openingHours.substring(0, 5) : b.openingHours} - ${b.closingHours.length >= 5 ? b.closingHours.substring(0, 5) : b.closingHours} WIB)',
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
                                              (b.address?.isNotEmpty ?? false)
                                                  ? '${b.outlet}, ${b.address}'
                                                  : b.location;
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
                                    borderRadius: BorderRadius.circular(20),
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
  }

  Widget _buildOutletInfoCard(
    String brandName,
    Branch? branch,
    String? distanceLabel,
    List<Branch>? branches,
    List<Menu> menus,
  ) {
    final lang = ref.watch(appLanguageProvider);
    final isOpen = branch?.isOpenNow ?? true;

    // Calculate aggregated outlet rating from menu reviews
    double totalRatingSum = 0;
    int totalReviewsCount = 0;
    for (final m in menus) {
      if (m.reviewCount > 0 && m.averageRating > 0) {
        totalRatingSum += m.averageRating * m.reviewCount;
        totalReviewsCount += m.reviewCount;
      }
    }
    final double outletAvgRating = totalReviewsCount > 0
        ? (totalRatingSum / totalReviewsCount)
        : 4.8;
    final String outletRatingStr = outletAvgRating.toStringAsFixed(1);
    final String outletReviewsStr = totalReviewsCount >= 1000
        ? '${(totalReviewsCount / 1000).toStringAsFixed(1)}k+'
        : (totalReviewsCount > 0 ? '$totalReviewsCount+' : '1.2k+');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Branch Logo
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: branch?.brandLogo != null && branch!.brandLogo!.isNotEmpty
                  ? CachedImage(
                      imageUrl: branch.brandLogo!,
                      fit: BoxFit.contain,
                      errorWidget: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        color: Color(0xFFDD2222),
                        size: 34,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Outlet Info, Rating & Distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand name + Closed badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        brandName,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isOpen) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr.get('closed_status', lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: () => _showBranchPickerModal(context, branches, branch),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          branch?.outlet ?? (lang == AppLanguage.indonesia ? 'Pilih outlet' : 'Select outlet'),
                          style: const TextStyle(
                            color: Color(0xFFDD2222),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black87,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Rating & Distance Row
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      outletRatingStr,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '($outletReviewsStr ${lang == AppLanguage.indonesia ? 'ulasan' : 'reviews'})',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (distanceLabel != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.near_me_rounded,
                        size: 12,
                        color: Color(0xFFDD2222),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          distanceLabel,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 11.5,
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isOpen && branch != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${lang == AppLanguage.indonesia ? 'Buka' : 'Open'} ${branch.openingHours.length >= 5 ? branch.openingHours.substring(0, 5) : branch.openingHours} – ${branch.closingHours.length >= 5 ? branch.closingHours.substring(0, 5) : branch.closingHours} WIB',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ));
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: tr.get('search_menu', ref.watch(appLanguageProvider)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFDD2222)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ));
  }

  Widget _buildCategoryTabs(List<String> categories, String selectedCategory) {
    return Container(
      height: 52,
      color: const Color(0xFFDD2222),
      child: ListView.separated(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return InkWell(
            onTap: () => _changeCategory(category, categories),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    category,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isSelected ? 28 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ));
        },
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemCount: categories.length,
      ));
  }

  Widget _buildMenuItemRow(Menu menu) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(
            '/product/${menu.id}?branchId=${menu.branchesId ?? (_activeBranchId ?? widget.branchId)}',
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey[200],
                    child: Stack(
                      children: [
                        CachedImage(
                          imageUrl: menu.photo,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          heroTag: 'product_photo_${menu.id}',
                          errorWidget: Image.asset(
                            'assets/images/logo.png',
                            width: 90,
                            height: 90,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.fastfood,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        if (menu.isPopular)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDD2222),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    tr.get('popular_badge',
                                        ref.watch(appLanguageProvider)),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
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
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (menu.averageRating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              menu.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (menu.reviewCount > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                '(${menu.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                            const SizedBox(width: 5),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              menu.formattedSoldFor(ref.watch(appLanguageProvider)),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PriceDisplayWidget.fromMenu(
                              menu: menu,
                              fontSize: 16,
                              priceColor: const Color(0xFFDD2222),
                              showBadge: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          menu.canBeOrdered
                              ? Material(
                                  color: const Color(0xFFDD2222),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () {
                                      _addToCart(menu);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[350]!),
                                  ),
                                  child: Text(
                                    menu.unavailableLabelFor(
                                        ref.watch(appLanguageProvider)),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.normal,
                                      fontSize: 12,
                                    ),
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
        ),
      ));
  }
}
