import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';
import 'dynamic_home_page.dart';
import '../../menu/views/menu_view.dart';
import '../../cart/views/cart_view.dart';
import '../../order/views/order_history_view.dart';
import '../../profile/views/profile_view.dart';
import '../../../core/localization/app_language.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../order/controllers/order_controller.dart';
import '../../../shared/services/service_providers.dart';

class NavigationView extends ConsumerStatefulWidget {
  final int initialIndex;
  const NavigationView({super.key, this.initialIndex = 0});

  @override
  ConsumerState<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends ConsumerState<NavigationView> {
  late int _currentIndex;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    const privateTabs = {2, 3, 4};
    final requestedIndex = widget.initialIndex.clamp(0, 4);
    if (privateTabs.contains(requestedIndex) &&
        !AuthGuard.isAuthenticated(ref)) {
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AuthGuard.requireLogin(
            context,
            ref,
            redirectTo: '${AppRouter.navigation}?index=$requestedIndex');
        }
      });
    } else {
      _currentIndex = requestedIndex;
    }
  }

  @override
  void didUpdateWidget(covariant NavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _currentIndex != widget.initialIndex) {
      const privateTabs = {2, 3, 4};
      final requestedIndex = widget.initialIndex;
      if (privateTabs.contains(requestedIndex) &&
          !AuthGuard.isAuthenticated(ref)) {
        _setCurrentTab(0, updateRoute: false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AuthGuard.requireLogin(
              context,
              ref,
              redirectTo: '${AppRouter.navigation}?index=$requestedIndex');
          }
        });
      } else {
        _setCurrentTab(requestedIndex.clamp(0, 4), updateRoute: false);
      }
    }
  }

  void _onTabTapped(int index) {
    const privateTabs = {2, 3, 4};
    if (privateTabs.contains(index) && !AuthGuard.isAuthenticated(ref)) {
      AuthGuard.requireLogin(
        context,
        ref,
        redirectTo: '${AppRouter.navigation}?index=$index');
      return;
    }

    if (_currentIndex != index) {
      _setCurrentTab(index);
    }
  }

  void _setCurrentTab(int index, {bool updateRoute = true}) {
    setState(() => _currentIndex = index);
    if (updateRoute) {
      context.go('${AppRouter.navigation}?index=$index');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch language only once here, pass down — avoid 5 separate watch calls in nav items
    final lang = ref.watch(appLanguageProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_currentIndex != 0) {
          _setCurrentTab(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          Helpers.showSnackbar(context,
            tr.get('tap_again_to_exit', lang),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          // IndexedStack keeps all page states alive across tab switches.
          // Previously using _buildCurrentPage() which destroyed/recreated
          // pages on every tab tap — causing lag and data re-fetching.
          index: _currentIndex,
          children: const [
            DynamicHomePage(),
            MenuView(),
            CartView(),
            OrderHistoryView(),
            ProfileView(key: ValueKey('profile-view-v2')),
          ],
        ),
        extendBody: false,
        bottomNavigationBar: _BottomNavBar(
          currentIndex: _currentIndex,
          lang: lang,
          onTap: _onTabTapped,
        ),
      ));
  }
}

/// Isolated BottomNavBar widget. Only rebuilds when currentIndex or lang changes.
/// Badge counts (cart, orders) are handled by their own isolated Consumer widgets.
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final AppLanguage lang;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double marginBottom = bottomPadding > 24 
        ? bottomPadding + 10 
        : (bottomPadding > 0 ? 12 : 10);

    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: marginBottom,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33DD2222),
            blurRadius: 20,
            offset: Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFDD2222),
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
              ),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: [
                _buildNavItem(Icons.home_rounded, Icons.home_outlined,
                    tr.get('nav_home', lang), 0),
                _buildNavItem(Icons.restaurant_menu_rounded,
                    Icons.restaurant_menu_outlined, tr.get('nav_menu', lang), 1),
                _buildNavItem(Icons.shopping_bag_rounded,
                    Icons.shopping_bag_outlined, tr.get('nav_cart', lang), 2),
                _buildNavItem(Icons.receipt_long_rounded,
                    Icons.receipt_long_outlined, tr.get('nav_orders', lang), 3),
                _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded,
                    tr.get('nav_profile', lang), 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index,
  ) {
    final isActive = currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0x1ADD2222)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _NavIcon(
          activeIcon: activeIcon,
          inactiveIcon: inactiveIcon,
          index: index,
          isActive: isActive,
        ),
      ),
      label: label,
    );
  }
}

/// Isolated icon widget per tab.
/// Cart badge (index=2) watches cartItemCountProvider.
/// Orders badge (index=3) watches activeOrdersProvider.
/// Only these specific provider watches happen here, not in the full nav build.
class _NavIcon extends ConsumerWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final int index;
  final bool isActive;

  const _NavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.index,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconWidget = Icon(isActive ? activeIcon : inactiveIcon, size: 26);

    if (index == 2) {
      // Cart badge — only rebuilds when cart count changes
      final cartCount = ref.watch(cartItemCountProvider);
      return Badge(
        label: Text('$cartCount'),
        isLabelVisible: cartCount > 0,
        backgroundColor: const Color(0xFFDD2222),
        child: iconWidget,
      );
    } else if (index == 3) {
      // Orders badge — only rebuilds when order count changes
      final user = ref.watch(currentUserProvider).valueOrNull;
      final activeOrdersCount = user != null
          ? (ref.watch(activeOrdersProvider(user.id)).valueOrNull?.length ?? 0)
          : 0;
      return Badge(
        label: Text('$activeOrdersCount'),
        isLabelVisible: activeOrdersCount > 0,
        backgroundColor: const Color(0xFFDD2222),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CART'),
        backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Cart Page - Coming Soon')),
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORDERS'),
        backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Orders Page - Coming Soon')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFDD2222),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Guest User',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'guest@delitopia.com',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Order History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRouter.orderHistory),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Addresses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('Vouchers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRouter.vouchers),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRouter.settings),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => context.go(AppRouter.navigation),
          ),
        ],
      ));
  }
}
