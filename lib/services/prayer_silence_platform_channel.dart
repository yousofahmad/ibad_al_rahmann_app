import 'package:flutter/services.dart';

class PrayerSilencePlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'app.ibad_al_rahmann/native_notifications',
  );

  static Future<bool> hasNotificationPolicyAccess() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isNotificationPolicyAccessGranted',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openNotificationPolicySettings() async {
    await _channel.invokeMethod<void>(
      'openNotificationPolicyAccessSettings',
    );
  }

  static Future<void> reschedule() async {
    await _channel.invokeMethod<void>('schedulePrayerSilence');
  }
}
