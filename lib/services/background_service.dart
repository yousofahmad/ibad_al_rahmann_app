import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BackgroundService {
  static const _channel = MethodChannel(
    'app.ibad_al_rahmann/native_notifications',
  );

  static Future<void> init() async {}

  // دالة الجدولة
  static Future<void> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    required String soundName,
  }) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'hour': hour,
        'minute': minute,
        'soundName': soundName,
      });
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

  // ── Log helpers ──────────────────────────────────────────────────────────

  /// يُعيد آخر [lines] سطراً من ملف اللوغ النيتيف
  static Future<String> getNativeLog({int lines = 300}) async {
    try {
      final result = await _channel.invokeMethod<String>('getNativeLog', {'lines': lines});
      return result ?? '(فارغ)';
    } catch (e) {
      return '❌ خطأ في قراءة اللوغ: $e';
    }
  }

  /// يمسح ملف اللوغ النيتيف
  static Future<void> clearNativeLog() async {
    try {
      await _channel.invokeMethod('clearNativeLog');
    } catch (e) {
      debugPrint('clearNativeLog error: $e');
    }
  }

  /// يُعيد مسار ملف اللوغ على الجهاز
  static Future<String?> getNativeLogPath() async {
    try {
      return await _channel.invokeMethod<String>('getNativeLogPath');
    } catch (_) {
      return null;
    }
  }
}
