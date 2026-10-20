import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/storage_service.dart';

class NotificationPreferenceKeys {
  NotificationPreferenceKeys._();

  static const enabled = 'notifications_enabled';
  static const orderUpdates = 'order_updates';
  static const promotions = 'promotions';
  static const sound = 'sound_enabled';
  static const vibration = 'vibration_enabled';

  static const legacyPushEnabled = 'notif_push_enabled';
  static const legacyOrderUpdates = 'notif_order_updates';
  static const legacyPromotions = 'notif_promotions';
  static const legacyNewMenu = 'notif_new_menu';
  static const legacyRewards = 'notif_rewards';
  static const legacyDelivery = 'notif_delivery';
  static const legacyEmail = 'notif_email_enabled';
}

class NotificationPreferences {
  final bool enabled;
  final bool orderUpdates;
  final bool promotions;
  final bool sound;
  final bool vibration;
  final bool newMenuItems;
  final bool rewards;
  final bool deliveryUpdates;
  final bool emailEnabled;

  const NotificationPreferences({
    this.enabled = true,
    this.orderUpdates = true,
    this.promotions = true,
    this.sound = true,
    this.vibration = true,
    this.newMenuItems = true,
    this.rewards = true,
    this.deliveryUpdates = true,
    this.emailEnabled = true,
  });

  NotificationPreferences copyWith({
    bool? enabled,
    bool? orderUpdates,
    bool? promotions,
    bool? sound,
    bool? vibration,
    bool? newMenuItems,
    bool? rewards,
    bool? deliveryUpdates,
    bool? emailEnabled,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      newMenuItems: newMenuItems ?? this.newMenuItems,
      rewards: rewards ?? this.rewards,
      deliveryUpdates: deliveryUpdates ?? this.deliveryUpdates,
      emailEnabled: emailEnabled ?? this.emailEnabled);
  }

  static NotificationPreferences fromPrefs(SharedPreferences prefs) {
    bool readBool(List<String> keys, bool fallback) {
      for (final key in keys) {
        final value = prefs.getBool(key);
        if (value != null) return value;
      }
      return fallback;
    }

    return NotificationPreferences(
      enabled: readBool(
        [
          NotificationPreferenceKeys.enabled,
          NotificationPreferenceKeys.legacyPushEnabled,
        ],
        true,
      ),
      orderUpdates: readBool(
        [
          NotificationPreferenceKeys.orderUpdates,
          NotificationPreferenceKeys.legacyOrderUpdates,
        ],
        true,
      ),
      promotions: readBool(
        [
          NotificationPreferenceKeys.promotions,
          NotificationPreferenceKeys.legacyPromotions,
        ],
        true,
      ),
      sound: readBool([NotificationPreferenceKeys.sound], true),
      vibration: readBool([NotificationPreferenceKeys.vibration], true),
      newMenuItems: readBool([NotificationPreferenceKeys.legacyNewMenu], true),
      rewards: readBool([NotificationPreferenceKeys.legacyRewards], true),
      deliveryUpdates:
          readBool([NotificationPreferenceKeys.legacyDelivery], true),
      emailEnabled: readBool([NotificationPreferenceKeys.legacyEmail], true));
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesController, NotificationPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationPreferencesController(prefs);
});

class NotificationPreferencesController
    extends StateNotifier<NotificationPreferences> {
  final SharedPreferences _prefs;

  NotificationPreferencesController(this._prefs)
      : super(NotificationPreferences.fromPrefs(_prefs));

  Future<void> setEnabled(bool value) async {
    await _setBool(
      [
        NotificationPreferenceKeys.enabled,
        NotificationPreferenceKeys.legacyPushEnabled,
      ],
      value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setOrderUpdates(bool value) async {
    await _setBool(
      [
        NotificationPreferenceKeys.orderUpdates,
        NotificationPreferenceKeys.legacyOrderUpdates,
      ],
      value);
    state = state.copyWith(orderUpdates: value);
  }

  Future<void> setPromotions(bool value) async {
    await _setBool(
      [
        NotificationPreferenceKeys.promotions,
        NotificationPreferenceKeys.legacyPromotions,
      ],
      value);
    state = state.copyWith(promotions: value);
  }

  Future<void> setSound(bool value) async {
    await _setBool([NotificationPreferenceKeys.sound], value);
    state = state.copyWith(sound: value);
  }

  Future<void> setVibration(bool value) async {
    await _setBool([NotificationPreferenceKeys.vibration], value);
    state = state.copyWith(vibration: value);
  }

  Future<void> setNewMenuItems(bool value) async {
    await _setBool([NotificationPreferenceKeys.legacyNewMenu], value);
    state = state.copyWith(newMenuItems: value);
  }

  Future<void> setRewards(bool value) async {
    await _setBool([NotificationPreferenceKeys.legacyRewards], value);
    state = state.copyWith(rewards: value);
  }

  Future<void> setDeliveryUpdates(bool value) async {
    await _setBool([NotificationPreferenceKeys.legacyDelivery], value);
    state = state.copyWith(deliveryUpdates: value);
  }

  Future<void> setEmailEnabled(bool value) async {
    await _setBool([NotificationPreferenceKeys.legacyEmail], value);
    state = state.copyWith(emailEnabled: value);
  }

  Future<void> _setBool(List<String> keys, bool value) async {
    for (final key in keys) {
      await _prefs.setBool(key, value);
    }
  }
}
