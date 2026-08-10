import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level handler required by FCM for background messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class FCMService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      // Register background handler early
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Only request permission if the app is actually in the foreground/active.
      // If the screen is locked, this might fail or show nothing.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
         debugPrint('FCM: Permission request timed out.');
         return _messaging.getNotificationSettings();
      });
      
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message: ${message.messageId}');
      });

      // Subscribe to global topic
      await _messaging.subscribeToTopic('all_users').catchError((_) {});

      final token = await _messaging.getToken().catchError((_) => null);
      if (token != null && kDebugMode) debugPrint('FCM token: $token');
    } catch (e) {
      debugPrint('FCM Init Error: $e');
    }
  }
}
