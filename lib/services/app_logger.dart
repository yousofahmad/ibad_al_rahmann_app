import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

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

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _secretAssignmentPattern = RegExp(
    r'''(["']?(?:password|passwd|passcode|token|access[_-]?token|refresh[_-]?token|id[_-]?token|authorization|api[_-]?key|client[_-]?secret|secret|cookie|set[_-]?cookie|auth[_-]?code|code[_-]?verifier)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^"'&,\s}\]]+)''',
    caseSensitive: false,
  );

  static String _redactSensitiveData(String content) {
    var safe = content.replaceAll(
      RegExp(r'\bhttps?://[^/@\s:]+:[^/@\s]+@', caseSensitive: false),
      'https://[redacted]@',
    );
    safe = safe.replaceAll(_emailPattern, '[email redacted]');
    safe = safe.replaceAll(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
      'Bearer [redacted]',
    );
    safe = safe.replaceAllMapped(
      _secretAssignmentPattern,
      (match) => '${match.group(1)}[redacted]',
    );
    return safe;
  }

  @visibleForTesting
  static String redactForTesting(String content) =>
      _redactSensitiveData(content);

  static Future<String> _getInstalledVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      return build.isEmpty ? info.version : '${info.version}+$build';
    } catch (_) {
      return 'unknown';
    }
  }

  @visibleForTesting
  static Future<String> getInstalledVersionLabelForTesting() =>
      _getInstalledVersionLabel();

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
      debugPrint('AppLogger.init error type: ${e.runtimeType}');
    }
  }

  /// يكتب رسالة في الملف
  static void log(String tag, String message) {
    final safeTag = _redactSensitiveData(tag);
    final safeMessage = _redactSensitiveData(message);
    final now = DateTime.now();
    final ts =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$ts] [$safeTag] $safeMessage\n';

    // دائماً اطبع في الـ console كذلك
    debugPrint('LOG [$safeTag] $safeMessage');

    if (!_initialized) {
      _buffer.write(line);
      return;
    }

    // كتابة غير متزامنة بـ batch (كل 2 ثانية)
    _buffer.write(line);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), _flushBuffer);
  }

  /// يكتب حدثًا بمفاتيح واضحة لتسهيل تتبع الجدولة والتنفيذ والنتائج.
  static void logEvent(
    String tag,
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    final details = fields.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    log(tag, 'event=$event${details.isEmpty ? '' : ' $details'}');
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
      debugPrint('AppLogger._write error type: ${e.runtimeType}');
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
      return all.reversed
          .take(lines)
          .toList()
          .reversed
          .map(_redactSensitiveData)
          .join('\n');
    } catch (e) {
      return 'خطأ في قراءة اللوغ (${e.runtimeType})';
    }
  }

  /// تنظيف ذكي — يحذف السطور الروتينية ويحتفظ بالمهمة فقط:
  /// • أي سطر يحتوي على خطأ / استثناء / warning
  /// • أي سطر تأخر أكثر من 2 ثانية عن السابق (يدل على تهنيج)
  /// • أول وآخر سطر في كل جلسة تشغيل
  /// • السطور المكررة: يحتفظ بنسخة واحدة فقط
  static Future<Map<String, int>> smartClean() async {
    await _flushBuffer();
    final file = _logFile;
    if (file == null || !await file.exists())
      return {'total': 0, 'kept': 0, 'removed': 0};

    final lines = await file.readAsLines();
    final total = lines.length;
    if (total == 0) return {'total': 0, 'kept': 0, 'removed': 0};

    // الكلمات الدالة على مشكلة — نحتفظ بهذه دائماً
    const errorKeywords = [
      'error',
      'exception',
      'fail',
      'crash',
      'timeout',
      'null',
      'fatal',
      'IOException',
      'ANR',
      'خطأ',
      'فشل',
      'تعذر',
    ];

    // السطور الروتينية الصرفة التي نحذفها إذا لم يكن هناك تأخير أو خطأ
    final routinePatterns = [
      RegExp(r'\[BgInit\] .*(start|triggered|done)', caseSensitive: false),
      RegExp(r'\[AppLogger\] initialized'),
    ];

    DateTime? prevTime;
    final kept = <String>[];
    final seen = <String>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      // يستوعب الطابع الحالي [yyyy-MM-dd HH:mm:ss.SSS] والسجلات القديمة.
      DateTime? lineTime;
      final timeMatch = RegExp(
        r'\[(?:(\d{4})-)?(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3})\]',
      ).firstMatch(line);
      if (timeMatch != null) {
        try {
          final now = DateTime.now();
          lineTime = DateTime(
            int.parse(timeMatch.group(1) ?? '${now.year}'),
            int.parse(timeMatch.group(2)!),
            int.parse(timeMatch.group(3)!),
            int.parse(timeMatch.group(4)!),
            int.parse(timeMatch.group(5)!),
            int.parse(timeMatch.group(6)!),
            int.parse(timeMatch.group(7)!),
          );
        } catch (_) {}
      }

      // 1. هل السطر يحتوي على كلمة مهمة؟
      final lower = line.toLowerCase();
      final isImportant = errorKeywords.any(
        (kw) => lower.contains(kw.toLowerCase()),
      );

      // 2. هل هناك تأخير كبير منذ السطر السابق؟ (> 2 ثانية = تهنيج محتمل)
      bool isSlowStep = false;
      if (lineTime != null && prevTime != null) {
        final gapMs = lineTime.difference(prevTime).inMilliseconds;
        if (gapMs > 2000) {
          isSlowStep = true;
          kept.add('⚠️  [SLOW ${gapMs}ms gap before this line]');
        }
      }

      // 3. أول وآخر سطر = دائماً مهم
      final isFirstOrLast = (i == 0 || i == lines.length - 1);

      // 4. هل هو روتيني صرف؟
      final isRoutine =
          !isImportant &&
          !isSlowStep &&
          !isFirstOrLast &&
          routinePatterns.any((p) => p.hasMatch(line));

      // 5. هل مكرر (نفس المحتوى بدون الطابع الزمني)؟
      final msgKey = line
          .replaceAll(
            RegExp(r'\[(?:(?:\d{4})-)?\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]'),
            '',
          )
          .trim();
      final isDuplicate = !isImportant && seen.contains(msgKey);

      if (!isRoutine && !isDuplicate) {
        kept.add(line);
        seen.add(msgKey);
      }

      if (lineTime != null) prevTime = lineTime;
    }

    await file.writeAsString('${kept.join('\n')}\n');
    final removed = total - kept.length;
    log(
      'AppLogger',
      'smartClean done: total=$total kept=${kept.length} removed=$removed',
    );
    return {'total': total, 'kept': kept.length, 'removed': removed};
  }

  /// يمسح الملف بالكامل (استخدام داخلي)
  static Future<void> clear() async {
    await _flushBuffer();
    try {
      await _logFile?.writeAsString('');
    } catch (e) {
      debugPrint('AppLogger.clear error type: ${e.runtimeType}');
    }
  }

  /// يشارك ملف اللوغ (Flutter + Native مدمجَين)
  static Future<void> shareLog({String? nativeLogContent}) async {
    await _flushBuffer();
    try {
      final appVersion = await _getInstalledVersionLabel();
      final path = await getLogPath();
      if (path == null) return;

      final flutterFile = File(path);
      String combined = '';

      // رأس الملف
      combined += '═══════════ عباد الرحمن — سجل التطبيق ═══════════\n';
      combined += 'الوقت: ${DateTime.now()}\n\n';
      combined += 'الإصدار المثبت: $appVersion\n\n';

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

      final timeStr = DateFormat('yyyy_MM_dd_HHmmss').format(DateTime.now());
      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/ibad_app_log_$timeStr.txt');
      await tempFile.writeAsString(_redactSensitiveData(combined));

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject:
            'سجل عباد الرحمن v$appVersion — ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        text: 'سجل التطبيق لتشخيص المشاكل (الإصدار $appVersion)',
      );
    } catch (e) {
      debugPrint('AppLogger.shareLog error type: ${e.runtimeType}');
    }
  }

  /// الإبلاغ عن مشكلة وتجهيز ملف السجل وإرساله
  static Future<void> reportIssue(
    BuildContext context, {
    String? nativeLogContent,
  }) async {
    try {
      await _flushBuffer();
      final appVersion = await _getInstalledVersionLabel();
      final timeStr = DateFormat('yyyy_MM_dd_HHmmss').format(DateTime.now());
      final path = await getLogPath();
      final flutterFile = path != null ? File(path) : null;

      String combined = '';
      combined += '═══════════ تقرير تشخيص مشكلة — عباد الرحمن ═══════════\n';
      combined += 'إصدار التطبيق المثبت: $appVersion\n';
      combined +=
          'تاريخ التقرير: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n';
      combined += 'إصدار التطبيق: $appVersion\n';
      combined +=
          'نظام التشغيل: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n\n';

      combined += '────── Flutter/Dart Logs ──────\n';
      if (flutterFile != null && await flutterFile.exists()) {
        combined += await flutterFile.readAsString();
      } else {
        combined += '(لا يوجد سجل Flutter)\n';
      }

      if (nativeLogContent != null && nativeLogContent.isNotEmpty) {
        combined += '\n────── Native/Kotlin Logs ──────\n';
        combined += nativeLogContent;
      }

      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/ibad_issue_report_$timeStr.txt');
      await tempFile.writeAsString(_redactSensitiveData(combined));

      final messageText =
          'السلام عليكم ورحمة الله وبركاته،\n'
          'أود الإبلاغ عن مشكلة في تطبيق عباد الرحمن (الإصدار $appVersion):\n\n'
          '[يرجى كتابة تفاصيل المشكلة هنا]\n\n'
          '(مرفق ملف سجل التطبيق للتشخيص)';

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'تقرير مشكلة — تطبيق عباد الرحمن',
        text: messageText,
      );
    } catch (e) {
      debugPrint('AppLogger.reportIssue error type: ${e.runtimeType}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تجهيز التقرير (${e.runtimeType})'),
          ),
        );
      }
    }
  }
}
