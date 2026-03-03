import 'package:flutter/services.dart';

class PrayerNotificationServiceHelper {
  static const MethodChannel _channel = MethodChannel(
    'com.example.ibad_al_rahmann/native_notifications',
  );

  /// Start or update the persistent prayer notification
  static Future<void> updateNotification({
    required String fajr,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    required String nextName,
    required String countdown,
    required String hijri,
    required int prayerIndex,
    int? nextPrayerEpoch,
  }) async {
    try {
      await _channel.invokeMethod('updatePrayerNotification', {
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'nextName': nextName,
        'countdown': countdown,
        'hijri': hijri,
        'prayerIndex': prayerIndex,
        'nextPrayerEpoch': nextPrayerEpoch ?? 0,
      });
    } catch (e) {
      print("Failed to update prayer notification: $e");
    }
  }

  /// Stop the persistent prayer notification
  static Future<void> stopNotification() async {
    try {
      await _channel.invokeMethod('stopPrayerNotification');
    } catch (e) {
      print("Failed to stop prayer notification: $e");
    }
  }
}
