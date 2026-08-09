import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../network/supabase_client_wrapper.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppConfig.hasFirebaseConfig) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    return;
  }
}

class PushNotificationService {
  static const _androidChannel = AndroidNotificationChannel(
    'academy_notifications',
    'Academy notifications',
    description: 'Operational, payment, attendance, and learning alerts.',
    importance: Importance.high,
  );

  final SupabaseClientWrapper _clientWrapper;
  FirebaseMessaging? messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;
  bool _started = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  PushNotificationService(
    this._clientWrapper, {
    this.messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  bool get isConfigured => AppConfig.hasFirebaseConfig && _initialized;

  Future<void> initialize() async {
    if (_initialized || !AppConfig.hasFirebaseConfig) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      messaging ??= FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(settings: initSettings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      await messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _initialized = true;
      AppLogger.info('Firebase Cloud Messaging initialized.');
    } catch (error, stackTrace) {
      AppLogger.error('Firebase initialization failed', error, stackTrace);
    }
  }

  Future<void> start() async {
    if (_started) return;
    await initialize();
    if (!_initialized) return;
    _started = true;

    await syncCurrentToken();
    _tokenRefreshSub = messaging?.onTokenRefresh.listen(registerToken);
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
  }

  Future<void> syncCurrentToken() async {
    if (!_initialized) return;
    final user = _clientWrapper.client.auth.currentUser;
    if (user == null) return;

    final messagingClient = messaging;
    if (messagingClient == null) return;

    final settings = await messagingClient.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.info('Push notification permission denied.');
      return;
    }

    final token = await messagingClient.getToken();
    if (token == null || token.isEmpty) return;
    await registerToken(token);
  }

  Future<void> registerToken(String token) async {
    final user = _clientWrapper.client.auth.currentUser;
    if (user == null || token.trim().isEmpty) return;

    try {
      await _clientWrapper.client.rpc(
        'register_device_push_token',
        params: {'p_token': token, 'p_platform': defaultTargetPlatform.name},
      );
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error('Failed to register FCM token', error, stackTrace);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected FCM token registration failure',
        error,
        stackTrace,
      );
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!_initialized) return;
    final messagingClient = messaging;
    if (messagingClient == null) return;
    final token = await messagingClient.getToken();
    if (token == null || token.isEmpty) return;
    await _clientWrapper.client.rpc(
      'unregister_device_push_token',
      params: {'p_token': token},
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'academy_notifications',
          'Academy notifications',
          channelDescription:
              'Operational, payment, attendance, and learning alerts.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    _started = false;
  }
}
