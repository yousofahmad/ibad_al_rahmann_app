import 'package:flutter/services.dart';

class PrayerRelativeAlarmPlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'app.ibad_al_rahmann/native_notifications',
  );

  static Future<void> reschedule() async {
    await _channel.invokeMethod<void>('schedulePrayerRelativeAlarm');
  }
}
