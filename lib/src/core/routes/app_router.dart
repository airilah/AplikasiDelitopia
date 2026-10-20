import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import actual view files
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/phone_auth_view.dart';
import '../../features/auth/views/otp_verification_view.dart';
import '../../features/auth/views/complete_profile_view.dart';
import '../../features/auth/views/email_verification_view.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/home/views/navigation_view.dart';
import '../../features/menu/views/menu_view.dart';
import '../../features/menu/views/brand_branch_selection_view.dart';
import '../../features/menu/views/product_details_view.dart';
import '../../features/menu/views/product_reviews_view.dart';
import '../../features/cart/views/cart_view.dart';
import '../../features/cart/views/checkout_view.dart';
import '../../features/order/views/order_history_view.dart';
import '../../features/order/views/order_details_view.dart';
import '../../features/payment/views/payment_details_view.dart';
import '../../features/payment/views/cash_payment_view.dart';
import '../../features/profile/views/profile_view.dart';
import '../../features/profile/views/edit_profile_view.dart';
import '../../features/profile/views/add_phone_number_view.dart';
import '../../features/profile/views/member_profile_qr_view.dart';
import '../../features/profile/views/address_list_view.dart';
import '../../features/profile/views/add_edit_address_view.dart';
import '../../features/profile/views/settings_view.dart';
import '../../features/qr_scanner/views/qr_scanner_view.dart';
import '../../features/voucher/views/vouchers_view.dart';
import '../../features/favorites/views/favorites_view.dart';
import '../../features/notifications/views/notifications_view.dart';
import '../../features/notifications/views/notification_management_view.dart';
import '../../features/help/views/help_center_view.dart';
import '../../features/about/views/about_us_view.dart';
import '../../features/legal/views/terms_and_conditions_view.dart';
import '../../features/legal/views/privacy_policy_view.dart';
import '../../features/search/views/global_search_view.dart';
import '../animations/page_transitions.dart';
import '../widgets/auth_required_view.dart';
import '../widgets/onboarding_screen.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/app_maintenance_dialog.dart';

/// AppRouter - Centralized routing configuration using GoRouter
class AppRouter {
  AppRouter._();

  // Route Names
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneAuth = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String completeProfile = '/auth/complete-profile';
  static const String emailVerification = '/auth/email-verification';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String navigation = '/navigation';
  static const String search = '/search';
  static const String brandBranchSelection = '/brand-branch-selection';
  static const String menu = '/menu';
  static const String productDetails = '/product/:id';
  static const String productReviews = '/product-reviews/:id';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderHistory = '/orders';
  static const String orderDetails = '/orders/:id';
  static const String trackOrder = '/track-order/:id';
  static const String payment = '/payment/:id';
  static const String cashPayment = '/cash-payment';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String addPhoneNumber = '/profile/phone';
  static const String addressList = '/profile/addresses';
  static const String addAddress = '/profile/addresses/add';
  static const String editAddress = '/profile/addresses/edit/:id';
  static const String qrScanner = '/qr-scanner';
  static const String vouchers = '/vouchers';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';
  static const String settings = '/settings';
  static const String helpCenter = '/help';
  static const String aboutUs = '/about';
  static const String termsAndConditions = '/terms';
  static const String privacyPolicy = '/privacy';
  static const String memberQr = '/member-qr';

  // Router Instance
  static final router = GoRouter(
    initialLocation: splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash Route
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashView(),
      ),

      // Onboarding Route
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            context.go(AppRouter.navigation);
          },
          onSkip: () {
            context.go(AppRouter.navigation);
          },
        ),
      ),

      // Auth Routes
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return LoginView(returnTo: returnTo);
        },
      ),
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return PhoneAuthView(
            mode: PhoneAuthMode.register,
            returnTo: returnTo);
        },
      ),
      GoRoute(
        path: phoneAuth,
        name: 'phoneAuth',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'register'
              ? PhoneAuthMode.register
              : PhoneAuthMode.login;
          final returnTo = state.uri.queryParameters['returnTo'];
          return PhoneAuthView(mode: mode, returnTo: returnTo);
        },
      ),
      GoRoute(
        path: otpVerification,
        name: 'otpVerification',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final mode = state.uri.queryParameters['mode'] == 'register'
              ? PhoneAuthMode.register
              : PhoneAuthMode.login;
          final channel = state.uri.queryParameters['channel'] ?? 'whatsapp';
          final returnTo = state.uri.queryParameters['returnTo'];
          return OtpVerificationView(
            phoneNumber: phone,
            mode: mode,
            channel: channel,
            returnTo: returnTo);
        },
      ),
      GoRoute(
        path: completeProfile,
        name: 'completeProfile',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final returnTo = state.uri.queryParameters['returnTo'];
          return CompleteProfileView(phoneNumber: phone, returnTo: returnTo);
        },
      ),
      GoRoute(
        path: emailVerification,
        name: 'emailVerification',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: EmailVerificationView(returnTo: returnTo));
        },
      ),
      GoRoute(
        path: forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordView(),
      ),

      // Main Navigation Route (Bottom Nav)
      GoRoute(
        path: navigation,
        name: 'navigation',
        builder: (context, state) {
          final index =
              int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;
          return NavigationView(initialIndex: index);
        },
      ),

      // Home Route
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeView(),
      ),

      // Global Search Route
      GoRoute(
        path: search,
        name: 'search',
        builder: (context, state) => const GlobalSearchView(),
      ),

      // Brand & Branch Selection Route
      GoRoute(
        path: brandBranchSelection,
        name: 'brandBranchSelection',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final brandId = extra?['brandId'] as String?;
          return BrandBranchSelectionView(initialBrandId: brandId);
        },
      ),

      // Menu/Product Routes
      GoRoute(
        path: menu,
        name: 'menu',
        redirect: (context, state) {
          final brandId = state.uri.queryParameters['brandId'];
          final branchId = state.uri.queryParameters['branchId'];
          // If no specific brand and branch are selected, redirect to the main navigation Menu tab
          if (brandId == null && branchId == null) {
            return '${AppRouter.navigation}?index=1';
          }
          return null;
        },
        builder: (context, state) {
          final brandId = state.uri.queryParameters['brandId'];
          final branchId = state.uri.queryParameters['branchId'];
          final categoryId = state.uri.queryParameters['categoryId'];
          return MenuView(
            brandId: brandId,
            branchId: branchId,
            categoryId: categoryId);
        },
      ),
      GoRoute(
        path: productDetails,
        name: 'productDetails',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final branchId = state.uri.queryParameters['branchId'];
          return PageTransitions.slideFromRight(
            child: ProductDetailsView(productId: id, branchId: branchId),
            state: state);
        },
      ),
      GoRoute(
        path: productReviews,
        name: 'productReviews',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final productName = state.uri.queryParameters['name'];
          return PageTransitions.slideFromRight(
            child: ProductReviewsView(productId: id, productName: productName),
            state: state);
        },
      ),

      // Cart & Checkout Routes
      GoRoute(
        path: cart,
        name: 'cart',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const CartView(),
        ),
      ),
      GoRoute(
        path: checkout,
        name: 'checkout',
        pageBuilder: (context, state) => PageTransitions.slideFromBottom(
          child: AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: const CheckoutView(),
          ),
          state: state,
        ),
      ),

      // Order Routes
      GoRoute(
        path: orderHistory,
        name: 'orderHistory',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const OrderHistoryView(),
        ),
      ),
      GoRoute(
        path: orderDetails,
        name: 'orderDetails',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return PageTransitions.slideFromRight(
            child: AuthRequiredView(
              redirectTo: state.uri.toString(),
              child: OrderDetailsView(orderId: id),
            ),
            state: state);
        },
      ),
      GoRoute(
        path: trackOrder,
        name: 'trackOrder',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: TrackOrderView(orderId: id));
        },
      ),
      GoRoute(
        path: payment,
        name: 'payment',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return PageTransitions.slideFromBottom(
            child: AuthRequiredView(
              redirectTo: state.uri.toString(),
              child: PaymentDetailsView(transactionId: id),
            ),
            state: state);
        },
      ),
      GoRoute(
        path: cashPayment,
        name: 'cashPayment',
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] ?? '';
          final amountStr = state.uri.queryParameters['amount'] ?? '0';
          final amount = double.tryParse(amountStr) ?? 0.0;
          return PageTransitions.slideFromBottom(
            child: AuthRequiredView(
              redirectTo: state.uri.toString(),
              child: CashPaymentView(
                orderId: orderId,
                amount: amount,
              ),
            ),
            state: state,
          );
        },
      ),

      // Profile Routes
      GoRoute(
        path: profile,
        name: 'profile',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const ProfileView(),
        ),
      ),
      GoRoute(
        path: editProfile,
        name: 'editProfile',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const EditProfileView(),
        ),
      ),
      GoRoute(
        path: addPhoneNumber,
        name: 'addPhoneNumber',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: AddPhoneNumberView(returnTo: returnTo));
        },
      ),
      GoRoute(
        path: '/add-phone-number',
        name: 'addPhoneNumberAlias',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: AddPhoneNumberView(returnTo: returnTo));
        },
      ),
      GoRoute(
        path: addressList,
        name: 'addressList',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const AddressListView(),
        ),
      ),
      GoRoute(
        path: addAddress,
        name: 'addAddress',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const AddEditAddressView(),
        ),
      ),
      GoRoute(
        path: editAddress,
        name: 'editAddress',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: AddEditAddressView(addressId: id));
        },
      ),
      GoRoute(
        path: memberQr,
        name: 'memberQr',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const MemberProfileQrView(),
        ),
      ),

      // QR Scanner Route
      GoRoute(
        path: qrScanner,
        name: 'qrScanner',
        builder: (context, state) => const QRScannerView(),
      ),

      // Voucher Route
      GoRoute(
        path: vouchers,
        name: 'vouchers',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialTab = tab == 'my'
              ? 1
              : (tab == 'history' || tab == 'points' || tab == '2')
                  ? 2
                  : int.tryParse(tab ?? '0') ?? 0;
          return AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: VouchersView(initialTab: initialTab));
        },
      ),

      // Favorites Route
      GoRoute(
        path: favorites,
        name: 'favorites',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const FavoritesView(),
        ),
      ),

      // Notifications Route
      GoRoute(
        path: notifications,
        name: 'notifications',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const NotificationsView(),
        ),
      ),
      GoRoute(
        path: notificationSettings,
        name: 'notificationSettings',
        builder: (context, state) => AuthRequiredView(
          redirectTo: state.uri.toString(),
          child: const NotificationManagementView(),
        ),
      ),

      // Settings Routes
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) => PageTransitions.slideFromRight(
          child: AuthRequiredView(
            redirectTo: state.uri.toString(),
            child: const SettingsView(),
          ),
          state: state,
        ),
      ),

      // Help & Support Routes
      GoRoute(
        path: helpCenter,
        name: 'helpCenter',
        builder: (context, state) => const HelpCenterView(),
      ),

      // Content Routes
      GoRoute(
        path: aboutUs,
        name: 'aboutUs',
        builder: (context, state) => const AboutUsView(),
      ),
      GoRoute(
        path: termsAndConditions,
        name: 'termsAndConditions',
        builder: (context, state) => const TermsAndConditionsView(),
      ),
      GoRoute(
        path: privacyPolicy,
        name: 'privacyPolicy',
        builder: (context, state) => const PrivacyPolicyView(),
      ),
    ],

    // Error Handler
    errorBuilder: (context, state) => ErrorView(error: state.error),

    // Redirect Logic (e.g., authentication)
    redirect: (context, state) {
      // Authentication redirect logic: guest browsing enabled without forced login redirect
      // Check if user is logged in, redirect to login if not
      // Example:
      // final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
      // final isGoingToAuth = state.matchedLocation.startsWith('/login') ||
      //     state.matchedLocation.startsWith('/register');
      //
      // if (!isLoggedIn && !isGoingToAuth) {
      //   return AppRouter.login;
      // }
      //
      // if (isLoggedIn && isGoingToAuth) {
      //   return AppRouter.navigation;
      // }

      return null; // No redirect
    });
}

// Placeholder Views - Replace these with actual implementations
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final updateService = AppUpdateService();

      // Run minimum splash presentation and version check concurrently
      final results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 1800)),
        updateService.checkUpdate(),
      ]);

      if (!mounted) return;

      final updateResult = results[1] as AppUpdateCheckResult;

      // Update maintenance provider state for global app availability
      if (updateResult.maintenance != null) {
        ref.read(appMaintenanceProvider.notifier).state = updateResult.maintenance;
      }

      if (updateResult.hasUpdate) {
        // App is not on the latest version -> show popup dialog
        await AppUpdateDialog.show(
          context,
          updateResult: updateResult,
          onDismiss: () {
            if (mounted) {
              context.go(AppRouter.navigation);
            }
          },
        );
      } else if (updateResult.maintenance?.isActive == true) {
        // Mode Maintenance / Persiapan Rilis Aktif -> tampilkan pop-up maintenance (Pilihan 1)
        await AppMaintenanceDialog.show(
          context,
          maintenance: updateResult.maintenance!,
          onDismiss: () {
            if (mounted) {
              context.go(AppRouter.navigation);
            }
          },
        );
      } else {
        if (mounted) context.go(AppRouter.navigation);
      }
    } catch (e) {
      debugPrint('⚠️ Splash version check failed: $e');
      if (mounted) context.go(AppRouter.navigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDD2222), Color(0xFFB01C1C)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logoApp.png',
                            width: 180,
                            height: 190,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            'Delitopia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                          const Text(
                            'Order Your Favorite Food',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                          const SizedBox(height: 36),
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Remaining placeholder views that don't have dedicated files yet

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFDD2222), Color(0xFFB01C1C)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.white,
                              child:
                                  Icon(Icons.person, color: Color(0xFFDD2222)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome Back!',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Guest User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  context.go(AppRouter.notifications),
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search for food...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: null,
                      // QR Scanner shortcut hidden from the Home dashboard for now.
                      // Keep AppRouter.qrScanner and QRScannerView available for future use.
                      // suffixIcon: IconButton(
                      //   icon: const Icon(Icons.qr_code_scanner),
                      //   onPressed: () => context.go(AppRouter.qrScanner),
                      // ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Categories
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCategoryCard('All', Icons.restaurant_menu),
                      _buildCategoryCard('Main Course', Icons.lunch_dining),
                      _buildCategoryCard('Appetizer', Icons.ramen_dining),
                      _buildCategoryCard('Dessert', Icons.cake),
                      _buildCategoryCard('Drinks', Icons.local_drink),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Popular Items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Popular Items',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) => _buildProductCard(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ));
  }

  Widget _buildCategoryCard(String label, IconData icon) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: const Color(0xFFDD2222)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ));
  }

  Widget _buildProductCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(
              child: Icon(Icons.fastfood, size: 48, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    const Text('4.5', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      'Rp 25.000',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDD2222),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ));
  }
}

class TrackOrderView extends StatelessWidget {
  final String orderId;
  const TrackOrderView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Track Order View')));
  }
}

class ErrorView extends StatelessWidget {
  final Exception? error;
  const ErrorView({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final isIndo = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  isIndo ? 'Halaman Tidak Ditemukan' : 'Page Not Found',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ??
                      (isIndo
                          ? 'Halaman yang Anda cari tidak ditemukan.'
                          : 'The page you are looking for does not exist.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRouter.home),
                  child: Text(isIndo ? 'Kembali ke Beranda' : 'Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
