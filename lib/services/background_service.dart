import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BackgroundService {
  // اسم القناة لازم يكون مطابق للموجود في الكوتلين
  static const _channel = MethodChannel(
    'com.example.ibad_al_rahmann/native_notifications',
  );

  static Future<void> init() async {}

  // دالة الجدولة: تستقبل ID وساعة ودقيقة واسم ملف الصوت
  static Future<void> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    required String soundName, // (sabah, masaa, ruqyah)
  }) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'hour': hour,
        'minute': minute,
        'soundName': soundName,
      });
      debugPrint("✅ تم جدولة المنبه $id الساعة $hour:$minute بصوت $soundName");
    } catch (e) {
      debugPrint("❌ خطأ في الجدولة: $e");
    }
  }

  // دالة إلغاء المنبه
  static Future<void> cancelAlarm(int id) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': id});
      debugPrint("✅ تم إلغاء المنبه رقم $id");
    } catch (e) {
      debugPrint("❌ خطأ في الإلغاء: $e");
    }
  }
}
