import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../router/app_router.dart' show appRouterInstance;

// Top-level background handler (required by FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'domovnik_high_importance',
    'Domovník Notifikácie',
    description: 'Notifikácie z aplikácie Domovník',
    importance: Importance.high,
  );

  // Route stored when navigation is triggered before the router is ready
  // (terminated-app launch). Consumed by DomovnikApp.initState.
  static String? _pendingRoute;
  static String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  Future<void> initialize() async {
    // ── Wire navigation handlers for ALL platforms ────────────────────────
    // Background tap (app was suspended, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // Terminated launch (app was killed, opened by tapping a notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleMessageNavigation(initialMessage);

    if (kIsWeb) {
      // On web, FCM shows browser notifications via the SW automatically.
      // Foreground messages just log; background navigation handled above.
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
      });
      return;
    }

    // ── Native-only setup ─────────────────────────────────────────────────
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await requestPermission();
    await setupMessageHandlers();
  }

  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission status: ${settings.authorizationStatus}');
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        return await _messaging.getToken(
          vapidKey: 'BD-WctOQ4qd3dZkSc9i1NldHuc0ordU3MQ2gENtcDO3cZkllkCbKaycFcr9rwd3U1GP04An1-CLMBf5RnQdsJlU',
        );
      }
      final token = await _messaging.getToken();
      debugPrint('FCM token: $token');
      return token;
    } catch (e) {
      debugPrint('FcmService.getToken error: $e');
      return null;
    }
  }

  Future<void> saveFcmTokenToProfile(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);

      debugPrint('FCM token saved to profile');
    } catch (e) {
      debugPrint('FcmService.saveFcmTokenToProfile error: $e');
    }
  }

  Future<void> setupMessageHandlers() async {
    // Foreground messages → show local notification (native only)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.messageId}');
      _showLocalNotification(message);
    });

    // Token refresh
    _messaging.onTokenRefresh.listen(saveFcmTokenToProfile);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final route = response.payload;
    if (route == null) return;
    debugPrint('Notification tapped, navigating to: $route');
    _navigate(route);
  }

  void _handleMessageNavigation(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route == null) return;
    debugPrint('FCM navigation to: $route');
    _navigate(route);
  }

  void _navigate(String route) {
    final router = appRouterInstance;
    if (router != null) {
      router.go(route);
    } else {
      // Router not ready yet (terminated-app launch). DomovnikApp.initState
      // will consume this and navigate after the first frame.
      _pendingRoute = route;
    }
  }

  static Future<void> requestPermissionAfterInteraction() async {
    if (!kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken(
          vapidKey: 'BD-WctOQ4qd3dZkSc9i1NldHuc0ordU3MQ2gENtcDO3cZkllkCbKaycFcr9rwd3U1GP04An1-CLMBf5RnQdsJlU',
        );
        if (token != null) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client
                .from('profiles')
                .update({'fcm_token': token})
                .eq('id', userId);
            debugPrint('FCM token saved after interaction');
          }
        }
      }
    } catch (e) {
      debugPrint('FCM permission error: $e');
    }
  }
}
