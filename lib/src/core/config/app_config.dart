import 'dart:io';

/// App configuration for production/development
class AppConfig {
  /// Environment type
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development');

  /// Is production environment
  static bool get isProduction => environment == 'production';

  /// Is development environment
  static bool get isDevelopment => environment == 'development';

  /// API Base URL
  static String get apiBaseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://aplikasi.mannagroup.id/api');
  }

  /// API timeout duration
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Cache duration
  static const Duration cacheValidDuration = Duration(hours: 1);

  /// Image cache max age
  static const Duration imageCacheMaxAge = Duration(days: 7);

  /// Max image cache size (in MB)
  static const int maxImageCacheSize = 100;

  /// Enable logging
  static bool get enableLogging => isDevelopment;

  /// Enable analytics
  static bool get enableAnalytics => isProduction;

  /// App version
  static const String appVersion = '2.1.8';

  /// Minimum supported app version
  static const String minSupportedVersion = '2.0.0';

  /// Force update required
  static bool get forceUpdateRequired => false;

  /// Feature flags
  static const bool enablePushNotifications = true;
  static const bool enableInAppPurchase = false;
  static const bool enableSocialLogin = true;
  static const bool enableGrabDelivery = true;
  static const bool enableVoucherSystem = true;
  static const bool enablePointsSystem = true;

  static const String googleMapsApiKeyAndroid = 'AIzaSyCB2S6ipwUFHOnm93jIWqJS-H2AKkDSRH4';
  static const String googleMapsApiKeyIOS = 'AIzaSyCB2S6ipwUFHOnm93jIWqJS-H2AKkDSRH4';

  static String get googleMapsApiKey {
    if (Platform.isIOS) {
      return googleMapsApiKeyIOS;
    }
    return googleMapsApiKeyAndroid;
  }

  /// Firebase configuration (set in google-services.json/plist)
  static const bool enableFirebase = true;

  /// Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// Image quality
  static const int imageQuality = 85;
  static const int thumbnailQuality = 70;

  /// Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 350);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  /// Debounce durations
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration tapDebounce = Duration(milliseconds: 300);

  /// Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Default values
  static const String defaultCurrency = 'IDR';
  static const String defaultLanguage = 'id';
  static const String defaultCountryCode = '+62';

  /// Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 50;

  /// File upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];
}
