import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// AppLogger — سجل شامل للتطبيق يعمل بدون اتصال بالكمبيوتر
///
/// • يكتب في ملفين:
///   - app_log.txt      → أحداث التطبيق (Flutter/Dart side)
///   - native_log.txt   → يُقرأ من النيتيف (Kotlin side) عبر BackgroundService
/// • يحتفظ بآخر 500 KB فقط (rotation تلقائي)
/// • يمكن مشاركة الملف مباشرة من داخل التطبيق
/// • استخدام: AppLogger.log('تسمية', 'الرسالة')
class AppLogger {
  static const int _maxBytes = 500 * 1024; // 500 KB
  static const String _fileName = 'ibad_app_log.txt';

  static File? _logFile;
  static bool _initialized = false;
  static final _buffer = StringBuffer();
  static Timer? _flushTimer;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_fileName');
      _initialized = true;
      log('AppLogger', 'initialized — log file: ${_logFile!.path}');
      // Flush buffered messages written before init
      if (_buffer.isNotEmpty) {
        await _write(_buffer.toString());
        _buffer.clear();
      }
    } catch (e) {
      debugPrint('AppLogger.init error: $e');
    }
  }

  /// يكتب رسالة في الملف
  static void log(String tag, String message) {
    final now = DateTime.now();
    final ts = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$ts] [$tag] $message\n';

    // دائماً اطبع في الـ console كذلك
    debugPrint('LOG [$tag] $message');

    if (!_initialized) {
      _buffer.write(line);
      return;
    }

    // كتابة غير متزامنة بـ batch (كل 2 ثانية)
    _buffer.write(line);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), _flushBuffer);
  }

  static Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final content = _buffer.toString();
    _buffer.clear();
    await _write(content);
  }

  static Future<void> _write(String content) async {
    try {
      final file = _logFile;
      if (file == null) return;

      // Rotation: لو الملف أكبر من 500 KB، احتفظ بنصفه الأخير
      if (await file.exists() && await file.length() > _maxBytes) {
        final existing = await file.readAsString();
        final half = existing.substring(existing.length ~/ 2);
        await file.writeAsString('... [truncated] ...\n$half');
      }

      await file.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      debugPrint('AppLogger._write error: $e');
    }
  }

  /// يُعيد مسار ملف اللوغ
  static Future<String?> getLogPath() async {
    if (_logFile != null) return _logFile!.path;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$_fileName';
    } catch (_) {
      return null;
    }
  }

  /// يُعيد آخر [lines] سطراً من الملف
  static Future<String> tail({int lines = 300}) async {
    try {
      await _flushBuffer(); // flush أي بيانات معلقة أولاً
      final file = _logFile;
      if (file == null || !await file.exists()) return '(اللوغ فارغ)';
      final all = await file.readAsLines();
      return all.reversed.take(lines).toList().reversed.join('\n');
    } catch (e) {
      return 'خطأ في قراءة اللوغ: $e';
    }
  }

  /// يمسح الملف
  static Future<void> clear() async {
    await _flushBuffer();
    try {
      await _logFile?.writeAsString('');
    } catch (e) {
      debugPrint('AppLogger.clear error: $e');
    }
  }

  /// يشارك ملف اللوغ (Flutter + Native مدمجَين)
  static Future<void> shareLog({String? nativeLogContent}) async {
    await _flushBuffer();
    try {
      final path = await getLogPath();
      if (path == null) return;

      final flutterFile = File(path);
      String combined = '';

      // رأس الملف
      combined += '═══════════ عباد الرحمن — سجل التطبيق ═══════════\n';
      combined += 'الوقت: ${DateTime.now()}\n\n';

      // Flutter logs
      combined += '────── Flutter/Dart Logs ──────\n';
      if (await flutterFile.exists()) {
        combined += await flutterFile.readAsString();
      } else {
        combined += '(لا يوجد)\n';
      }

      // Native logs
      if (nativeLogContent != null && nativeLogContent.isNotEmpty) {
        combined += '\n────── Native/Kotlin Logs ──────\n';
        combined += nativeLogContent;
      }

      // كتابة الملف المدمج في temp
      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/ibad_full_log.txt');
      await tempFile.writeAsString(combined);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'سجل عباد الرحمن — ${DateTime.now().toString().substring(0, 16)}',
        text: 'سجل التطبيق لتشخيص المشاكل',
      );
    } catch (e) {
      debugPrint('AppLogger.shareLog error: $e');
    }
  }
}
