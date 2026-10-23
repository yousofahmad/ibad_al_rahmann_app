import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Notification messages in the background are displayed by Firebase/Android.
/// Do not display them again here, which would create duplicate notifications.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class FCMService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  static String _payload(RemoteMessage message) {
    final payload = message.data['payload'];
    return payload is String && payload.isNotEmpty ? payload : 'home';
  }

  static void _openMessage(RemoteMessage message) {
    NotificationService.onNotificationTap.value = null;
    NotificationService.onNotificationTap.value = _payload(message);
  }

  /// Kept separate from Firebase initialization so local rendering is testable.
  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if ((title is! String || title.trim().isEmpty) &&
        (body is! String || body.trim().isEmpty)) {
      return;
    }
    await NotificationService.showImmediateNotification(
      title: title is String && title.trim().isNotEmpty ? title : 'عباد الرحمن',
      body: body is String ? body : '',
      payload: _payload(message),
      soundName: 'default',
    );
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      final settings = await _messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => _messaging.getNotificationSettings(),
          );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(handleForegroundMessage(message));
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _openMessage,
      );
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _openMessage(initial);
      await _messaging.subscribeToTopic('all_users').catchError((_) {});
    } catch (e) {
      await _foregroundSubscription?.cancel();
      await _openedSubscription?.cancel();
      _foregroundSubscription = null;
      _openedSubscription = null;
      _initialized = false;
      debugPrint('FCM Init Error: $e');
    }
  }
}
