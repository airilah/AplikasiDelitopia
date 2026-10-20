import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/services/service_providers.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  String _selectedCategory = 'all';
  final Set<String> _deletedNotificationKeys = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifs = ref.read(notificationsProvider).valueOrNull ?? [];
      _markNotificationsAsRead(notifs);
    });
  }

  void _loadDeletedKeys() {
    final storage = ref.read(storageServiceProvider);
    final savedKeys = storage.getDeletedNotificationKeys();
    setState(() {
      _deletedNotificationKeys.addAll(savedKeys);
    });
  }

  String _getNotificationKey(NotificationModel n) {
    if (n.id > 0) return 'id_${n.id}';
    if (n.eventId != null && n.eventId!.isNotEmpty) return 'event_${n.eventId}';
    return 'key_${n.title}_${n.createdAt.millisecondsSinceEpoch}';
  }

  void _markNotificationsAsRead(
      [List<NotificationModel>? notifications]) async {
    final now = DateTime.now();
    DateTime markTime = now;
    final list =
        notifications ?? ref.read(notificationsProvider).valueOrNull ?? [];
    if (list.isNotEmpty) {
      final latest =
          list.map((n) => n.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      if (latest.isAfter(markTime)) markTime = latest;
    }
    await ref
        .read(storageServiceProvider)
        .saveLastSeenNotificationTime(markTime);
    ref.read(lastSeenNotificationTimeProvider.notifier).state = markTime;
    ref.invalidate(hasUnreadNotificationsProvider);
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final key = _getNotificationKey(notification);
    setState(() {
      _deletedNotificationKeys.add(key);
    });

    final storage = ref.read(storageServiceProvider);
    await storage.addDeletedNotificationKey(key);

    if (mounted) {
      final lang = ref.read(appLanguageProvider);
      var isUndone = false;
      Helpers.showCustomAlert(
        context,
        lang == AppLanguage.indonesia
            ? 'Notifikasi berhasil dihapus'
            : 'Notification deleted',
        isSuccess: true,
        duration: const Duration(seconds: 3),
        bottomOffset: 12,
        includeBottomPadding: false,
        action: SnackBarAction(
          label: lang == AppLanguage.indonesia ? 'Urungkan' : 'Undo',
          onPressed: () async {
            isUndone = true;
            if (mounted) {
              setState(() {
                _deletedNotificationKeys.remove(key);
              });
            }
            await storage.removeDeletedNotificationKey(key);
          },
        ),
      );

      Timer(const Duration(seconds: 3), () {
        if (!isUndone && notification.id > 0) {
          try {
            ref
                .read(notificationServiceProvider)
                .deleteNotification(notification.id);
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _deleteAllNotifications(
      List<NotificationModel> notifications) async {
    final keys = notifications.map(_getNotificationKey).toList();
    setState(() {
      _deletedNotificationKeys.addAll(keys);
    });

    final storage = ref.read(storageServiceProvider);
    await storage.addAllDeletedNotificationKeys(keys);

    if (mounted) {
      final lang = ref.read(appLanguageProvider);
      var isUndone = false;
      Helpers.showCustomAlert(
        context,
        lang == AppLanguage.indonesia
            ? 'Semua notifikasi berhasil dihapus'
            : 'All notifications cleared',
        isSuccess: true,
        duration: const Duration(seconds: 3),
        bottomOffset: 12,
        includeBottomPadding: false,
        action: SnackBarAction(
          label: lang == AppLanguage.indonesia ? 'Urungkan' : 'Undo',
          onPressed: () async {
            isUndone = true;
            if (mounted) {
              setState(() {
                _deletedNotificationKeys.removeAll(keys);
              });
            }
            await storage.removeAllDeletedNotificationKeys(keys);
          },
        ),
      );

      Timer(const Duration(seconds: 3), () {
        if (!isUndone) {
          for (final n in notifications) {
            if (n.id > 0) {
              try {
                ref.read(notificationServiceProvider).deleteNotification(n.id);
              } catch (_) {}
            }
          }
        }
      });
    }
  }

  Future<void> _showDeleteAllConfirmationDialog(
    BuildContext context,
    AppLanguage lang,
    List<NotificationModel> notificationsToDelete,
  ) async {
    final isIndo = lang == AppLanguage.indonesia;

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: isIndo ? 'Hapus Semua Notifikasi?' : 'Delete All Notifications?',
      message: isIndo
          ? 'Apakah Anda yakin ingin menghapus semua pesan notifikasi?'
          : 'Are you sure you want to delete all notifications?',
      confirmText: isIndo ? 'Hapus Semua' : 'Delete All',
      cancelText: isIndo ? 'Batal' : 'Cancel',
      type: AppDialogType.danger,
    );

    if (confirmed == true && mounted) {
      _deleteAllNotifications(notificationsToDelete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final lang = ref.watch(appLanguageProvider);
    final allRawNotifications = notificationsAsync.valueOrNull ?? [];

    // Filter out deleted notifications
    final nonDeletedNotifications = allRawNotifications
        .where((n) => !_deletedNotificationKeys.contains(_getNotificationKey(n)))
        .toList();

    return BackButtonWrapper(
      backRoute: '/navigation?index=0',
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=0',
            color: Colors.white,
          ),
          title: Text(
            tr.get('notifications_title', lang),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            if (nonDeletedNotifications.isNotEmpty)
              IconButton(
                tooltip: lang == AppLanguage.indonesia
                    ? 'Hapus Semua Notifikasi'
                    : 'Clear All Notifications',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => _showDeleteAllConfirmationDialog(
                  context,
                  lang,
                  nonDeletedNotifications,
                ),
              ),
          ],
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Filter Tabs (Tanpa Icon)
            _buildFilterTabs(lang),

            // Notification List
            Expanded(
              child: notificationsAsync.when(
                data: (notifications) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markNotificationsAsRead(notifications);
                  });

                  // Deduplicate notifications with identical content in the same minute
                  final seenKeys = <String>{};
                  final uniqueNotifications = <NotificationModel>[];
                  for (final n in notifications) {
                    final key = n.eventId ??
                        '${n.id}_${n.idOrder ?? ''}_${n.statusOrder ?? ''}_${n.title}_${n.body}_${n.createdAt.year}-${n.createdAt.month}-${n.createdAt.day}_${n.createdAt.hour}:${n.createdAt.minute}';
                    if (!seenKeys.contains(key)) {
                      seenKeys.add(key);
                      uniqueNotifications.add(n);
                    }
                  }

                  final nonDeleted = uniqueNotifications
                      .where((n) =>
                          !_deletedNotificationKeys.contains(_getNotificationKey(n)))
                      .toList();

                  final filteredNotifications = nonDeleted
                      .where((n) => _matchesCategory(n, _selectedCategory))
                      .toList();

                  if (filteredNotifications.isEmpty) {
                    return RefreshIndicator(
                      color: const Color(0xFFDD2222),
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        ref.invalidate(notificationsProvider);
                      },
                      child: _buildEmptyState(lang),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFDD2222),
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      ref.invalidate(notificationsProvider);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      itemCount: filteredNotifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = filteredNotifications[index];
                        return _SwipeableNotificationCard(
                          key: ValueKey(_getNotificationKey(notification)),
                          onDelete: () => _deleteNotification(notification),
                          child: _buildNotificationCard(
                            notification,
                            index,
                            lang,
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const _NotificationSkeleton(),
                ),
                error: (error, stack) => _buildErrorState(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal pill filter tabs without icons
  Widget _buildFilterTabs(AppLanguage lang) {
    final filters = [
      {'key': 'all', 'label': lang == AppLanguage.indonesia ? 'Semua' : 'All'},
      {
        'key': 'order',
        'label': lang == AppLanguage.indonesia ? 'Pesanan' : 'Orders'
      },
      {
        'key': 'promo',
        'label': lang == AppLanguage.indonesia ? 'Promo' : 'Promo'
      },
      {
        'key': 'voucher',
        'label': lang == AppLanguage.indonesia ? 'Voucher' : 'Vouchers'
      },
      {'key': 'info', 'label': lang == AppLanguage.indonesia ? 'Info' : 'Info'},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedCategory == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = filter['key']!;
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFDD2222)
                        : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFDD2222)
                                   .withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter['label']!,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF111827),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _matchesCategory(NotificationModel notification, String category) {
    if (category == 'all') return true;

    final explicitCategory = (notification.category ?? '').toLowerCase();
    final type = notification.type.toLowerCase();
    final typeData = (notification.typeData ?? '').toLowerCase();
    final title = notification.title.toLowerCase();
    final body = notification.body.toLowerCase();

    // 1. Order Category Check (Prioritize: order notifications must never leak into Info)
    final isOrder = explicitCategory == 'order' ||
        type == 'order' ||
        type.startsWith('order') ||
        type == 'delivery' ||
        type == 'cancellation_request' ||
        typeData == 'cancellation_request' ||
        typeData.startsWith('order') ||
        notification.statusOrder != null ||
        (notification.idOrder != null && notification.idOrder!.isNotEmpty) ||
        title.contains('pesanan') ||
        title.contains('order') ||
        title.contains('batal') ||
        title.contains('pembatalan') ||
        title.contains('kurir') ||
        title.contains('driver') ||
        title.contains('dimasak') ||
        title.contains('hidangan') ||
        body.contains('pesanan') ||
        body.contains('order') ||
        body.contains('ord-') ||
        body.contains('kurir') ||
        body.contains('dibatalkan');

    if (category == 'order') {
      return isOrder;
    }

    // 2. Voucher Category Check (Priority over Promo so vouchers mentioning discount/promo aren't stolen)
    final isVoucher = !isOrder &&
        (explicitCategory == 'voucher' ||
            type == 'voucher' ||
            type.contains('voucher') ||
            typeData == 'voucher' ||
            typeData.contains('voucher') ||
            notification.isVoucherNotification ||
            title.contains('voucher') ||
            title.contains('kupon') ||
            title.contains('klaim') ||
            body.contains('voucher') ||
            body.contains('kupon') ||
            body.contains('ditukarkan') ||
            body.contains('digunakan'));

    if (category == 'voucher') {
      return isVoucher;
    }

    // 3. Promo Category Check (Only if not order and not voucher)
    final isPromo = !isOrder &&
        !isVoucher &&
        (explicitCategory == 'promo' ||
            type == 'promo' ||
            type == 'marketing' ||
            type == 're_engagement' ||
            notification.isPromoNotification ||
            title.contains('promo') ||
            title.contains('diskon') ||
            body.contains('promo') ||
            body.contains('diskon'));

    if (category == 'promo') {
      return isPromo;
    }

    // 4. Info / General Category Check (Everything else: system maintenance, announcements, broadcasts)
    if (category == 'info') {
      return !isOrder && !isPromo && !isVoucher;
    }

    return true;
  }

  Widget _buildEmptyState(AppLanguage lang) {
    final isIndo = lang == AppLanguage.indonesia;
    String emptyTitle = isIndo ? 'Belum Ada Notifikasi' : 'No Notifications';
    String emptySubtitle =
        isIndo ? 'Notifikasi terbaru akan muncul di sini.' : 'New updates will appear here.';

    if (_selectedCategory != 'all') {
      switch (_selectedCategory) {
        case 'order':
          emptyTitle = isIndo
              ? 'Belum Ada Notifikasi Pesanan'
              : 'No Order Notifications';
          emptySubtitle = isIndo
              ? 'Status pesanan makananmu akan muncul di sini.'
              : 'Your food order updates will appear here.';
          break;
        case 'promo':
          emptyTitle = isIndo
              ? 'Belum Ada Notifikasi Promo'
              : 'No Promo Notifications';
          emptySubtitle = isIndo
              ? 'Promo dan diskon menarik akan muncul di sini.'
              : 'Exciting promos and discounts will appear here.';
          break;
        case 'voucher':
          emptyTitle = isIndo
              ? 'Belum Ada Notifikasi Voucher'
              : 'No Voucher Notifications';
          emptySubtitle = isIndo
              ? 'Voucher hadiah dan promo akan muncul di sini.'
              : 'Reward and promo vouchers will appear here.';
          break;
        case 'info':
          emptyTitle =
              isIndo ? 'Belum Ada Info & Akun' : 'No Info & Updates';
          emptySubtitle = isIndo
              ? 'Pembaruan reward dan info akun akan muncul di sini.'
              : 'Reward and account updates will appear here.';
          break;
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 42,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  emptyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final lang = ref.watch(appLanguageProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 38,
                color: Color(0xFFDD2222),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Gagal memuat notifikasi'
                  : 'Failed to load notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang == AppLanguage.indonesia
                  ? 'Silakan periksa koneksi Anda dan coba lagi.'
                  : 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(notificationsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr.get('retry', lang)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD2222),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Notification Card tanpa badge/label di dalam
  Widget _buildNotificationCard(
    NotificationModel notification,
    int index,
    AppLanguage lang,
  ) {
    final title = notification.title.trim().isEmpty
        ? _fallbackTitle(notification)
        : notification.title.trim();
    final body = notification.body.trim();
    final meta = _notificationMeta(notification, lang);

    const titleStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      height: 1.3,
      color: Color(0xFF111827),
    );
    const bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: Color(0xFF1F2937),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          NotificationRouter.open(
            actionUrl: notification.actionUrl,
            category: notification.category,
            templateKey: notification.templateKey,
            type: notification.type,
            orderId: notification.idOrder,
            statusOrder: notification.statusOrder,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEBEBEB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title: Full width, clean & bold without internal badge
              Text(
                title,
                style: titleStyle,
                softWrap: true,
              ),

              // Body text: Full width, natural text without truncation
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  style: bodyStyle,
                  softWrap: true,
                ),
              ],

              // Bottom Footer: Waktu & Nomor Order
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Color(0xFF374151),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.normal,
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
      ),
    );
  }

  String _fallbackTitle(NotificationModel notification) {
    final lang = ref.read(appLanguageProvider);
    final category = (notification.category ?? '').toLowerCase();
    if (category == 'order' ||
        notification.isOrderNotification ||
        notification.type == 'order') {
      return lang == AppLanguage.indonesia
          ? 'Pembaruan Pesanan'
          : 'Order update';
    }
    if (category == 'voucher' ||
        notification.isVoucherNotification ||
        notification.type == 'voucher' ||
        (notification.typeData ?? '').contains('voucher')) {
      return lang == AppLanguage.indonesia
          ? 'Voucher & Hadiah'
          : 'Voucher & Rewards';
    }
    if (category == 'promo' ||
        notification.isPromoNotification ||
        notification.type == 'promo') {
      return lang == AppLanguage.indonesia ? 'Promosi & Diskon' : 'Promotion';
    }
    return lang == AppLanguage.indonesia ? 'Notifikasi' : 'Notification';
  }

  String _notificationMeta(NotificationModel notification, AppLanguage lang) {
    final details = <String>[notification.formattedTime(lang)];
    final isOrder = _matchesCategory(notification, 'order');
    if (!isOrder &&
        notification.idOrder != null &&
        notification.idOrder!.isNotEmpty) {
      details.add('Order #${notification.idOrder}');
    }
    return details.join(' - ');
  }
}

/// Swipeable card wrapper that reveals a red delete button with trash icon when swiped left
class _SwipeableNotificationCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeableNotificationCard({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeableNotificationCard> createState() =>
      _SwipeableNotificationCardState();
}

class _SwipeableNotificationCardState extends State<_SwipeableNotificationCard>
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Delete Button with Trash Icon
        // Only visible when swiped left (_dragExtent < 0)
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
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hapus',
                        style: TextStyle(
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
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
