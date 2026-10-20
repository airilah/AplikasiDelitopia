import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_language.dart';
import '../models/onboarding_model.dart';

/// Service to manage onboarding and feature tour state
class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyFeatureTourPrefix = 'feature_tour_';
  static const String _keySkippedOnboarding = 'skipped_onboarding';

  /// Check if user has completed initial onboarding
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Mark initial onboarding as completed
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// Mark onboarding as skipped
  Future<void> skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkippedOnboarding, true);
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// Check if user skipped onboarding
  Future<bool> hasSkippedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySkippedOnboarding) ?? false;
  }

  /// Check if a specific feature tour has been completed
  Future<bool> hasCompletedFeatureTour(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyFeatureTourPrefix$featureKey') ?? false;
  }

  /// Mark a specific feature tour as completed
  Future<void> completeFeatureTour(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyFeatureTourPrefix$featureKey', true);
  }

  /// Reset all onboarding progress (for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove(_keySkippedOnboarding);

    // Remove all feature tours
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyFeatureTourPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Reset a specific feature tour
  Future<void> resetFeatureTour(String featureKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyFeatureTourPrefix$featureKey');
  }

  /// Reset all feature tours but keep onboarding status
  Future<void> resetAllTours() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyFeatureTourPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Get list of completed feature tours
  Future<List<String>> getCompletedFeatureTours() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    return keys
        .where((key) => key.startsWith(_keyFeatureTourPrefix))
        .where((key) => prefs.getBool(key) ?? false)
        .map((key) => key.replaceFirst(_keyFeatureTourPrefix, ''))
        .toList();
  }

  /// Get onboarding steps
  List<OnboardingStep> getOnboardingSteps(
      [AppLanguage lang = AppLanguage.indonesia]) {
    return [
      OnboardingStep(
        title: tr.get('onboarding_welcome_title', lang),
        description: tr.get('onboarding_welcome_desc', lang),
        image: 'assets/images/onboarding_welcome.png',
      ),
      OnboardingStep(
        title: tr.get('onboarding_menu_title', lang),
        description: tr.get('onboarding_menu_desc', lang),
        image: 'assets/images/onboarding_menu.png',
      ),
      OnboardingStep(
        title: tr.get('onboarding_points_title', lang),
        description: tr.get('onboarding_points_desc', lang),
        image: 'assets/images/onboarding_points.png',
      ),
      OnboardingStep(
        title: tr.get('onboarding_vouchers_title', lang),
        description: tr.get('onboarding_vouchers_desc', lang),
        image: 'assets/images/onboarding_vouchers.png',
      ),
      OnboardingStep(
        title: tr.get('onboarding_order_title', lang),
        description: tr.get('onboarding_order_desc', lang),
        image: 'assets/images/onboarding_order.png',
        action: OnboardingAction(
          label: tr.get('start', lang),
          route: '/navigation',
        ),
      ),
    ];
  }

  /// Get feature tour steps for a specific feature
  List<TourSpotlight> getFeatureTourSpotlights(
    String featureKey, [
    AppLanguage lang = AppLanguage.indonesia,
  ]) {
    switch (featureKey) {
      case 'home':
        return [
          TourSpotlight(
            targetKey: 'home_points_card',
            title: tr.get('tour_home_points_title', lang),
            description: tr.get('tour_home_points_desc', lang),
            order: 1,
          ),
          TourSpotlight(
            targetKey: 'home_brands',
            title: tr.get('tour_home_brands_title', lang),
            description: tr.get('tour_home_brands_desc', lang),
            order: 2,
          ),
          TourSpotlight(
            targetKey: 'home_popular',
            title: tr.get('tour_home_popular_title', lang),
            description: tr.get('tour_home_popular_desc', lang),
            order: 3,
          ),
        ];

      case 'vouchers':
        return [
          TourSpotlight(
            targetKey: 'vouchers_points_card',
            title: tr.get('tour_vouchers_points_title', lang),
            description: tr.get('tour_vouchers_points_desc', lang),
            order: 1,
          ),
          TourSpotlight(
            targetKey: 'vouchers_free_section',
            title: tr.get('tour_vouchers_free_title', lang),
            description: tr.get('tour_vouchers_free_desc', lang),
            order: 2,
          ),
          TourSpotlight(
            targetKey: 'vouchers_point_section',
            title: tr.get('tour_vouchers_point_title', lang),
            description: tr.get('tour_vouchers_point_desc', lang),
            order: 3,
          ),
        ];

      case 'menu':
        return [
          TourSpotlight(
            targetKey: 'menu_search',
            title: tr.get('tour_menu_search_title', lang),
            description: tr.get('tour_menu_search_desc', lang),
            order: 1,
          ),
          TourSpotlight(
            targetKey: 'menu_categories',
            title: tr.get('tour_menu_categories_title', lang),
            description: tr.get('tour_menu_categories_desc', lang),
            order: 2,
          ),
          TourSpotlight(
            targetKey: 'menu_add_to_cart',
            title: tr.get('tour_menu_cart_title', lang),
            description: tr.get('tour_menu_cart_desc', lang),
            order: 3,
          ),
        ];

      case 'cart':
        return [
          TourSpotlight(
            targetKey: 'cart_items',
            title: tr.get('tour_cart_items_title', lang),
            description: tr.get('tour_cart_items_desc', lang),
            order: 1,
          ),
          TourSpotlight(
            targetKey: 'cart_voucher',
            title: tr.get('tour_cart_voucher_title', lang),
            description: tr.get('tour_cart_voucher_desc', lang),
            order: 2,
          ),
          TourSpotlight(
            targetKey: 'cart_checkout',
            title: tr.get('tour_cart_checkout_title', lang),
            description: tr.get('tour_cart_checkout_desc', lang),
            order: 3,
          ),
        ];

      case 'profile':
        return [
          TourSpotlight(
            targetKey: 'profile_points',
            title: tr.get('tour_profile_points_title', lang),
            description: tr.get('tour_profile_points_desc', lang),
            order: 1,
          ),
          TourSpotlight(
            targetKey: 'profile_orders',
            title: tr.get('tour_profile_orders_title', lang),
            description: tr.get('tour_profile_orders_desc', lang),
            order: 2,
          ),
          TourSpotlight(
            targetKey: 'profile_addresses',
            title: tr.get('tour_profile_addresses_title', lang),
            description: tr.get('tour_profile_addresses_desc', lang),
            order: 3,
          ),
        ];

      default:
        return [];
    }
  }
}
