/// API endpoints and configuration
class ApiConstants {
  ApiConstants._();

  // Production API base. Override with --dart-define only when intentionally testing another backend.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://aplikasi.mannagroup.id/api');

  static const String socketUrl = String.fromEnvironment('SOCKET_URL',
      defaultValue: 'wss://aplikasi.mannagroup.id');

  // API Version
  static const String apiVersion = 'v2';

  // Auth Endpoints
  static const String login = '/v2/auth/login';
  static const String legacyLogin = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyOtp = '/v2/auth/phone/verify';
  static const String legacyVerifyOtp = '/auth/phone/verify';
  static const String resendOtp = '/auth/resend-otp';
  static const String requestPhoneOtp = '/v2/auth/phone/request-otp';
  static const String legacyRequestPhoneOtp = '/auth/phone/request-otp';
  static const String completePhoneProfile = '/v2/users/profile/complete';
  static const String sendEmailVerification =
      '/v2/users/email/send-verification';
  static const String verifyEmail = '/v2/users/email/verify';
  static const String requestProfilePhoneOtp = '/v2/users/phone/request-otp';
  static const String verifyProfilePhone = '/v2/users/phone/verify';
  static const String setPassword = '/v2/users/password';
  static const String socialLogin = '/auth/social-login';
  static const String changePassword = '/auth/change-password';

  // User Endpoints
  static const String userProfile = '/user/profile';
  static const String updateProfile = '/user/profile/update';
  static const String uploadProfileImage = '/user/profile/image';
  static const String deleteAccount = '/user/account/delete';

  // Address Endpoints
  static const String addresses = '/user/addresses';
  static const String addAddress = '/user/addresses/add';
  static const String updateAddress = '/user/addresses/update';
  static const String deleteAddress = '/user/addresses/delete';
  static const String setDefaultAddress = '/user/addresses/set-default';

  // Home Endpoints
  static const String home = '/home';
  static const String banners = '/getData/banner';
  static const String categories = '/getData/kategori';
  static const String featuredProducts = '/home/featured';
  static const String popularProducts = '/getData/menu/popular';
  static const String showcaseProducts = '/getData/menu/showcase';
  static const String recommendations = '/home/recommendations';

  // Product/Menu Endpoints
  static const String products = '/products';
  static const String productDetails = '/products'; // append /{id}
  static const String searchProducts = '/products/search';
  static const String filterProducts = '/products/filter';
  static const String productsByCategory =
      '/products/category'; // append /{categoryId}
  static const String productReviews =
      '/products/reviews'; // append /{productId}
  static const String addReview = '/products/reviews/add';

  // Category Endpoints
  static const String categoryList = '/categories';
  static const String categoryDetails = '/categories'; // append /{id}

  // Cart Endpoints (if using server-side cart)
  static const String cart = '/cart';
  static const String addToCart = '/cart/add';
  static const String updateCartItem = '/cart/update';
  static const String removeFromCart = '/cart/remove';
  static const String clearCart = '/cart/clear';
  static const String cartCount = '/cart/count';

  // Order Endpoints
  static const String orders = '/orders';
  static const String ordersWithDelivery = '/orders/b';
  static const String ordersShow = '/orders/show';
  static const String ordersMarkPaid = '/orders/mark-paid';
  static const String ordersUpdateStatus = '/orders/update-status';
  static const String ordersPoint = '/orders/point';
  static const String ordersHistoryPoint = '/orders/history-point';

  // Points Endpoints
  static const String getUserPoints = '/getData/points';
  static const String getPointsSummary = '/getData/points/summary';
  static const String getPointsHistory = '/getData/historyPoint';
  static const String placeOrder = '/orders/place';
  static const String orderDetails = '/orders'; // append /{orderId}
  static const String orderHistory = '/orders/history';
  static const String activeOrders = '/orders/active';
  static const String cancelOrder = '/orders/cancel'; // append /{orderId}
  static const String trackOrder = '/orders/track'; // append /{orderId}
  static const String reorder = '/orders/reorder'; // append /{orderId}
  static const String orderRating = '/orders/rate';

  // Payment Endpoints
  static const String paymentMethods = '/payments/methods';
  static const String initiatePayment = '/payments/initiate';
  static const String verifyPayment = '/payments/verify';
  static const String paymentHistory = '/payments/history';

  // Voucher/Coupon Endpoints
  static const String vouchers =
      '/getData/voucher'; // Get all available vouchers
  static const String voucherShow = '/getData/voucher-show'; // append /{id}
  static const String pointRedemptionVouchers =
      '/getData/vouchers/point-redemption';
  static const String cashPurchaseVouchers = '/getData/vouchers/cash-purchase';
  static const String myVouchers = '/getData/my-vouchers';
  static const String myActiveVouchers = '/getData/my-active-vouchers';
  static const String redeemVoucherPoints = '/postData/vouchers/redeem-points';
  static const String purchaseVoucherCash = '/postData/vouchers/purchase-cash';
  static const String activateVoucher = '/postData/voucher-activate';
  static const String validateVoucherUsage = '/getData/vouchers/validate-usage';
  static const String voucherUsageHistory = '/getData/vouchers/usage-history';
  static const String useVoucher = '/postData/use-voucher-api';
  static const String allVouchersCategorized =
      '/postData/vouchers/all-categorized';
  static const String birthdayVoucher = '/api/birthday-voucher';

  // Notification Endpoints
  static const String notifications = '/getData/notification';
  static const String markNotificationRead =
      '/notifications/read'; // append /{id}
  static const String markAllNotificationsRead = '/notifications/read-all';
  static const String deleteNotification =
      '/notifications/delete'; // append /{id}
  static const String notificationPreferences = '/notifications/preferences';
  static const String updateFcmToken = '/notifications/fcm-token';

  // Favorites/Wishlist Endpoints
  static const String favorites = '/favorites';
  static const String addToFavorites = '/favorites/add';
  static const String removeFromFavorites = '/favorites/remove';
  static const String isFavorite = '/favorites/check'; // append /{productId}

  // Store/Restaurant Endpoints
  static const String stores = '/stores';
  static const String storeDetails = '/stores'; // append /{id}
  static const String nearbyStores = '/stores/nearby';
  static const String storeMenu = '/stores/menu'; // append /{id}
  static const String storeReviews = '/stores/reviews'; // append /{id}

  // QR Code Endpoints
  static const String scanQr = '/qr/scan';
  static const String generateQr = '/qr/generate';
  static const String validateQr = '/qr/validate';

  // Support Endpoints
  static const String helpCenter = '/support/help';
  static const String contactSupport = '/support/contact';
  static const String faq = '/support/faq';
  static const String reportIssue = '/support/report';

  // Settings Endpoints
  static const String appSettings = '/settings/app';
  static const String userSettings = '/settings/user';
  static const String updateSettings = '/settings/update';
  static const String appVersion = '/v2/app/version';
  static const String legacyAppVersion = '/app-version';

  // Search Endpoints
  static const String search = '/search';
  static const String searchSuggestions = '/search/suggestions';
  static const String searchHistory = '/search/history';
  static const String clearSearchHistory = '/search/history/clear';

  // Analytics Endpoints
  static const String logEvent = '/analytics/event';
  static const String logScreenView = '/analytics/screen';

  // Content Endpoints
  static const String termsAndConditions = '/content/terms';
  static const String privacyPolicy = '/content/privacy';
  static const String aboutUs = '/content/about';

  // Helper method to construct full URL
  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }

  // Helper method for parameterized endpoints
  static String withId(String endpoint, String id) {
    return '$endpoint/$id';
  }

  // Helper method for query parameters
  static String withParams(String endpoint, Map<String, dynamic> params) {
    if (params.isEmpty) return endpoint;

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    return '$endpoint?$queryString';
  }
}
