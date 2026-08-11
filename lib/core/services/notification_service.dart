import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../logging/app_logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.info('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  final _deepLinkController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deepLinkStream => _deepLinkController.stream;

  Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.info('User granted permission: ${settings.authorizationStatus}');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.info('Got a message whilst in the foreground!');
        AppLogger.info('Message data: ${message.data}');

        if (message.notification != null) {
          AppLogger.info('Message also contained a notification: ${message.notification}');
        }
      });

      // Handle deep links when app is in background but opened via notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info('A new onMessageOpenedApp event was published!');
        if (message.data.isNotEmpty) {
          _deepLinkController.add(message.data);
        }
      });

      // Handle deep link if app was terminated and opened via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        _deepLinkController.add(initialMessage.data);
      }
    } catch (e) {
      AppLogger.error('Failed to initialize NotificationService: $e');
    }
  }

  void dispose() {
    _deepLinkController.close();
  }
}
