import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/localization/app_language.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/order_controller.dart';
import '../models/order_model.dart';
import '../../../core/widgets/app_dialog.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';

class OrderHistoryView extends ConsumerStatefulWidget {
  const OrderHistoryView({super.key});

  @override
  ConsumerState<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends ConsumerState<OrderHistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'all';
  String _periodFilter = 'all';
  String _sortFilter = 'newest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
        backRoute: '/navigation?index=0',
        child: Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: _buildHeader(lang),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveOrders(lang),
              _buildOrderHistory(lang),
            ],
          ),
        ));
  }

  Widget _buildHeader(AppLanguage lang) {
    return Material(
      color: const Color(0xFFDD2222),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Center(
                child: Text(
                  tr.get('orders_title', lang).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  letterSpacing: 0,
                ),
                tabs: [
                  Tab(text: tr.get('orders_active_tab', lang)),
                  Tab(text: tr.get('orders_history_tab', lang)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          _buildFilterChip(
            icon: Icons.tune_rounded,
            label: _statusFilterLabel(lang),
            items: [
              _FilterOption('all', isEn ? 'All Status' : 'Semua Status'),
              _FilterOption('completed', isEn ? 'Completed' : 'Selesai'),
              _FilterOption('cancelled', isEn ? 'Cancelled' : 'Dibatalkan'),
              _FilterOption('expired', isEn ? 'Expired' : 'Kedaluwarsa'),
            ],
            value: _statusFilter,
            onSelected: (value) => setState(() => _statusFilter = value),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            icon: Icons.calendar_today_outlined,
            label: _periodFilterLabel(lang),
            items: [
              _FilterOption('month', isEn ? 'This Month' : 'Bulan Ini'),
              _FilterOption('week', isEn ? 'This Week' : 'Minggu Ini'),
              _FilterOption('all', isEn ? 'All Time' : 'Semua Waktu'),
            ],
            value: _periodFilter,
            onSelected: (value) => setState(() => _periodFilter = value),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            icon: Icons.swap_vert_rounded,
            label: _sortFilterLabel(lang),
            items: [
              _FilterOption('newest', isEn ? 'Newest' : 'Terbaru'),
              _FilterOption('oldest', isEn ? 'Oldest' : 'Terlama'),
            ],
            value: _sortFilter,
            onSelected: (value) => setState(() => _sortFilter = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required List<_FilterOption> items,
    required String value,
    required ValueChanged<String> onSelected,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: const Color(0xFFF3F4F6),
        hoverColor: const Color(0xFFF3F4F6),
        splashColor: Colors.transparent,
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
      ),
      child: PopupMenuButton<String>(
        initialValue: value,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 6,
        onSelected: onSelected,
        itemBuilder: (context) => items
            .map((item) => PopupMenuItem<String>(
                  value: item.value,
                  child: Text(item.label),
                ))
            .toList(),
        child: Container(
          height: 42,
          constraints: const BoxConstraints(minWidth: 138),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: const Color(0xFF262626)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF262626),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Color(0xFF262626)),
            ],
          ),
        ),
      ),
    );
  }

  List<Order> _applyFilters(List<Order> orders, {required bool isActive}) {
    final now = DateTime.now();
    final statusFilter = isActive ? 'all' : _statusFilter;
    final periodFilter = isActive ? 'all' : _periodFilter;
    final sortFilter = isActive ? 'newest' : _sortFilter;
    final filtered = orders.where((order) {
      final statusMatches = switch (statusFilter) {
        'completed' => order.isCompleted,
        'cancelled' => order.isCancelled && !order.isExpired,
        'expired' => order.isExpired,
        'processing' => order.isPaid ||
            order.isConfirmed ||
            order.isPreparing ||
            order.isReady ||
            order.isReadyForPickup ||
            order.isOutForDelivery,
        'pending_payment' => order.isPendingPayment,
        _ => true,
      };

      final periodMatches = switch (periodFilter) {
        'week' => now.difference(order.createdAt).inDays < 7,
        'month' => order.createdAt.year == now.year &&
            order.createdAt.month == now.month,
        _ => true,
      };

      return statusMatches && periodMatches;
    }).toList();

    filtered.sort((a, b) => sortFilter == 'oldest'
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  String _statusFilterLabel(AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    return switch (_statusFilter) {
      'completed' => isEn ? 'Completed' : 'Selesai',
      'cancelled' => isEn ? 'Cancelled' : 'Dibatalkan',
      'expired' => isEn ? 'Expired' : 'Kedaluwarsa',
      _ => isEn ? 'All Status' : 'Semua Status',
    };
  }

  String _periodFilterLabel(AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    return switch (_periodFilter) {
      'week' => isEn ? 'This Week' : 'Minggu Ini',
      'all' => isEn ? 'All Time' : 'Semua Waktu',
      _ => isEn ? 'This Month' : 'Bulan Ini',
    };
  }

  String _sortFilterLabel(AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    return _sortFilter == 'oldest'
        ? (isEn ? 'Oldest' : 'Terlama')
        : (isEn ? 'Newest' : 'Terbaru');
  }

  Widget _buildActiveOrders(AppLanguage lang) {
    final userIdAsync = ref.watch(currentUserIdProvider);

    return userIdAsync.when(
        data: (userId) {
          if (userId == null) {
            return _buildLoginPrompt(lang);
          }

          final activeOrders = ref.watch(activeOrdersProvider(userId));
          final orders = activeOrders.valueOrNull;

          if (orders != null) {
            final visibleOrders = _applyFilters(orders, isActive: true);

            if (visibleOrders.isEmpty) {
              return RefreshIndicator(
                color: const Color(0xFFDD2222),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(activeOrdersProvider(userId));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: _buildEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: tr.get('no_active_orders', lang),
                            message: tr.get('no_active_orders_message', lang),
                            lang: lang),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
                color: const Color(0xFFDD2222),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(activeOrdersProvider(userId));
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: visibleOrders.length,
                  itemBuilder: (context, index) => _buildOrderCard(
                      visibleOrders[index],
                      isActive: true,
                      lang: lang),
                ));
          }

          if (activeOrders.hasError) {
            return _buildErrorState(activeOrders.error.toString(), lang);
          }

          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFDD2222)));
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFDD2222))),
        error: (error, stack) => _buildErrorState(error.toString(), lang));
  }

  Widget _buildOrderHistory(AppLanguage lang) {
    final userIdAsync = ref.watch(currentUserIdProvider);

    return userIdAsync.when(
        data: (userId) {
          if (userId == null) {
            return _buildLoginPrompt(lang);
          }

          final completedOrders = ref.watch(completedOrdersProvider(userId));
          final activeOrders = ref.watch(activeOrdersProvider(userId)).valueOrNull ?? [];
          final orders = completedOrders.valueOrNull;

          if (orders != null) {
            if (orders.isEmpty) {
              return RefreshIndicator(
                color: const Color(0xFFDD2222),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(completedOrdersProvider(userId));
                  ref.invalidate(activeOrdersProvider(userId));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: _buildEmptyState(
                            icon: Icons.history,
                            title: tr.get('no_order_history', lang),
                            message: tr.get('no_order_history_message', lang),
                            activeOrdersCount: activeOrders.length,
                            lang: lang),
                      ),
                    ),
                  ],
                ),
              );
            }

            final visibleOrders = _applyFilters(orders, isActive: false);

            if (visibleOrders.isEmpty) {
              return RefreshIndicator(
                color: const Color(0xFFDD2222),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(completedOrdersProvider(userId));
                  ref.invalidate(activeOrdersProvider(userId));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildFilterBar(lang),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: _buildFilteredEmptyState(lang),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
                color: const Color(0xFFDD2222),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  ref.invalidate(completedOrdersProvider(userId));
                  ref.invalidate(activeOrdersProvider(userId));
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: visibleOrders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildFilterBar(lang);
                    final order = visibleOrders[index - 1];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildOrderCard(order,
                          isActive: false, lang: lang),
                    );
                  },
                ));
          }

          if (completedOrders.hasError) {
            return _buildErrorState(completedOrders.error.toString(), lang);
          }

          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFDD2222)));
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFDD2222))),
        error: (error, stack) => _buildErrorState(error.toString(), lang));
  }

  Widget _buildOrderCard(
    Order order, {
    required bool isActive,
    required AppLanguage lang,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFECECEC)),
      ),
      child: InkWell(
        onTap: () => context.go(
            '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: icon + order number + status chip ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Container(
                  //   width: 35,
                  //   height: 35,
                  //   decoration: const BoxDecoration(
                  //     color: Color(0xFFFFEBEB),
                  //     shape: BoxShape.circle,
                  //   ),
                  //   child: Icon(
                  //     order.isDelivery
                  //         ? Icons.delivery_dining_rounded
                  //         : (order.isTakeAway
                  //             ? Icons.shopping_bag_outlined
                  //             : Icons.dinner_dining_rounded),
                  //     color: const Color(0xFFDD2222),
                  //     size: 18,
                  //   ),
                  // ),
                  // const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.orderNumber.isNotEmpty
                          ? order.orderNumber
                          : tr
                              .get('order_fallback', lang)
                              .replaceFirst('{id}', order.id.toString()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // const SizedBox(width: 8),
                  _buildStatusChip(order, lang),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 2: date | time | order type ──────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: Color(0xFF111827)),
                      const SizedBox(width: 4),
                      Text(
                        _formatOrderDateTime(order, lang),
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.isDelivery
                            ? Icons.delivery_dining_rounded
                            : (order.isTakeAway
                                ? Icons.shopping_bag_outlined
                                : Icons.dinner_dining_rounded),
                        size: 14,
                        color: const Color(0xFF111827),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatOrderTypeBadge(order, lang),
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                  if (isActive &&
                      !order.isExpired &&
                      (order.isAccepted ||
                          order.isConfirmed ||
                          order.isPreparing ||
                          order.isReady ||
                          order.isReadyForPickup ||
                          order.isDelivering ||
                          order.status == 'accepted' ||
                          order.status == 'confirmed' ||
                          order.status == 'preparing' ||
                          order.status == 'cooking' ||
                          order.status == 'ready' ||
                          order.status == 'ready_for_pickup' ||
                          order.status == 'out_for_delivery'))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.displayTargetTime.isNotEmpty
                              ? (lang == AppLanguage.english
                                  ? '${order.displayRangeTextLang(lang)}, Ready ±${order.displayTargetTime}'
                                  : '${order.displayRangeTextLang(lang)}, Siap ±${order.displayTargetTime} WIB')
                              : order.displayRangeTextLang(lang),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              const SizedBox(height: 10),

              // ── Row 3: branch + item count  +  Total price ─────────────
              Row(
                children: [
                  if (order.branchName.isNotEmpty) ...[
                    const Icon(Icons.storefront_outlined,
                        size: 15, color: Color(0xFF111827)),
                    const SizedBox(width: 4),
                    Text(
                      order.branchName,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.inventory_2_outlined,
                      size: 14, color: Color(0xFF111827)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      tr
                          .get('item_count', lang)
                          .replaceFirst('{count}', order.itemCount.toString()),
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Total',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.normal),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rp ${order.formattedTotalAmount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFFDD2222),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Row 4: action buttons ─────────────────────────────
              if (isActive) ...[
                Row(
                  children: [
                    if (order.isPendingPayment &&
                        !order.isPaid &&
                        order.paymentStatus != 'paid') ...[
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: () =>
                                _showCancelDialog(order.id.toString(), lang),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(color: Color(0xFF9CA3AF)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(
                              tr.get('cancel_order', lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.normal),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 40,
                          child: _buildPayNowButton(context, ref, order, lang),
                        ),
                      ),
                    ] else ...[
                      () {
                        final rightBtn =
                            _buildActiveRightButton(context, ref, order, lang);
                        if (rightBtn != null) {
                          return Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () => context.go(
                                          '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF111827),
                                        side: const BorderSide(
                                            color: Color(0xFF9CA3AF)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: Text(
                                        tr.get('view_details', lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF111827),
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: rightBtn,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () => context.go(
                                    '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF111827),
                                  side: const BorderSide(
                                      color: Color(0xFF9CA3AF)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(
                                  tr.get('view_details', lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.normal),
                                ),
                              ),
                            ),
                          );
                        }
                      }(),
                    ],
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    // Left: Outline Abu-abu (Lihat Detail)
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => context.go(
                              '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFF9CA3AF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            tr.get('view_details', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.normal),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right: Outline Merah (Pesan Lagi)
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => _handleReorder(order.id.toString()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDD2222),
                            side: const BorderSide(color: Color(0xFFDD2222)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            tr.get('reorder', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.normal),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    const indoMonths = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    const engMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return isIndo ? indoMonths[month - 1] : engMonths[month - 1];
  }

  Widget _buildStatusChip(Order order, AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    final String text;

    if (order.isExpired) {
      text = isEn ? 'Expired' : 'Kedaluwarsa';
    } else {
      switch (order.status.toLowerCase().trim()) {
        case 'pending':
        case 'pending_payment':
        case 'awaiting_payment':
          text = isEn ? 'Unpaid' : 'Belum Bayar';
          break;
        case 'payment_failed':
          text = isEn ? 'Failed' : 'Gagal';
          break;
        case 'paid':
        case 'paid_waiting_confirmation':
          text = isEn ? 'Confirming' : 'Tunggu Konfirmasi';
          break;
        case 'confirmed':
        case 'accepted':
          text = isEn ? 'Accepted' : 'Diterima';
          break;
        case 'rejected':
          text = isEn ? 'Rejected' : 'Ditolak';
          break;
        case 'preparing':
          text = isEn ? 'Preparing' : 'Disiapkan';
          break;
        case 'ready':
        case 'ready_for_pickup':
          text = isEn ? 'Ready' : 'Siap';
          break;
        case 'picking_up':
        case 'picking_up_driver':
          text = isEn ? 'Driver OTW' : 'Kurir OTW';
          break;
        case 'picked_up':
          text = isEn ? 'Picked Up' : 'Diambil';
          break;
        case 'in_delivery':
        case 'out_for_delivery':
          text = isEn ? 'Delivering' : 'Diantar';
          break;
        case 'completed':
          text = isEn ? 'Completed' : 'Selesai';
          break;
        case 'cancelled':
          text = isEn ? 'Cancelled' : 'Dibatalkan';
          break;
        default:
          text = order.status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF111827), width: 1.0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(AppLanguage lang) {
    final isEn = lang == AppLanguage.english;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 72, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              isEn ? 'No Orders Found' : 'Tidak Ada Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'No order history matches the selected filters.'
                  : 'Tidak ada riwayat pesanan yang sesuai dengan filter yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _statusFilter = 'all';
                  _periodFilter = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFDD2222)),
              label: Text(
                isEn ? 'Reset Filter' : 'Reset Filter',
                style: const TextStyle(
                  color: Color(0xFFDD2222),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDD2222)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required AppLanguage lang,
    int activeOrdersCount = 0,
  }) {
    final isEn = lang == AppLanguage.english;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (activeOrdersCount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFFDD2222)),
                      const SizedBox(width: 8),
                      Text(
                        isEn
                            ? 'You have $activeOrdersCount active orders'
                            : 'Kamu memiliki $activeOrdersCount pesanan aktif',
                        style: const TextStyle(
                          color: Color(0xFFDD2222),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _tabController.animateTo(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: Text(
                      isEn ? 'View Active Orders' : 'Lihat Pesanan Aktif',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/navigation?index=1'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD2222),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              tr.get('browse_menu', lang),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(AppLanguage lang) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_outline, size: 100, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          tr.get('please_login', lang),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr.get('login_to_view_orders', lang),
          style: TextStyle(color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go(
            AuthGuard.loginLocation('${AppRouter.navigation}?index=3'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD2222),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text(
            tr.get('login', lang),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ));
  }

  Widget _buildErrorState(String error, AppLanguage lang) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          tr.get('error_loading_orders', lang),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            final userId = ref.read(currentUserIdProvider).value;
            if (userId != null) {
              ref.invalidate(activeOrdersProvider(userId));
              ref.invalidate(completedOrdersProvider(userId));
            }
          },
          child: Text(tr.get('retry', lang)),
        ),
      ],
    ));
  }

  void _showCancelDialog(String orderId, AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    String selectedReason =
        isIndo ? 'Salah pilih menu / cabang' : 'Wrong menu / branch selection';
    final customReasonController = TextEditingController();
    bool isCustom = false;

    final reasonsList = isIndo
        ? [
            'Salah pilih menu / cabang',
            'Ingin mengganti metode pembayaran',
            'Ubah pesanan (tambah/kurang item)',
            'Berubah pikiran',
            'Lainnya',
          ]
        : [
            'Wrong menu / branch selection',
            'Change payment method',
            'Change order (add/remove items)',
            'Changed mind',
            'Other',
          ];

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isIndo ? 'Batalkan Pesanan?' : 'Cancel Order?',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndo
                            ? 'Pilih alasan pembatalan:'
                            : 'Select cancellation reason:',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      RadioGroup<String>(
                        groupValue: selectedReason,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            selectedReason = val;
                            isCustom = val == (isIndo ? 'Lainnya' : 'Other');
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: reasonsList.map((reason) {
                            final isSelected = selectedReason == reason;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedReason = reason;
                                  isCustom =
                                      reason == (isIndo ? 'Lainnya' : 'Other');
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Radio<String>(
                                        value: reason,
                                        activeColor: const Color(0xFFDD2222),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: const VisualDensity(
                                          horizontal:
                                              VisualDensity.minimumDensity,
                                          vertical:
                                              VisualDensity.minimumDensity,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFF334155),
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customReasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: isIndo
                                ? 'Tuliskan alasan Anda...'
                                : 'Write your reason...',
                            hintStyle: TextStyle(
                                fontSize: 12, color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFDD2222)),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr.get('no', lang),
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.normal)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final reason = isCustom
                          ? customReasonController.text.trim()
                          : selectedReason;
                      if (isCustom && reason.isEmpty) {
                        Helpers.showSnackbar(
                            context, tr.get('cancel_reason_prompt', lang),
                            backgroundColor: Colors.orange);
                        return;
                      }

                      Navigator.pop(ctx);
                      _cancelOrder(orderId, reason);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    child: Text(isIndo ? 'Ya, Batalkan' : 'Yes, Cancel',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.normal)),
                  ),
                ],
              ),
            ));
  }

  void _cancelOrder(String orderId, String reason) async {
    final lang = ref.read(appLanguageProvider);
    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) {
        if (mounted) {
          Helpers.showSnackbar(context, tr.get('user_not_found', lang));
        }
        return;
      }

      await ref
          .read(orderControllerProvider.notifier)
          .cancelOrder(int.parse(orderId), userId, reason);

      if (mounted) {
        Helpers.showSnackbar(context, tr.get('order_cancelled_success', lang),
            backgroundColor: Colors.green);

        // Refresh the lists
        ref.invalidate(activeOrdersProvider(userId));
        ref.invalidate(completedOrdersProvider(userId));
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackbar(
            context, '${tr.get('failed_cancel_order', lang)}: $e',
            backgroundColor: Colors.red);
      }
    }
  }

  void _handleReorder(String orderId) async {
    if (mounted) {
      context.go('/brand-branch-selection');
    }
  }

  String _formatOrderDateTime(Order order, AppLanguage lang) {
    final createdAt = order.createdAt.toLocal();
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = _getMonthName(createdAt.month, lang);
    final year = createdAt.year.toString();
    final hh = createdAt.hour.toString().padLeft(2, '0');
    final mm = createdAt.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hh:$mm WIB';
  }

  Widget _buildPayNowButton(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang) {
    final isCash = order.paymentMethod.toLowerCase() == 'cash' ||
        order.paymentMethod.toLowerCase() == 'tunai';
    if (isCash) {
      return OutlinedButton.icon(
        onPressed: () {
          final orderNum = order.orderNumber.isNotEmpty
              ? order.orderNumber
              : order.id.toString();
          context.go(
              '/cash-payment?orderId=$orderNum&amount=${order.totalAmount}');
        },
        // icon: const Icon(Icons.payments_rounded, size: 15),
        label: Text(
          tr.get('pay_now', lang),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDD2222),
          side: const BorderSide(color: Color(0xFFDD2222)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => context.go(
          '/payment/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
      icon: const Icon(Icons.payment_rounded, size: 15),
      label: Text(
        tr.get('pay_now', lang),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDD2222),
        side: const BorderSide(color: Color(0xFFDD2222)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  String _formatOrderTypeBadge(Order order, AppLanguage lang) {
    return order.orderTypeDisplayFor(lang);
  }

  Widget? _buildActiveRightButton(
      BuildContext context, WidgetRef ref, Order order, AppLanguage lang) {
    final status = order.status.toLowerCase().trim();
    final isIndo = lang == AppLanguage.indonesia;

    // Ready for dine-in or takeaway pickup -> Confirm received
    if ((status == 'ready' || status == 'ready_for_pickup') &&
        !order.isDelivery) {
      return OutlinedButton(
        onPressed: () async {
          final confirmed = await AppDialog.showConfirm(
            context: context,
            title: isIndo
                ? 'Konfirmasi Pesanan Diterima'
                : 'Confirm Order Received',
            message: isIndo
                ? 'Apakah Anda yakin sudah menerima pesanan ini dengan baik dan lengkap?'
                : 'Are you sure you have received this order completely and in good condition?',
            confirmText: isIndo ? 'Ya, Sudah' : 'Yes',
            cancelText: isIndo ? 'Batal' : 'Cancel',
            confirmColor: const Color(0xFFDD2222),
            showIcon: false,
            type: AppDialogType.info,
          );
          if (!confirmed || !context.mounted) return;

          try {
            final userId = await ref.read(currentUserIdProvider.future);
            final targetId = order.orderNumber.isNotEmpty
                ? order.orderNumber
                : order.id.toString();
            await ref
                .read(orderControllerProvider.notifier)
                .completeOrder(targetId, userId!);
            if (context.mounted) {
              Helpers.showSnackbar(
                  context, tr.get('order_confirmed_success', lang),
                  backgroundColor: Colors.green);
            }
          } catch (e) {
            if (context.mounted) {
              Helpers.showSnackbar(
                  context, '${tr.get('order_confirm_failed', lang)}: $e',
                  backgroundColor: Colors.red);
            }
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDD2222),
          side: const BorderSide(color: Color(0xFFDD2222)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          tr.get('order_received', lang),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Delivery with live track URL
    if (order.isDelivery &&
        order.trackUrl != null &&
        order.trackUrl!.isNotEmpty) {
      return OutlinedButton(
        onPressed: () async {
          final uri = Uri.tryParse(order.trackUrl!);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
          if (context.mounted) {
            context.go(
                '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}');
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDD2222),
          side: const BorderSide(color: Color(0xFFDD2222)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          isIndo ? 'Lacak Kurir' : 'Track Driver',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Delivery order default action -> Lacak Pesanan
    if (order.isDelivery) {
      return OutlinedButton(
        onPressed: () => context.go(
            '/orders/${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDD2222),
          side: const BorderSide(color: Color(0xFFDD2222)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          isIndo ? 'Lacak Pesanan' : 'Track Order',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // For Dine-in and Takeaway in progress (not ready) -> No right action (only Lihat Detail)
    return null;
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}
