import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/widgets/app_maintenance_dialog.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_model.dart';
import '../../menu/views/brand_branch_selection_view.dart';
import '../../../shared/models/brand_model.dart';
import '../../../shared/models/branch_model.dart';
import '../../../shared/models/menu_model.dart';
import '../../../shared/widgets/price_display_widget.dart';
import '../../../shared/services/service_providers.dart'
    show branchesProvider, menuServiceProvider;

/// Provider untuk mengambil dan mencache menu cabang aktif pada keranjang
final cartBranchMenusProvider =
    FutureProvider.family<List<Menu>, int>((ref, branchId) async {
  final service = ref.watch(menuServiceProvider);
  return service.getMenuByBranchAndBrand(
    type: 'brand',
    data: 'all',
    branchId: branchId.toString(),
  );
});

class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  final Set<int> _pendingDeletedItemIds = {};
  final Map<int, Timer> _pendingDeletionTimers = {};
  Timer? _clearCartTimer;
  bool _isCartClearPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appMaintenanceProvider.notifier).fetchMaintenance();
    });
  }

  @override
  void dispose() {
    if (_isCartClearPending) {
      _clearCartTimer?.cancel();
      ref.read(cartControllerProvider.notifier).clearCart();
    } else {
      for (final entry in _pendingDeletionTimers.entries) {
        entry.value.cancel();
        ref.read(cartControllerProvider.notifier).removeItem(entry.key);
      }
    }
    super.dispose();
  }

  void _flushPendingDeletes() {
    if (_isCartClearPending) {
      _clearCartTimer?.cancel();
      _isCartClearPending = false;
      ref.read(cartControllerProvider.notifier).clearCart();
    } else {
      for (final entry in _pendingDeletionTimers.entries) {
        entry.value.cancel();
        ref.read(cartControllerProvider.notifier).removeItem(entry.key);
      }
      _pendingDeletionTimers.clear();
      _pendingDeletedItemIds.clear();
    }
  }

  void _deleteCartItem(CartItem item) {
    setState(() {
      _pendingDeletedItemIds.add(item.id);
    });

    final lang = ref.read(appLanguageProvider);
    var isUndone = false;

    final timer = Timer(const Duration(seconds: 3), () {
      if (!isUndone) {
        ref.read(cartControllerProvider.notifier).removeItem(item.id);
        _pendingDeletionTimers.remove(item.id);
        if (mounted) {
          setState(() {
            _pendingDeletedItemIds.remove(item.id);
          });
        }
      }
    });

    _pendingDeletionTimers[item.id] = timer;

    Helpers.showCustomAlert(
      context,
      lang == AppLanguage.indonesia
          ? '${item.menuName} dihapus dari keranjang'
          : '${item.menuName} removed from cart',
      isSuccess: true,
      duration: const Duration(seconds: 3),
      bottomOffset: 12,
      includeBottomPadding: false,
      action: SnackBarAction(
        label: lang == AppLanguage.indonesia ? 'Urungkan' : 'Undo',
        onPressed: () {
          isUndone = true;
          timer.cancel();
          _pendingDeletionTimers.remove(item.id);
          if (mounted) {
            setState(() {
              _pendingDeletedItemIds.remove(item.id);
            });
          }
        },
      ),
    );
  }

  void _clearCart(Cart cart) {
    setState(() {
      _isCartClearPending = true;
    });

    final lang = ref.read(appLanguageProvider);
    var isUndone = false;

    _clearCartTimer = Timer(const Duration(seconds: 3), () {
      if (!isUndone) {
        ref.read(cartControllerProvider.notifier).clearCart();
        if (mounted) {
          setState(() {
            _isCartClearPending = false;
          });
        }
      }
    });

    Helpers.showCustomAlert(
      context,
      lang == AppLanguage.indonesia
          ? 'Semua item dihapus dari keranjang'
          : 'All items removed from cart',
      isSuccess: true,
      duration: const Duration(seconds: 3),
      bottomOffset: 12,
      includeBottomPadding: false,
      action: SnackBarAction(
        label: lang == AppLanguage.indonesia ? 'Urungkan' : 'Undo',
        onPressed: () {
          isUndone = true;
          _clearCartTimer?.cancel();
          if (mounted) {
            setState(() {
              _isCartClearPending = false;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=2',
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr.get('cart_title', lang)),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final cart = cartAsync.valueOrNull;
                if (cart == null || cart.items.isEmpty) return;

                final confirmed = await Helpers.showConfirmDialog(
                  context,
                  title: tr.get('clear_cart_title', lang),
                  message: tr.get('clear_cart_confirm', lang),
                  confirmText: tr.get('delete_all', lang),
                  cancelText: tr.get('cancel', lang),
                  isDanger: true,
                  icon: Icons.delete_outline_rounded,
                );

                if (confirmed) {
                  _clearCart(cart);
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: const Color(0xFFDD2222),
          backgroundColor: Colors.white,
          onRefresh: () => ref.refresh(cartProvider.future),
          child: cartAsync.when(
            data: (cart) {
              final visibleItems = _isCartClearPending
                  ? <CartItem>[]
                  : cart.items
                      .where((it) => !_pendingDeletedItemIds.contains(it.id))
                      .toList();

              if (visibleItems.isEmpty) {
                return _buildEmptyCart(context, lang);
              }

              final displayCart = cart.copyWith(items: visibleItems);

              return Column(
                children: [
                  _buildBranchHeaderCard(context, ref, displayCart, lang),
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return _SwipeableCartItemCard(
                          key: ValueKey(item.id),
                          onDelete: () => _deleteCartItem(item),
                          deleteLabel: tr.get('delete', lang),
                          child: _buildCartItem(
                              context, ref, displayCart, item, lang),
                        );
                      },
                    ),
                  ),
                  _buildOrderSummary(context, ref, displayCart, lang),
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
                    onPressed: () => ref.refresh(cartProvider),
                    child: Text(tr.get('try_again', lang)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchHeaderCard(
      BuildContext context, WidgetRef ref, Cart cart, AppLanguage lang) {
    final selectedBrand = ref.watch(selectedBrandProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    final brandName = cart.brandName ?? selectedBrand?.name;
    final branchName = cart.branchName ?? selectedBranch?.outlet;

    if (brandName == null && branchName == null) {
      return const SizedBox.shrink();
    }

    // Determine if branch is open/closed
    final branchesAsync = ref.watch(branchesProvider);
    final Branch? activeBranch = branchesAsync.when(
      data: (branches) {
        final matches = branches.where((b) => b.id == cart.branchId);
        return matches.isNotEmpty ? matches.first : selectedBranch;
      },
      loading: () => selectedBranch,
      error: (_, __) => selectedBranch,
    );

    final bool isOpen = activeBranch?.isOpenNow ?? true;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: isOpen ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen
              ? const Color(0xFFDD2222).withValues(alpha: 0.15)
              : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isOpen ? 0.03 : 0.01),
            blurRadius: isOpen ? 6 : 4,
            offset: Offset(0, isOpen ? 2 : 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            try {
              final branches = await ref.read(branchesProvider.future);
              final matched = branches.where((b) => b.id == cart.branchId);
              if (matched.isNotEmpty) {
                final branch = matched.first;
                ref.read(selectedBranchProvider.notifier).state = branch;
                ref.read(selectedBrandProvider.notifier).state = Brand(
                  id: branch.brandId,
                  name: branch.brandName,
                  logo: branch.brandLogo ?? '',
                  service: 0,
                  tax: 0,
                  category: const [],
                );
                if (context.mounted) {
                  context.go('/menu?brandId=${branch.brandId}&branchId=${branch.id}');
                }
              }
            } catch (_) {}
          },
          child: Opacity(
            opacity: isOpen ? 1.0 : 0.6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFDD2222).withValues(alpha: 0.08)
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: isOpen ? const Color(0xFFDD2222) : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              brandName?.toUpperCase() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isOpen
                                      ? Colors.green[200]!
                                      : Colors.red[200]!,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                isOpen
                                    ? tr.get('open_status', lang).toUpperCase()
                                    : tr.get('closed_status', lang).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          branchName ?? tr.get('main_branch', lang),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, AppLanguage lang) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 120, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  tr.get('empty_cart_title', lang),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr.get('empty_cart_subtitle', lang),
                  style: TextStyle(color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('${AppRouter.navigation}?index=1'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    tr.get('browse_menu', lang),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, Cart cart,
      CartItem item, AppLanguage lang) {
    // 1. Lookup data promo dari cache menu cabang jika belum ada di item
    final branchMenusAsync = cart.branchId != null
        ? ref.watch(cartBranchMenusProvider(cart.branchId!))
        : null;
    final branchMenus = branchMenusAsync?.valueOrNull ?? const <Menu>[];

    Menu? matchedMenu;
    if (branchMenus.isNotEmpty) {
      matchedMenu = branchMenus.cast<Menu?>().firstWhere(
        (m) =>
            (item.menuTemplateId != null &&
                m?.menuTemplateId == item.menuTemplateId) ||
            (item.menuId > 0 && m?.id == item.menuId) ||
            (item.branchMenuItemId != null &&
                m?.branchMenuItemId == item.branchMenuItemId) ||
            (item.templateCode != null &&
                item.templateCode!.isNotEmpty &&
                m?.templateCode == item.templateCode) ||
            (item.menuCode != null &&
                item.menuCode!.isNotEmpty &&
                m?.code == item.menuCode) ||
            (m != null &&
                m.name.trim().toLowerCase() ==
                    item.menuName.trim().toLowerCase()),
        orElse: () => null,
      );
    }

    final hasPromo = item.hasPromo || (matchedMenu?.hasPromo ?? false);
    final effectivePrice =
        item.price > 0 ? item.price : (matchedMenu?.displayPromoPrice ?? matchedMenu?.price ?? 0.0);
    final originalPrice = item.originalPrice ??
        matchedMenu?.displayOriginalPrice ??
        matchedMenu?.basePrice;
    final discountPercent =
        item.discountPercentage ?? matchedMenu?.discountPercentage;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          // 1. Simpan dan sinkronisasi branch yang sesuai dengan keranjang
          if (cart.branchId != null) {
            try {
              final branches = await ref.read(branchesProvider.future);
              final matched = branches.where((b) => b.id == cart.branchId);
              if (matched.isNotEmpty) {
                final branch = matched.first;
                ref.read(selectedBranchProvider.notifier).state = branch;
                ref.read(selectedBrandProvider.notifier).state = Brand(
                  id: branch.brandId,
                  name: branch.brandName,
                  logo: branch.brandLogo ?? '',
                  service: 0,
                  tax: 0,
                  category: const [],
                );
              }
            } catch (_) {}
          }

          if (!context.mounted) return;

          // 2. Tentukan target menu ID
          int targetId = item.targetMenuId;
          if (targetId <= 0 && matchedMenu != null && matchedMenu.id > 0) {
            targetId = matchedMenu.id;
          }

          // 3. Fallback cerdas jika item belum memiliki targetId valid
          if (targetId <= 0 && cart.branchId != null) {
            try {
              final menuService = ref.read(menuServiceProvider);
              final menus = await menuService.getMenuByBranchAndBrand(
                type: 'brand',
                data: 'all',
                branchId: cart.branchId.toString(),
              );
              final matched = menus.where((m) =>
                (item.templateCode != null &&
                    item.templateCode!.isNotEmpty &&
                    m.templateCode == item.templateCode) ||
                (item.menuCode != null &&
                    item.menuCode!.isNotEmpty &&
                    m.code == item.menuCode) ||
                (item.branchMenuItemId != null &&
                    item.branchMenuItemId! > 0 &&
                    m.branchMenuItemId == item.branchMenuItemId) ||
                m.name.trim().toLowerCase() == item.menuName.trim().toLowerCase(),
              );
              if (matched.isNotEmpty) {
                targetId = matched.first.id;
              }
            } catch (_) {}
          }

          if (!context.mounted) return;

          if (targetId > 0) {
            final branchQuery =
                cart.branchId != null ? '?branchId=${cart.branchId}' : '';
            context.push('/product/$targetId$branchQuery');
          } else {
            Helpers.showWarning(
              context,
              lang == AppLanguage.indonesia
                  ? 'Detail menu tidak tersedia saat ini'
                  : 'Menu details unavailable at this time',
              bottomOffset: 12,
              includeBottomPadding: false,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                imageUrl: item.menuImage ?? '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.menuName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    Text(
                      item.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  PriceDisplayWidget(
                    priceText: 'Rp ${Helpers.formatNumber(effectivePrice)}',
                    originalPriceText: (hasPromo &&
                            originalPrice != null &&
                            originalPrice > effectivePrice)
                        ? 'Rp ${Helpers.formatNumber(originalPrice)}'
                        : null,
                    hasPromo: hasPromo &&
                        originalPrice != null &&
                        originalPrice > effectivePrice,
                    discountPercentage: discountPercent,
                    fontSize: 14,
                    priceColor: const Color(0xFFDD2222),
                    showBadge: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Quantity Controls
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  ref
                                      .read(cartControllerProvider.notifier)
                                      .decrementItem(item.id, item.quantity);
                                } else {
                                  _deleteCartItem(item);
                                }
                              },
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(5),
                                bottomLeft: Radius.circular(5),
                              ),
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: Icon(Icons.remove,
                                    size: 14, color: Colors.black87),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 24),
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                ref
                                    .read(cartControllerProvider.notifier)
                                    .incrementItem(item.id, item.quantity);
                              },
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(5),
                                bottomRight: Radius.circular(5),
                              ),
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: Icon(Icons.add,
                                    size: 14, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          try {
                            final branches =
                                await ref.read(branchesProvider.future);
                            final matched =
                                branches.where((b) => b.id == cart.branchId);
                            if (matched.isNotEmpty) {
                              final branch = matched.first;
                              ref
                                    .read(selectedBranchProvider.notifier)
                                    .state = branch;
                              ref
                                  .read(selectedBrandProvider.notifier)
                                  .state = Brand(
                                id: branch.brandId,
                                name: branch.brandName,
                                logo: branch.brandLogo ?? '',
                                service: 0,
                                tax: 0,
                                category: const [],
                              );
                              if (context.mounted) {
                                context.go(
                                    '/menu?brandId=${branch.brandId}&branchId=${branch.id}');
                              }
                            }
                          } catch (_) {}
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          tr.get('add', lang),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDD2222),
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
  );
  }

  Widget _buildOrderSummary(
      BuildContext context, WidgetRef ref, Cart cart, AppLanguage lang) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(tr.get('subtotal', lang), cart.subtotal),
          _buildSummaryRow(tr.get('tax', lang), cart.tax),
          _buildSummaryRow(tr.get('service', lang), cart.service),
          const Divider(height: 10, thickness: 1),
          _buildSummaryRow(tr.get('total', lang), cart.total, isTotal: true),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final maintenance = ref.watch(appMaintenanceProvider);
            final isMaintenance = maintenance?.isActive == true;

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cart.items.isEmpty
                    ? null
                    : (isMaintenance
                        ? () async {
                            // Verifikasi ulang realtime ke server sebelum memblokir
                            await ref.read(appMaintenanceProvider.notifier).fetchMaintenance();
                            final updated = ref.read(appMaintenanceProvider);
                            if (updated?.isActive == true) {
                              if (context.mounted) {
                                AppMaintenanceDialog.show(context, maintenance: updated!);
                              }
                            } else {
                              _flushPendingDeletes();
                              if (context.mounted) {
                                context.go(AppRouter.checkout);
                              }
                            }
                          }
                        : () {
                            _flushPendingDeletes();
                            context.go(AppRouter.checkout);
                          }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMaintenance
                      ? const Color(0xFFEA580C)
                      : const Color(0xFFDD2222),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isMaintenance
                      ? (lang == AppLanguage.indonesia
                          ? 'Pemesanan Dibuka ${maintenance?.launchDate ?? "Desember 2026"}'
                          : 'Ordering Opens ${maintenance?.launchDate ?? "December 2026"}')
                      : tr.get('continue_to_payment', lang),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 15 : 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? Colors.black87 : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
            style: TextStyle(
              fontSize: isTotal ? 15 : 12,
              fontWeight: FontWeight.bold,
              color: isTotal ? const Color(0xFFDD2222) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable cart item card wrapper that reveals a red delete button with trash icon when swiped left
class _SwipeableCartItemCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;

  const _SwipeableCartItemCard({
    super.key,
    required this.child,
    required this.onDelete,
    this.deleteLabel = 'Hapus',
  });

  @override
  State<_SwipeableCartItemCard> createState() => _SwipeableCartItemCardState();
}

class _SwipeableCartItemCardState extends State<_SwipeableCartItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;
  double _dragExtent = 0;
  static const double _buttonWidth = 84.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent =
          (_dragExtent + details.primaryDelta!).clamp(-_buttonWidth, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent < -_buttonWidth / 2 ||
        (details.primaryVelocity ?? 0) < -300) {
      _animateTo(-_buttonWidth);
    } else {
      _animateTo(0.0);
    }
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _dragExtent = _animation!.value;
          });
        }
      });
    _controller.forward(from: 0);
  }

  void _close() {
    if (_dragExtent != 0) {
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _dragExtent < -10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Delete Button with Trash Icon
          // Only rendered when swiped left (_dragExtent < 0)
          if (_dragExtent < 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _buttonWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDelete,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDD2222),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.deleteLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Foreground Card that slides left
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onTap: isOpen ? _close : null,
              child: IgnorePointer(
                ignoring: isOpen,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
