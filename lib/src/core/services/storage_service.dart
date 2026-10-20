import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs, const FlutterSecureStorage());
});

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String? _authToken;

  StorageService(this._prefs, this._secureStorage);

  /// Completes before the provider is exposed to the UI. This preserves the
  /// existing synchronous token reads while migrating legacy tokens once.
  Future<void> initialize() async {
    try {
      final secureToken =
          await _secureStorage.read(key: AppConstants.keyAuthToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        _authToken = secureToken;
        await _prefs.setString(AppConstants.keyAuthToken, secureToken);
        return;
      }

      final legacyToken = _prefs.getString(AppConstants.keyAuthToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _secureStorage.write(
          key: AppConstants.keyAuthToken,
          value: legacyToken,
        );
        _authToken = legacyToken;
      }
    } catch (_) {
      // Keep the current session usable if a device's secure storage is
      // temporarily unavailable; a later launch retries the migration.
      _authToken = _prefs.getString(AppConstants.keyAuthToken);
    }
  }

  // Auth Token
  Future<void> saveAuthToken(String token) async {
    _authToken = token;
    try {
      await _secureStorage.write(key: AppConstants.keyAuthToken, value: token);
    } catch (_) {}
    // Ensure SharedPreferences is always synchronized for backwards compatibility
    // with services and components that read the token directly.
    await _prefs.setString(AppConstants.keyAuthToken, token);
  }

  String? getAuthToken() {
    return _authToken;
  }

  Future<void> deleteAuthToken() async {
    _authToken = null;
    try {
      await _secureStorage.delete(key: AppConstants.keyAuthToken);
    } catch (_) {}
    await _prefs.remove(AppConstants.keyAuthToken);
  }

  // User ID
  Future<void> saveUserId(int userId) async {
    await _prefs.setInt(AppConstants.keyUserId, userId);
  }

  Future<int?> getUserId() async {
    return _prefs.getInt(AppConstants.keyUserId);
  }

  Future<void> deleteUserId() async {
    await _prefs.remove(AppConstants.keyUserId);
  }

  // FCM registration migration. Incrementing the revision lets the app rotate
  // a revoked legacy token once without generating a new token every launch.
  int getFcmRegistrationRevision() {
    return _prefs.getInt(AppConstants.keyFcmRegistrationRevision) ?? 0;
  }

  Future<void> saveFcmRegistrationRevision(int revision) async {
    await _prefs.setInt(AppConstants.keyFcmRegistrationRevision, revision);
  }

  // Keep the last token issued by Firebase. Google Play Services can
  // temporarily reject token refresh requests while the previous token is
  // still able to receive messages.
  Future<void> saveFcmToken(String token) async {
    await _prefs.setString(AppConstants.keyFcmToken, token);
  }

  String? getFcmToken() {
    final token = _prefs.getString(AppConstants.keyFcmToken)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  // User data
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs.setString(AppConstants.keyUserName, userData['name'] ?? '');
    await _prefs.setString(AppConstants.keyUserEmail, userData['email'] ?? '');
    await _prefs.setString(AppConstants.keyUserPhone, userData['phone'] ?? '');
    if (userData['point'] != null) {
      final pointVal = userData['point'] is int
          ? userData['point'] as int
          : int.tryParse(userData['point'].toString()) ?? 0;
      await _prefs.setInt('cached_user_point', pointVal);
    }
  }

  String? getCachedUserName() {
    return _prefs.getString(AppConstants.keyUserName);
  }

  Future<Map<String, String?>> getUserData() async {
    return {
      'name': _prefs.getString(AppConstants.keyUserName),
      'email': _prefs.getString(AppConstants.keyUserEmail),
      'phone': _prefs.getString(AppConstants.keyUserPhone),
      'point': _prefs.getInt('cached_user_point')?.toString(),
    };
  }

  // Onboarding
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(AppConstants.keyOnboardingComplete, true);
  }

  Future<bool> isOnboardingComplete() async {
    return _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  // Theme
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(AppConstants.keyDarkMode, isDark);
  }

  Future<bool> isDarkMode() async {
    return _prefs.getBool(AppConstants.keyDarkMode) ?? false;
  }

  // Notifications Read State
  Future<void> saveLastSeenNotificationTime(DateTime time) async {
    await _prefs.setString(
        'last_seen_notification_time', time.toIso8601String());
  }

  DateTime? getLastSeenNotificationTime() {
    final str = _prefs.getString('last_seen_notification_time');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // Deleted Notifications
  List<String> getDeletedNotificationKeys() {
    return _prefs.getStringList('deleted_notification_keys') ?? [];
  }

  Future<void> addDeletedNotificationKey(String key) async {
    final list = _prefs.getStringList('deleted_notification_keys') ?? [];
    if (!list.contains(key)) {
      list.add(key);
      await _prefs.setStringList('deleted_notification_keys', list);
    }
  }

  Future<void> removeDeletedNotificationKey(String key) async {
    final list = _prefs.getStringList('deleted_notification_keys') ?? [];
    if (list.contains(key)) {
      list.remove(key);
      await _prefs.setStringList('deleted_notification_keys', list);
    }
  }

  Future<void> addAllDeletedNotificationKeys(Iterable<String> keys) async {
    final list = _prefs.getStringList('deleted_notification_keys') ?? [];
    final set = list.toSet()..addAll(keys);
    await _prefs.setStringList('deleted_notification_keys', set.toList());
  }

  Future<void> removeAllDeletedNotificationKeys(Iterable<String> keys) async {
    final list = _prefs.getStringList('deleted_notification_keys') ?? [];
    final set = list.toSet()..removeAll(keys);
    await _prefs.setStringList('deleted_notification_keys', set.toList());
  }

  Future<void> clearDeletedNotificationKeys() async {
    await _prefs.remove('deleted_notification_keys');
  }

  // Showcase Catalog Cache for Instant Cold Start & SWR
  static const String keyShowcaseCatalogCache = 'showcase_catalog_cache_v2';

  Future<void> saveShowcaseCatalog(String jsonString) async {
    await _prefs.setString(keyShowcaseCatalogCache, jsonString);
  }

  String? getShowcaseCatalog() {
    return _prefs.getString(keyShowcaseCatalogCache);
  }

  // Clear all data (logout)
  Future<void> clearAll() async {
    final onboardingComplete =
        _prefs.getBool(AppConstants.keyOnboardingComplete);
    final isDarkMode = _prefs.getBool(AppConstants.keyDarkMode);
    final fcmRegistrationRevision =
        _prefs.getInt(AppConstants.keyFcmRegistrationRevision);

    _authToken = null;
    try {
      await _secureStorage.delete(key: AppConstants.keyAuthToken);
    } catch (_) {}
    await _prefs.clear();
    if (onboardingComplete != null) {
      await _prefs.setBool(
          AppConstants.keyOnboardingComplete, onboardingComplete);
    }
    if (isDarkMode != null) {
      await _prefs.setBool(AppConstants.keyDarkMode, isDarkMode);
    }
    if (fcmRegistrationRevision != null) {
      await _prefs.setInt(
        AppConstants.keyFcmRegistrationRevision,
        fcmRegistrationRevision,
      );
    }

    await Hive.box(AppConstants.boxCart).clear();
    await Hive.box(AppConstants.boxFavorites).clear();
  }

  // Hive boxes
  Box get cartBox => Hive.box(AppConstants.boxCart);
  Box get favoritesBox => Hive.box(AppConstants.boxFavorites);
  Box get addressBox => Hive.box(AppConstants.boxAddress);
  Box get orderHistoryBox => Hive.box(AppConstants.boxOrderHistory);
}
