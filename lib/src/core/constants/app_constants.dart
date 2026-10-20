/// App-wide constants for Delitopia V2
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Delitopia';
  static const String appVersion = '2.1.8';
  static const int appBuildNumber = 31;
  static const String appTagline = 'Order Your Favorite Food';
  static const String playStorePackage = 'com.delitopia.softindo';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.delitopia.softindo';
  static const String marketUrl =
      'market://details?id=com.delitopia.softindo';

  // Shared Preferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserAvatar = 'user_avatar';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyThemeMode = 'theme_mode';
  static const String keyDarkMode = 'dark_mode';
  static const String keyLanguage = 'language';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyFcmToken = 'fcm_token';
  static const String keyFcmRegistrationRevision = 'fcm_registration_revision';

  // Hive Box Names
  static const String boxCart = 'cart_box';
  static const String boxFavorites = 'favorites_box';
  static const String boxAddress = 'address_box';
  static const String boxOrderHistory = 'order_history_box';
  static const String boxSettings = 'settings_box';

  // Pagination
  static const int itemsPerPage = 20;
  static const int maxCacheAge = 300; // 5 minutes in seconds

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int phoneNumberLength = 10;

  // Timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;

  // Map Config
  static const double defaultLatitude = -6.2088; // Jakarta
  static const double defaultLongitude = 106.8456;
  static const double defaultZoom = 15.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  static const int locationUpdateInterval = 5000; // milliseconds

  // Order Status
  static const String orderPending = 'pending';
  static const String orderConfirmed = 'confirmed';
  static const String orderPreparing = 'preparing';
  static const String orderReady = 'ready';
  static const String orderDelivering = 'delivering';
  static const String orderCompleted = 'completed';
  static const String orderCancelled = 'cancelled';

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentEWallet = 'e_wallet';
  static const String paymentQR = 'qr_code';

  // Image Config
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 85;
  static const double maxImageWidth = 1920;
  static const double maxImageHeight = 1080;

  // Animation Durations (in milliseconds)
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Carousel
  static const int autoPlayInterval = 5000; // milliseconds
  static const Duration autoPlayDelay =
      Duration(milliseconds: autoPlayInterval);

  // Search
  static const int minSearchLength = 2;
  static const int searchDebounceTime = 500; // milliseconds

  // Notifications
  static const String notificationChannelId = 'delitopia_notifications';
  static const String notificationChannelName = 'Delitopia Notifications';
  static const String notificationChannelDescription =
      'Notifications for orders, offers, and updates';

  // Social Media
  static const String facebookUrl = 'https://facebook.com/delitopia';
  static const String instagramUrl = 'https://instagram.com/delitopia';
  static const String twitterUrl = 'https://twitter.com/delitopia';
  static const String websiteUrl = 'https://delitopia.com';

  // Support
  static const String supportEmail = 'support@delitopia.com';
  static const String supportPhone = '+62-123-456-7890';
  static const String whatsappNumber = '62123456789';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Network error. Please check your connection.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorUnauthorized =
      'Session expired. Please login again.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorServerError =
      'Server error. Please try again later.';

  // Success Messages
  static const String successLogin = 'Logged in successfully!';
  static const String successRegister = 'Account created successfully!';
  static const String successOrderPlaced = 'Order placed successfully!';
  static const String successItemAddedToCart = 'Item added to cart!';
  static const String successItemRemovedFromCart = 'Item removed from cart!';

  // Currency
  static const String currencySymbol = 'Rp';
  static const String currencyCode = 'IDR';
  static const String currencyLocale = 'id_ID';

  // Date Formats
  static const String dateFormatFull = 'EEEE, dd MMMM yyyy';
  static const String dateFormatShort = 'dd/MM/yyyy';
  static const String dateFormatMedium = 'dd MMM yyyy';
  static const String timeFormat12Hour = 'hh:mm a';
  static const String timeFormat24Hour = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
}
