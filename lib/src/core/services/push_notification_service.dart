import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../routes/app_router.dart';
import 'storage_service.dart';
import 'notification_router.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/order/controllers/order_controller.dart';
import '../../shared/services/service_providers.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔔 Background message received: ${message.messageId}");
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  static const int _fcmRegistrationRevision = 2;
  static const String _customChannelId = 'delitopia_order_channel_v6';
  static const String _defaultChannelId = 'delitopia_order_channel_v4';
  static const String _silentChannelId = 'delitopia_silent_channel_v1';
  static const MethodChannel _nativeFcmCache =
      MethodChannel('com.delitopia.aplikasi/fcm_cache');
  static const List<Duration> _tokenRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
  ];

  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Map<String, DateTime> _handledEvents = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastSoundPlayed;
  Timer? _tokenRetryTimer;
  int _tokenRetryAttempt = 0;
  bool _tokenUploadInProgress = false;

  bool _isInitialized = false;

  PushNotificationService(this._ref);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Set background messaging handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 2. Request permissions
      final notificationSettings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint(
          'Notification permission: ${notificationSettings.authorizationStatus.name}');

      // Apple requires an APNs token before FCM token/topic operations. Keep
      // the wait bounded so a network problem never blocks app startup.
      await _waitForApnsTokenIfNeeded();

      // Enable foreground notification presentation options
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
      } catch (e) {
        debugPrint('Note on setForegroundNotificationPresentationOptions: $e');
      }

      // 3. Initialize Flutter Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          final payload = details.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final data = jsonDecode(payload) as Map<String, dynamic>;
              _handleNotificationTapWithData(data);
            } catch (e) {
              debugPrint('⚠️ Error parsing notification payload: $e');
            }
          }
        },
      );

      // 4. Create Android high-importance channels. Channel sound is
      // immutable on Android, so v6 deliberately uses a new identifier.
      final androidPlugin =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Explicitly request notification permissions on Android 13+ (TIRAMISU+)
      try {
        await androidPlugin?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('Note on requestNotificationsPermission: $e');
      }

      const AndroidNotificationChannel channelV6 = AndroidNotificationChannel(
        _customChannelId,
        'Notifikasi Delitopia',
        description:
            'Notifikasi pelanggan Delitopia dengan suara resmi Delitopia.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('delitopia'),
        enableVibration: true,
        showBadge: true,
      );

      // Keep the default-sound channel for rolling deployment compatibility.
      const AndroidNotificationChannel channelV4 = AndroidNotificationChannel(
        _defaultChannelId,
        'Notifikasi Delitopia',
        description:
            'Notifikasi status pesanan, pembayaran, voucher, dan promo Delitopia.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const AndroidNotificationChannel silentChannel =
          AndroidNotificationChannel(
        _silentChannelId,
        'Notifikasi Delitopia Tanpa Suara',
        description: 'Notifikasi Delitopia tanpa audio.',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
        showBadge: true,
      );

      // Keep legacy channels registered for notifications sent by an older
      // backend during a rolling deployment.
      const AndroidNotificationChannel channelV3 = AndroidNotificationChannel(
        'delitopia_order_channel_v3',
        'Notifikasi Delitopia',
        description:
            'Notifikasi status pesanan, pembayaran, dan promo Delitopia dengan suara resmi.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('delitopia'),
        enableVibration: true,
        showBadge: true,
      );

      // Register legacy v2 and v1 channels so existing notifications targeting either channel show properly
      const AndroidNotificationChannel channelV2 = AndroidNotificationChannel(
        'delitopia_order_channel_v2',
        'Notifikasi Pesanan Delitopia',
        description:
            'Notifikasi status pesanan, pembayaran, dan promo Delitopia dengan suara resmi.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('delitopia'),
        enableVibration: true,
        showBadge: true,
      );

      const AndroidNotificationChannel channelV1 = AndroidNotificationChannel(
        'delitopia_order_channel_v1',
        'Notifikasi Delitopia V1',
        description: 'Notifikasi pesanan dan voucher Delitopia.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('delitopia'),
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin?.createNotificationChannel(channelV6);
      await androidPlugin?.createNotificationChannel(channelV4);
      await androidPlugin?.createNotificationChannel(silentChannel);
      await androidPlugin?.createNotificationChannel(channelV3);
      await androidPlugin?.createNotificationChannel(channelV2);
      await androidPlugin?.createNotificationChannel(channelV1);

      // 5. Subscribe to broadcast topics
      await _subscribeToBroadcastTopics();

      // 6. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final eventId = (message.data['event_id'] ??
                message.data['notification_id'] ??
                message.messageId)
            ?.toString();
        if (!_acceptEvent(eventId)) return;
        debugPrint(
            '🔔 Foreground FCM message: ${message.notification?.title ?? message.data['title']}');

        // Auto refresh in-app notifications provider so UI updates instantly
        _ref.invalidate(notificationsProvider);
        _ref.invalidate(hasUnreadNotificationsProvider);

        final rawTitle = message.notification?.title?.trim() ??
            message.data['title']?.toString().trim();
        final rawBody = message.notification?.body?.trim() ??
            message.data['body']?.toString().trim();

        final orderId =
            (message.data['order_id'] ?? message.data['id_order'])?.toString();
        final type =
            (message.data['type'] ?? message.data['type_data'])?.toString();

        // If this notification belongs to an order, invalidate the active order details immediately
        if (orderId != null && orderId.isNotEmpty) {
          _ref.invalidate(orderDetailsProvider(orderId));
          _ref.read(storageServiceProvider).getUserId().then((userId) {
            if (userId != null) {
              _ref.invalidate(activeOrdersProvider(userId));
            }
          });
        }

        // Silent / data-only message: if there is no actual content (both title & body are empty),
        // do not display a blank or fake "Notifikasi Baru" notification to the user.
        final hasTitle = rawTitle != null && rawTitle.isNotEmpty;
        final hasBody = rawBody != null && rawBody.isNotEmpty;
        if (!hasTitle && !hasBody) {
          debugPrint(
              '🔇 Silent / Data-only FCM message received; UI refreshed without alert banner.');
          return;
        }

        final title = hasTitle ? rawTitle : 'Delitopia';
        final body = hasBody ? rawBody : '';

        // Show system notification & in-app banner
        await showLocalNotification(
          title: title,
          body: body,
          orderId: orderId,
          type: type,
          category: message.data['category']?.toString(),
          templateKey: message.data['template_key']?.toString(),
          actionUrl: message.data['action_url']?.toString(),
          eventId: eventId,
          sound: message.data['sound']?.toString(),
          data: message.data,
        );
      });

      // 7. Handle notification click when app is running in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification opened app: ${message.data}');
        _handleNotificationTapWithData(message.data);
      });

      // 8. Handle notification click when app is launched from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App launched from notification: ${initialMessage.data}');
        _handleNotificationTapWithData(initialMessage.data);
      }

      // 9. Upload FCM token if logged in
      await uploadToken();
      _fcm.onTokenRefresh.listen((token) async {
        await uploadToken(token);
        await _subscribeToBroadcastTopics();
      });

      _isInitialized = true;
      debugPrint('✅ PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('⚠️ PushNotificationService initialization failed: $e');
    }
  }

  Future<void> _waitForApnsTokenIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        if (await _fcm.getAPNSToken() != null) return;
      } catch (e) {
        debugPrint('Waiting for APNs token: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    debugPrint(
        'APNs token is not ready; FCM registration will retry on token refresh.');
  }

  Future<void> _subscribeToBroadcastTopics() async {
    try {
      await _fcm.subscribeToTopic('promo');
      await _fcm.subscribeToTopic('all');
      await _fcm.subscribeToTopic('general');
      debugPrint('✅ Subscribed to FCM topics: promo, all, general');
    } catch (e) {
      debugPrint('⚠️ Failed to subscribe to FCM topics: $e');
    }
  }

  Future<bool> uploadToken([String? refreshedToken]) async {
    if (_tokenUploadInProgress) return false;
    _tokenUploadInProgress = true;

    try {
      final token = await _resolveFcmToken(refreshedToken);
      if (token == null) {
        _scheduleTokenRetry();
        return false;
      }

      debugPrint('🔑 FCM token retrieved (${token.length} characters)');

      final userId = await _ref.read(storageServiceProvider).getUserId();
      if (userId != null) {
        await _ref.read(authServiceProvider).updateFcmToken(userId, token);
        await _ref
            .read(storageServiceProvider)
            .saveFcmRegistrationRevision(_fcmRegistrationRevision);
        _tokenRetryTimer?.cancel();
        _tokenRetryAttempt = 0;
        debugPrint('✅ FCM Token uploaded successfully for User ID $userId');
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to upload FCM token: $e');
      _scheduleTokenRetry();
      return false;
    } finally {
      _tokenUploadInProgress = false;
    }
  }

  Future<String?> _resolveFcmToken(String? refreshedToken) async {
    final storage = _ref.read(storageServiceProvider);
    final suppliedToken = refreshedToken?.trim();
    if (suppliedToken != null && suppliedToken.isNotEmpty) {
      await storage.saveFcmToken(suppliedToken);
      return suppliedToken;
    }

    try {
      final firebaseToken =
          (await _fcm.getToken().timeout(const Duration(seconds: 8)))?.trim();
      if (firebaseToken != null && firebaseToken.isNotEmpty) {
        await storage.saveFcmToken(firebaseToken);
        return firebaseToken;
      }
    } catch (e) {
      debugPrint('FCM token refresh unavailable; using safe cache: $e');
    }

    final cachedToken = storage.getFcmToken();
    if (cachedToken != null) return cachedToken;

    // One-time migration for builds that predate Delitopia's app-owned token
    // cache. This reads only this app's private Firebase preferences.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativeCachedToken =
            (await _nativeFcmCache.invokeMethod<String>('getCachedFcmToken'))
                ?.trim();
        if (nativeCachedToken != null && nativeCachedToken.isNotEmpty) {
          await storage.saveFcmToken(nativeCachedToken);
          return nativeCachedToken;
        }
      } catch (e) {
        debugPrint('Native FCM token cache unavailable: $e');
      }
    }

    return null;
  }

  void _scheduleTokenRetry() {
    if (_tokenRetryTimer?.isActive ?? false) return;
    final index = _tokenRetryAttempt.clamp(0, _tokenRetryDelays.length - 1);
    final delay = _tokenRetryDelays[index];
    _tokenRetryAttempt++;
    _tokenRetryTimer = Timer(delay, uploadToken);
    debugPrint('FCM token registration will retry in ${delay.inSeconds}s');
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? orderId,
    String? type,
    String? category,
    String? templateKey,
    String? actionUrl,
    String? eventId,
    String? sound,
    Map<String, dynamic>? data,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      return;
    }
    try {
      final payloadData = {
        if (orderId != null) 'order_id': orderId,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
        if (templateKey != null) 'template_key': templateKey,
        if (actionUrl != null) 'action_url': actionUrl,
        if (eventId != null) 'event_id': eventId,
        if (data != null) ...data,
      };

      final soundKey = _normalizeMobileSound(sound);
      final usesCustomSound = soundKey == 'delitopia';
      final isSilent = soundKey == 'silent';
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        isSilent
            ? _silentChannelId
            : (usesCustomSound ? _customChannelId : _defaultChannelId),
        'Notifikasi Delitopia',
        channelDescription:
            'Notifikasi status pesanan, pembayaran, dan promo Delitopia dengan suara resmi.',
        icon: 'ic_notification',
        importance: Importance.max,
        priority: Priority.max,
        playSound: !isSilent,
        sound: usesCustomSound
            ? const RawResourceAndroidNotificationSound('delitopia')
            : null,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );

      final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: !isSilent,
        sound: usesCustomSound ? 'delitopia.caf' : null,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Trigger system local notification with official Delitopia sound
      final id = eventId?.hashCode.abs() ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
      await _localNotificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: jsonEncode(payloadData),
      );

      // Also trigger in-app SnackBar overlay
      _showInAppSnackbar(
        title,
        body,
        orderId,
        type,
        category,
        templateKey,
        actionUrl,
      );
    } catch (e) {
      debugPrint('⚠️ Error showing local notification: $e');
    }
  }

  String _normalizeMobileSound(String? sound) {
    final value = sound?.trim().toLowerCase().replaceAll('.mp3', '');
    if (value == null || value.isEmpty || value == 'delitopia') {
      return 'delitopia';
    }
    if (value == 'silent') return 'silent';
    if (const ['orderbaru', 'berhasilbayar', 'chime', 'pos_error']
        .contains(value)) {
      return 'delitopia';
    }
    return 'default';
  }

  Future<void> playDelitopiaSound() async {
    final now = DateTime.now();
    if (_lastSoundPlayed != null &&
        now.difference(_lastSoundPlayed!).inMilliseconds < 3500) {
      return;
    }

    _lastSoundPlayed = now;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/delitopia.mp3'));
    } catch (e) {
      debugPrint('Error playing Delitopia sound: $e');
    }
  }

  void _showInAppSnackbar(
    String title,
    String body,
    String? orderId,
    String? type,
    String? category,
    String? templateKey,
    String? actionUrl,
  ) {
    final context = AppRouter.router.configuration.navigatorKey.currentContext;
    if (context == null) return;

    final hasAction = orderId != null ||
        actionUrl != null ||
        type == 'voucher' ||
        type == 'promo';

    final VoidCallback? onNotificationTap = hasAction
        ? () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            NotificationRouter.open(
              actionUrl: actionUrl,
              category: category,
              templateKey: templateKey,
              type: type,
              orderId: orderId,
            );
          }
        : null;

    // Tentukan tema warna dan icon secara kontekstual
    final keyLower = (templateKey ?? '').toLowerCase();
    final titleLower = title.toLowerCase();

    final isSuccess = keyLower.contains('paid') ||
        keyLower.contains('ready') ||
        keyLower.contains('completed') ||
        titleLower.contains('berhasil') ||
        titleLower.contains('selesai') ||
        titleLower.contains('siap');

    final isCancel = keyLower.contains('cancelled') ||
        titleLower.contains('batal') ||
        titleLower.contains('gagal');

    final isCooking = keyLower.contains('cooking') ||
        titleLower.contains('dimasak') ||
        titleLower.contains('menyiapkan');

    final isVoucher = type == 'voucher' ||
        type == 'promo' ||
        keyLower.contains('voucher') ||
        keyLower.contains('promo');

    final Color accentColor;
    final IconData iconData;

    if (isCancel) {
      accentColor = const Color(0xFFDC2626); // Merah peringatan
      iconData = Icons.cancel_rounded;
    } else if (isSuccess) {
      accentColor = const Color(0xFF16A34A); // Hijau emerald sukses
      iconData = Icons.check_circle_rounded;
    } else if (isCooking) {
      accentColor = const Color(0xFFEA580C); // Oranye memasak
      iconData = Icons.restaurant_rounded;
    } else if (isVoucher) {
      accentColor = const Color(0xFF8B5CF6); // Ungu promo
      iconData = Icons.local_offer_rounded;
    } else {
      accentColor = const Color(0xFFDD2222); // Merah brand Delitopia
      iconData = Icons.notifications_active_rounded;
    }

    // Bersihkan snackbar sebelumnya agar tidak menumpuk
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 3), // Durasi 3 detik
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onNotificationTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasAction) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDD2222).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail',
                        style: TextStyle(
                          color: Color(0xFFDD2222),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Color(0xFFDD2222),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTapWithData(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['type_data'])?.toString();
    final orderId = (data['order_id'] ?? data['id_order'])?.toString();

    NotificationRouter.open(
      actionUrl: data['action_url']?.toString(),
      category: data['category']?.toString(),
      templateKey: data['template_key']?.toString(),
      type: type,
      orderId: orderId,
      statusOrder: (data['status_order'] ?? data['order_status'])?.toString(),
    );
  }

  bool _acceptEvent(String? eventId) {
    if (eventId == null || eventId.isEmpty) return true;
    final now = DateTime.now();
    _handledEvents.removeWhere(
      (_, handledAt) => now.difference(handledAt) > const Duration(minutes: 10),
    );
    if (_handledEvents.containsKey(eventId)) return false;
    _handledEvents[eventId] = now;
    return true;
  }
}
