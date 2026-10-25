import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/services/backup_payload_validator.dart';
import 'package:ibad_al_rahmann/services/backup_sync_schedule.dart';

@pragma('vm:entry-point')
Future<void> driveAutoSyncTask() async {
  var success = false;
  var shouldReportResult = true;
  int? recoveryAttemptsRemaining;
  var stage = 'flutter_binding_init';
  var failureReason = 'not_started';
  String? scheduledFor;
  final startedAt = DateTime.now();
  final stopwatch = Stopwatch()..start();
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await AppLogger.init();
    AppLogger.logEvent('DriveAutoSync', 'task_started', {
      'startedAt': startedAt.toIso8601String(),
      'trigger': 'android_alarm_manager_callback',
    });
    stage = 'cache_init';
    await CacheHelper.init();
    // تهيئة Hive بالمسار الصحيح لمعالجة الخلفية
    stage = 'hive_init';
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VerseModelAdapter());
    }
    try {
      await BookmarkService.init();
    } catch (error) {
      AppLogger.logEvent('DriveAutoSync', 'subtask_failed', {
        'stage': 'bookmark_service_init',
        'reason': 'exception_${error.runtimeType}',
      });
    }
    try {
      if (!Hive.isBoxOpen('appDataBox')) await Hive.openBox('appDataBox');
    } catch (error) {
      AppLogger.logEvent('DriveAutoSync', 'subtask_failed', {
        'stage': 'hive_box_open',
        'reason': 'exception_${error.runtimeType}',
      });
    }

    final prefs = CacheHelper.prefs;
    if (prefs.getBool('auto_sync_drive') != true) {
      failureReason = 'automatic_sync_disabled';
      AppLogger.logEvent('DriveAutoSync', 'task_skipped', {
        'reason': failureReason,
        'startedAt': startedAt.toIso8601String(),
      });
      shouldReportResult = false;
      return;
    }
    stage = 'attempt_accounting';
    recoveryAttemptsRemaining = await BackupService.beginAutoSyncAttempt();
    if (recoveryAttemptsRemaining != null) {
      debugPrint('Google Drive: Running a post-power-on recovery attempt.');
    }
    final scheduledAt = prefs.getString('auto_sync_next_scheduled_for');
    scheduledFor = scheduledAt;
    if (scheduledAt != null) {
      await prefs.setString('last_auto_sync_scheduled_for', scheduledAt);
    }
    AppLogger.logEvent('DriveAutoSync', 'scheduled_run_started', {
      'scheduledFor': scheduledAt,
      'startedAt': DateTime.now().toIso8601String(),
      'trigger': recoveryAttemptsRemaining == null
          ? 'scheduled_or_regular_retry'
          : 'power_recovery_retry',
      'recoveryAttemptsRemaining': recoveryAttemptsRemaining,
    });
    await prefs.setString(
      'last_auto_sync_started_at',
      DateTime.now().toIso8601String(),
    );

    // 1. مزامنة مع مهلة دقيقتين للنت الضعيف
    stage = 'sync_to_drive';
    success = await BackupService.syncToDrive(allowUI: false);
    failureReason = success ? 'none' : 'sync_to_drive_returned_false';

    stage = 'persist_result';
    await prefs.setString(
      'last_auto_sync_status',
      '${DateTime.now().toIso8601String()}: $success',
    );
    if (success) {
      await prefs.setString(
        'last_auto_sync_completed_at',
        DateTime.now().toIso8601String(),
      );
    }
    AppLogger.logEvent('DriveAutoSync', 'sync_result', {
      'outcome': success ? 'success' : 'failure',
      'reason': failureReason,
      'scheduledFor': scheduledAt,
      'startedAt': prefs.getString('last_auto_sync_started_at'),
      'finishedAt': DateTime.now().toIso8601String(),
      'durationMs': stopwatch.elapsedMilliseconds,
      'recoveryAttemptsRemaining': recoveryAttemptsRemaining,
    });
    debugPrint('Auto-sync to Google Drive completed: $success');
  } catch (e) {
    failureReason = 'exception_${e.runtimeType}';
    AppLogger.logEvent('DriveAutoSync', 'task_failed', {
      'stage': stage,
      'reason': failureReason,
      'scheduledFor': scheduledFor,
      'startedAt': startedAt.toIso8601String(),
      'durationMs': stopwatch.elapsedMilliseconds,
    });
    debugPrint('driveAutoSyncTask error type: ${e.runtimeType}');
    try {
      await CacheHelper.prefs.setString(
        'last_auto_sync_status',
        '${DateTime.now().toIso8601String()}: false',
      );
    } catch (_) {}
  } finally {
    if (shouldReportResult) {
      final finishedAt = DateTime.now();
      try {
        final prefs = CacheHelper.prefs;
        await prefs.setString(
          'last_auto_sync_finished_at',
          finishedAt.toIso8601String(),
        );
      } catch (error) {
        AppLogger.logEvent('DriveAutoSync', 'result_persistence_failed', {
          'reason': 'exception_${error.runtimeType}',
        });
      }
      await _showAutoSyncResult(
        success,
        recoveryAttemptsRemaining: recoveryAttemptsRemaining,
      );
      try {
        if (success) {
          await BackupService.scheduleAfterSuccessfulAutoSync();
        } else {
          await BackupService.scheduleRetryAfterFailedAutoSync();
        }
      } catch (e) {
        AppLogger.logEvent('DriveAutoSync', 'reschedule_failed', {
          'reason': 'exception_${e.runtimeType}',
          'afterOutcome': success ? 'success' : 'failure',
          'finishedAt': finishedAt.toIso8601String(),
        });
        debugPrint('Drive auto-sync reschedule error type: ${e.runtimeType}');
      }
      AppLogger.logEvent('DriveAutoSync', 'task_finished', {
        'outcome': success ? 'success' : 'failure',
        'reason': failureReason,
        'scheduledFor': scheduledFor,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'recoveryAttemptsRemaining': recoveryAttemptsRemaining,
      });
    }
  }
}

Future<void> _showAutoSyncResult(
  bool success, {
  int? recoveryAttemptsRemaining,
}) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await plugin.initialize(settings: initializationSettings);

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'auto_sync_drive_v1',
        'مزامنة Google Drive',
        description: 'نتيجة المزامنة التلقائية مع Google Drive',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    await plugin.show(
      id: 99999,
      title: success ? 'المزامنة التلقائية ✓' : 'فشل المزامنة التلقائية',
      body: success
          ? 'تمت مزامنة بياناتك مع جوجل درايف بنجاح.'
          : recoveryAttemptsRemaining == null
          ? 'تعذرت المزامنة؛ سنحاول مجددًا كل ساعة حتى الفجر.'
          : recoveryAttemptsRemaining > 0
          ? 'تعذرت المزامنة بعد عودة الهاتف؛ سنحاول مجددًا بعد 30 دقيقة.'
          : 'تعذرت المزامنة بعد محاولات الاستعادة الأربع؛ ستعود إلى سياسة الإعادة المعتادة.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'auto_sync_drive_v1',
          'مزامنة Google Drive',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          silent: true,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Drive sync notification error: $e');
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

enum BackupCategory { bookmarks, khatmas, prayers, tracker, settings }

class BackupService {
  static const String _backupFileName = 'ibad_al_rahmann_backup.json';
  static const String _currentVersion = '1.2.0';

  static const String _serverClientId =
      '1029405862241-u0m400hgjnmjsb60g6e4qcop3gd41fbp.apps.googleusercontent.com';
  static bool _isGoogleSignInInitialized = false;
  static GoogleSignInAccount? _cachedAccount;
  static Map<String, String>? _cachedAuthHeaders;

  static Future<void> _ensureInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _isGoogleSignInInitialized = true;
    }
  }

  /// Helper to get backup data as a Map (supports full or selective backup)
  static Future<Map<String, dynamic>> _generateBackupData({
    Set<BackupCategory>? categories,
  }) async {
    final Map<String, dynamic> backupData = {
      'version': _currentVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'preferences': {},
      'bookmarks': [],
      'khatmas': {},
    };

    final includeAll = categories == null;
    final includeBookmarks =
        includeAll || categories.contains(BackupCategory.bookmarks);
    final includeKhatmas =
        includeAll || categories.contains(BackupCategory.khatmas);
    final includePrayers =
        includeAll || categories.contains(BackupCategory.prayers);
    final includeTracker =
        includeAll || categories.contains(BackupCategory.tracker);
    final includeSettings =
        includeAll || categories.contains(BackupCategory.settings);

    // 1. Gather SharedPreferences
    final prefs = CacheHelper.prefs;
    final allKeys = prefs.getKeys();

    // Blacklist transient or machine-specific keys
    final blacklist = {
      'last_sync_time',
      'cache_',
      'lib_cash',
      'firebase_token',
      'last_sync_email',
      'last_auto_sync_status',
      'last_auto_sync_scheduled_for',
      'last_auto_sync_started_at',
      'last_auto_sync_completed_at',
      'last_auto_sync_finished_at',
      _autoSyncLastShutdownEpochMsKey,
      _autoSyncRetryUntilKey,
      _autoSyncNextScheduledAtKey,
      _autoSyncNextScheduledEpochMsKey,
      _autoSyncRecoveryPendingKey,
      _autoSyncRecoveryAttemptsRemainingKey,
    };

    for (String key in allKeys) {
      bool isBlacklisted = false;
      for (var b in blacklist) {
        if (key.startsWith(b)) {
          isBlacklisted = true;
          break;
        }
      }
      if (isBlacklisted) continue;

      bool isPrayerKey =
          key.startsWith('adhan_') ||
          key.startsWith('iqama_') ||
          key.startsWith('notif_prayer_') ||
          key.startsWith('adjust_') ||
          key.startsWith('sound_') ||
          key.startsWith('calc_method') ||
          key.startsWith('asr_calc') ||
          key.startsWith('city_') ||
          key.startsWith('lat') ||
          key.startsWith('long');
      bool isTrackerKey =
          key.startsWith('temp_') ||
          key.startsWith('prayer_focus_log_') ||
          key.startsWith('accountability_') ||
          key.startsWith('fasting_') ||
          key.startsWith('sabah_') ||
          key.startsWith('masaa_') ||
          key.startsWith('daily_tracker_') ||
          key.startsWith('prayer_streak_') ||
          key.startsWith('azkar_') ||
          key.startsWith('count_') ||
          key.startsWith('streak_');
      bool isSettingsKey = !isPrayerKey && !isTrackerKey;

      if ((isPrayerKey && includePrayers) ||
          (isTrackerKey && includeTracker) ||
          (isSettingsKey && includeSettings)) {
        backupData['preferences'][key] = prefs.get(key);
      }
    }

    // 2. Gather Hive Bookmarks (Quran)
    if (includeBookmarks) {
      try {
        if (!BookmarkService.box.isOpen) await BookmarkService.init();
        final bookmarkBox = BookmarkService.box;
        final List<VerseModel> bookmarks = bookmarkBox.values.toList();
        backupData['bookmarks'] = bookmarks
            .map(
              (b) => {
                'surahNumber': b.surahNumber,
                'verseNumber': b.verseNumber,
                'verse': b.verse,
                'fontFamily': b.fontFamily,
                'bookmarkedAt': b.bookmarkedAt.toIso8601String(),
                'label': b.label,
              },
            )
            .toList();
      } catch (e) {
        debugPrint('Backup bookmarks error: $e');
      }
    }

    // 3. Gather Hive Khatmas (Wird progress) from appDataBox
    if (includeKhatmas) {
      try {
        final appBox = Hive.box('appDataBox');
        final Map<String, dynamic> khatmasMap = {};
        for (var key in appBox.keys) {
          final keyStr = key.toString();
          if (keyStr.startsWith('khatma_') ||
              keyStr == 'completed_khatmas_list' ||
              keyStr == 'manual_completed_khatmas_count') {
            final value = appBox.get(key);
            if (value != null) {
              khatmasMap[keyStr] = value;
            }
          }
        }
        backupData['khatmas'] = khatmasMap;
      } catch (e) {
        debugPrint('Backup khatmas error: $e');
      }
    }

    return backupData;
  }

  static String getGeneratedBackupFileName() {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy_MM_dd_HHmmss').format(now);
    return 'ibad_al_rahmann_backup_$timestamp.json';
  }

  /// Export settings and bookmarks to a JSON file and share it (supports selective backup).
  static Future<bool> exportBackup({Set<BackupCategory>? categories}) async {
    try {
      final backupData = await _generateBackupData(categories: categories);
      final tempDir = await getTemporaryDirectory();
      final fileName = getGeneratedBackupFileName();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonEncode(backupData));
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'نسخة احتياطية لإعدادات تطبيق عباد الرحمن');
      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }

  /// Save backup to device manually using file picker (supports selective backup).
  static Future<bool> saveBackupToDevice({
    Set<BackupCategory>? categories,
    void Function(double)? onProgress,
  }) async {
    try {
      final backupData = await _generateBackupData(categories: categories);
      final content = jsonEncode(backupData);
      onProgress?.call(0.5);
      final bytes = utf8.encode(content);
      onProgress?.call(0.7);

      final dynamicFileName = getGeneratedBackupFileName();
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: dynamicFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (outputPath != null) {
        final file = File(outputPath);
        if (!await file.exists() || (await file.length()) == 0) {
          await file.writeAsBytes(bytes);
        }
      }

      return outputPath != null;
    } catch (e) {
      debugPrint('Save to device error: $e');
      return false;
    }
  }

  /// Import settings and bookmarks from a JSON file.
  static Future<bool> importBackup({void Function(double)? onProgress}) async {
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (_) {
        result = null;
      }

      if (result == null || result.files.single.path == null) {
        // Fallback for files where Android appended numbering or altered extension
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }

      if (result == null || result.files.single.path == null) return false;
      final file = File(result.files.single.path!);
      onProgress?.call(0.2);
      final content = await file.readAsString();
      final decoded =
          await compute(jsonDecode, content) as Map<String, dynamic>;
      onProgress?.call(0.4);
      onProgress?.call(0.5);
      return await _applyBackupData(
        decoded,
        onProgress: onProgress,
        startProgress: 0.4,
      );
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  static Future<bool> _applyBackupData(
    Map<String, dynamic> backupData, {
    void Function(double)? onProgress,
    double startProgress = 0.5,
  }) async {
    try {
      // Validate every section before writing preferences or clearing Hive.
      // A malformed bookmark used to clear all local bookmarks first.
      if (!BackupPayloadValidator.isValid(backupData)) {
        debugPrint('Restore: ❌ invalid backup payload');
        return false;
      }
      debugPrint(
        'Restore: starting from backup version ${backupData['version']}',
      );

      final Map<String, dynamic> prefsMap =
          (backupData['preferences'] as Map<String, dynamic>?) ?? {};
      final List<dynamic> bMap =
          (backupData['bookmarks'] as List<dynamic>?) ?? [];
      final Map<String, dynamic> kMap = backupData['khatmas'] != null
          ? Map<String, dynamic>.from(backupData['khatmas'] as Map)
          : {};
      int totalItems = prefsMap.length + bMap.length + kMap.length;
      if (totalItems == 0) totalItems = 1;
      int currentItem = 0;
      // 1. Restore SharedPreferences ────────────────────────────────────────
      final prefs = CacheHelper.prefs;
      final Map<String, dynamic> preferences =
          (backupData['preferences'] as Map<String, dynamic>?) ?? {};

      int restoredCount = 0;
      int skippedCount = 0;

      for (final entry in preferences.entries) {
        final key = entry.key;
        final value = entry.value;
        try {
          if (value == null) {
            await prefs.remove(key);
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          } else if (value is bool) {
            await prefs.setBool(key, value);
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          } else if (value is String) {
            await prefs.setString(key, value);
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          } else if (value is int) {
            await prefs.setInt(key, value);
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          } else if (value is double) {
            await prefs.setDouble(key, value);
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          } else if (value is num) {
            // JSON decode يرجع num — نقرر int أو double بناءً على القيمة
            if (value == value.toInt()) {
              await prefs.setInt(key, value.toInt());
            } else {
              await prefs.setDouble(key, value.toDouble());
            }
          } else if (value is List) {
            // نتأكد إن كل عناصر الـ List نصوص قبل الحفظ
            final strList = value.map((e) => e?.toString() ?? '').toList();
            await prefs.setStringList(key, strList);
          } else {
            debugPrint(
              'Restore: ⚠️ skipped key "$key" — unknown type ${value.runtimeType}',
            );
            skippedCount++;
            continue;
          }
          restoredCount++;
        } catch (e) {
          debugPrint('Restore: ❌ error writing key "$key": $e');
          skippedCount++;
        }
      }
      debugPrint(
        'Restore: ✅ preferences — $restoredCount restored, $skippedCount skipped',
      );

      // 2. Restore Hive Bookmarks (Quran) ───────────────────────────────────
      if (backupData['bookmarks'] != null) {
        try {
          if (!BookmarkService.box.isOpen) await BookmarkService.init();
          await BookmarkService.clearAllBookmarks();
          final List<dynamic> bookmarksData = backupData['bookmarks'] as List;
          for (var bData in bookmarksData) {
            try {
              final verse = VerseModel(
                surahNumber: (bData['surahNumber'] as num).toInt(),
                verseNumber: (bData['verseNumber'] as num).toInt(),
                verse: bData['verse']?.toString() ?? '',
                fontFamily: bData['fontFamily']?.toString() ?? '',
                bookmarkedAt: DateTime.parse(bData['bookmarkedAt'].toString()),
                label: bData['label']?.toString(),
              );
              await BookmarkService.addBookmark(verse);
              currentItem++;
              if (currentItem % 10 == 0 || currentItem == totalItems) {
                final fraction = currentItem / totalItems;
                final mapped = startProgress + fraction * (1.0 - startProgress);
                onProgress?.call(mapped);
              }
            } catch (e) {
              debugPrint('Restore: ❌ bookmark error: $e');
            }
          }
          debugPrint('Restore: ✅ bookmarks — ${bookmarksData.length} restored');
        } catch (e) {
          debugPrint('Restore: ❌ bookmarks section error: $e');
        }
      }

      // 3. Restore Hive Khatmas (Wird progress) ─────────────────────────────
      if (backupData['khatmas'] != null) {
        try {
          final appBox = Hive.box('appDataBox');
          final Map<String, dynamic> khatmasMap = Map<String, dynamic>.from(
            backupData['khatmas'] as Map,
          );
          int kCount = 0;
          for (final entry in khatmasMap.entries) {
            if (entry.key.startsWith('khatma_') ||
                entry.key == 'completed_khatmas_list' ||
                entry.key == 'manual_completed_khatmas_count') {
              await appBox.put(entry.key, entry.value);
              kCount++;
            }
            currentItem++;
            if (currentItem % 10 == 0 || currentItem == totalItems) {
              final fraction = currentItem / totalItems;
              final mapped = startProgress + fraction * (1.0 - startProgress);
              onProgress?.call(mapped);
            }
          }
          debugPrint('Restore: ✅ khatmas — $kCount restored to appDataBox');
        } catch (e) {
          debugPrint('Restore: ❌ khatmas section error: $e');
        }
      }

      // 4. Re-schedule notifications once (debounced to avoid storm) ────────
      try {
        await PrayerService().scheduleNotificationsDebounced();
        debugPrint('Restore: ✅ notifications rescheduled');
      } catch (e) {
        debugPrint('Restore: ⚠️ reschedule error: $e');
      }
      try {
        NotificationService.rescheduleWird();
      } catch (e) {
        debugPrint('Restore: ⚠️ rescheduleWird error: $e');
      }

      debugPrint('Restore: ✅ complete');
      return true;
    } catch (e) {
      debugPrint('Restore: ❌ fatal error: $e');
      return false;
    }
  }

  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;

  /// Gets authenticated Drive API client with a single prompt.
  static Future<drive.DriveApi?> _getDriveApi({bool allowUI = true}) async {
    try {
      await _ensureInitialized();

      // 1. If we already have valid auth headers in memory, return client immediately
      if (_cachedAuthHeaders != null) {
        return drive.DriveApi(GoogleAuthClient(_cachedAuthHeaders!));
      }

      // 2. Try silent headers retrieval first without prompt
      try {
        final silentHeaders = await GoogleSignIn.instance.authorizationClient
            .authorizationHeaders([
              drive.DriveApi.driveAppdataScope,
            ], promptIfNecessary: false);
        if (silentHeaders != null && silentHeaders.isNotEmpty) {
          _cachedAuthHeaders = silentHeaders;
          AppLogger.log('GoogleDrive', 'Silent headers OK');
          return drive.DriveApi(GoogleAuthClient(silentHeaders));
        }
      } catch (e) {
        AppLogger.log(
          'GoogleDrive',
          'Silent authorizationHeaders error type: ${e.runtimeType}',
        );
      }

      // 3. If silent failed and UI is allowed, authenticate with driveAppdataScope in ONE dialog
      if (allowUI) {
        AppLogger.log(
          'GoogleDrive',
          'Triggering single interactive authenticate()',
        );
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: [drive.DriveApi.driveAppdataScope],
        );
        _cachedAccount = account;
        final prefs = CacheHelper.prefs;
        await prefs.setString('last_sync_email', account.email);
        AppLogger.log('GoogleDrive', 'Interactive auth completed');

        // Retrieve the authorized headers immediately
        final authHeaders = await GoogleSignIn.instance.authorizationClient
            .authorizationHeaders([
              drive.DriveApi.driveAppdataScope,
            ], promptIfNecessary: false);

        if (authHeaders != null) {
          _cachedAuthHeaders = authHeaders;
          AppLogger.log('GoogleDrive', 'DriveApi client ready');
          return drive.DriveApi(GoogleAuthClient(authHeaders));
        }
      }
      return null;
    } catch (e) {
      AppLogger.log('GoogleDrive', '_getDriveApi error type: ${e.runtimeType}');
      debugPrint('Google Drive: _getDriveApi error type: ${e.runtimeType}');
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final api = await _getDriveApi(allowUI: true);
      if (api != null) {
        return _cachedAccount;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _cachedAccount = null;
    _cachedAuthHeaders = null;
    final prefs = CacheHelper.prefs;
    await prefs.remove('last_sync_email');
    await prefs.remove('last_sync_time');
  }

  static Future<bool> syncToDrive({
    bool allowUI = true,
    void Function(double)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    if (_isSyncing) {
      AppLogger.logEvent('GoogleDrive', 'upload_skipped', {
        'reason': 'another_drive_sync_in_progress',
        'startedAt': startedAt.toIso8601String(),
      });
      debugPrint(
        'Google Drive: Sync already in progress, ignoring duplicate call.',
      );
      return false;
    }
    _isSyncing = true;
    var outcome = 'failure';
    var reason = 'unclassified_failure';
    try {
      AppLogger.logEvent('GoogleDrive', 'upload_started', {
        'startedAt': startedAt.toIso8601String(),
        'allowUI': allowUI,
      });
      debugPrint('Google Drive: Starting Sync to Drive...');
      final driveApi = await _getDriveApi(allowUI: allowUI);
      if (driveApi == null) {
        reason = 'authentication_unavailable_or_cancelled';
        debugPrint('Google Drive: Auth failed or cancelled.');
        return false;
      }

      onProgress?.call(0.1);
      final backupData = await _generateBackupData();
      onProgress?.call(0.3);
      final content = jsonEncode(backupData);
      onProgress?.call(0.5);
      final bytes = utf8.encode(content);
      onProgress?.call(0.7);

      final fileList = await driveApi.files
          .list(
            q: "name = '$_backupFileName' and 'appDataFolder' in parents",
            spaces: 'appDataFolder',
            $fields: 'files(id)',
          )
          .timeout(const Duration(minutes: 2));
      onProgress?.call(1.0);

      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final driveFile = drive.File()..name = _backupFileName;
        await driveApi.files
            .update(driveFile, fileId, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
        AppLogger.logEvent('GoogleDrive', 'upload_written', {
          'operation': 'update_existing_backup',
          'payloadBytes': bytes.length,
        });
        onProgress?.call(1.0);
      } else {
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files
            .create(driveFile, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
        AppLogger.logEvent('GoogleDrive', 'upload_written', {
          'operation': 'create_backup',
          'payloadBytes': bytes.length,
        });
        onProgress?.call(1.0);
      }

      final prefs = CacheHelper.prefs;
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      outcome = 'success';
      reason = 'backup_uploaded';
      debugPrint('Google Drive: Sync Up Successful.');
      return true;
    } catch (e) {
      reason = 'exception_${e.runtimeType}';
      debugPrint('Google Drive Sync Up error type: ${e.runtimeType}');
      return false;
    } finally {
      _isSyncing = false;
      AppLogger.logEvent('GoogleDrive', 'upload_finished', {
        'outcome': outcome,
        'reason': reason,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'allowUI': allowUI,
      });
    }
  }

  static Future<bool> syncFromDrive({
    bool allowUI = true,
    void Function(double)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    if (_isSyncing) {
      AppLogger.logEvent('GoogleDrive', 'restore_skipped', {
        'reason': 'another_drive_sync_in_progress',
        'startedAt': startedAt.toIso8601String(),
      });
      debugPrint(
        'Google Drive: Sync already in progress, ignoring duplicate call.',
      );
      return false;
    }
    _isSyncing = true;
    var outcome = 'failure';
    var reason = 'unclassified_failure';
    try {
      AppLogger.logEvent('GoogleDrive', 'restore_started', {
        'startedAt': startedAt.toIso8601String(),
        'allowUI': allowUI,
      });
      debugPrint('Google Drive: Starting Sync from Drive...');
      final driveApi = await _getDriveApi(allowUI: allowUI);
      if (driveApi == null) {
        reason = 'authentication_unavailable_or_cancelled';
        return false;
      }

      final fileList = await driveApi.files
          .list(
            q: "name = '$_backupFileName' and 'appDataFolder' in parents",
            spaces: 'appDataFolder',
            $fields: 'files(id)',
          )
          .timeout(const Duration(minutes: 2));
      onProgress?.call(1.0);

      if (fileList.files == null || fileList.files!.isEmpty) {
        reason = 'no_backup_found';
        debugPrint('Google Drive: No backup found.');
        return false;
      }

      final fileId = fileList.files!.first.id!;
      final response =
          await driveApi.files
                  .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia)
                  .timeout(const Duration(minutes: 3))
              as drive.Media;

      final List<int> dataBytes = [];
      await for (var chunk in response.stream) {
        dataBytes.addAll(chunk);
      }
      AppLogger.logEvent('GoogleDrive', 'restore_download_finished', {
        'downloadBytes': dataBytes.length,
        'durationMs': stopwatch.elapsedMilliseconds,
      });

      onProgress?.call(0.3);
      final content = utf8.decode(dataBytes);
      final decoded =
          await compute(jsonDecode, content) as Map<String, dynamic>;
      onProgress?.call(0.4);
      onProgress?.call(0.5);
      final result = await _applyBackupData(decoded, onProgress: onProgress);

      if (result) {
        final prefs = CacheHelper.prefs;
        await prefs.setString(
          'last_sync_time',
          DateTime.now().toIso8601String(),
        );
        debugPrint('Google Drive: Sync Down Successful.');
        outcome = 'success';
        reason = 'backup_downloaded_and_applied';
      } else {
        reason = 'backup_validation_or_application_failed';
      }
      return result;
    } catch (e) {
      reason = 'exception_${e.runtimeType}';
      debugPrint('Google Drive Sync Down error type: ${e.runtimeType}');
      return false;
    } finally {
      _isSyncing = false;
      AppLogger.logEvent('GoogleDrive', 'restore_finished', {
        'outcome': outcome,
        'reason': reason,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'allowUI': allowUI,
      });
    }
  }

  static Future<bool> isGoogleSignedIn() async {
    final prefs = CacheHelper.prefs;
    return prefs.getString('last_sync_email') != null;
  }

  static Future<String?> getSignedInEmail({bool forceCheck = false}) async {
    if (_cachedAccount?.email != null) {
      return _cachedAccount!.email;
    }
    final prefs = CacheHelper.prefs;
    return prefs.getString('last_sync_email');
  }

  static Future<String?> getLastSyncTime() async {
    final prefs = CacheHelper.prefs;
    await prefs.reload();
    return prefs.getString('last_sync_time');
  }

  static const int _autoSyncAlarmId = 888;
  static const String _autoSyncRetryUntilKey = 'auto_sync_retry_until';
  static const String _autoSyncNextScheduledAtKey =
      'auto_sync_next_scheduled_for';
  static const String _autoSyncNextScheduledEpochMsKey =
      'auto_sync_next_scheduled_epoch_ms';
  static const String _autoSyncRecoveryPendingKey =
      'auto_sync_recovery_pending';
  static const String _autoSyncRecoveryAttemptsRemainingKey =
      'auto_sync_recovery_attempts_remaining';
  static const String _autoSyncLastShutdownEpochMsKey =
      'auto_sync_last_shutdown_epoch_ms';

  static Future<void> _markRecoveryIfScheduleWasMissedWhilePoweredOff(
    DateTime now,
  ) async {
    final prefs = CacheHelper.prefs;
    final shutdownEpoch = int.tryParse(
      prefs.getString(_autoSyncLastShutdownEpochMsKey) ?? '',
    );
    if (shutdownEpoch == null) return;

    final recoveryAlreadyActive = prefs.containsKey(
      _autoSyncRecoveryAttemptsRemainingKey,
    );
    final scheduledEpoch = int.tryParse(
      prefs.getString(_autoSyncNextScheduledEpochMsKey) ?? '',
    );
    if (!recoveryAlreadyActive &&
        scheduledEpoch != null &&
        scheduledEpoch > shutdownEpoch &&
        scheduledEpoch <= now.millisecondsSinceEpoch) {
      await prefs.setBool(_autoSyncRecoveryPendingKey, true);
      AppLogger.logEvent('DriveAutoSync', 'missed_run_detected', {
        'scheduledFor': DateTime.fromMillisecondsSinceEpoch(
          scheduledEpoch,
        ).toIso8601String(),
        'poweredOffAt': DateTime.fromMillisecondsSinceEpoch(
          shutdownEpoch,
        ).toIso8601String(),
        'detectedAt': now.toIso8601String(),
        'reason': 'scheduled_time_passed_while_device_powered_off',
      });
    }
    await prefs.remove(_autoSyncLastShutdownEpochMsKey);
  }

  static Future<int?> beginAutoSyncAttempt() async {
    final prefs = CacheHelper.prefs;
    await _markRecoveryIfScheduleWasMissedWhilePoweredOff(DateTime.now());
    if (prefs.getBool(_autoSyncRecoveryPendingKey) == true) {
      if (!prefs.containsKey(_autoSyncRecoveryAttemptsRemainingKey)) {
        await prefs.setInt(
          _autoSyncRecoveryAttemptsRemainingKey,
          BackupSyncSchedule.maxPowerRecoveryAttempts,
        );
      }
      await prefs.remove(_autoSyncRetryUntilKey);
      await prefs.remove(_autoSyncRecoveryPendingKey);
    }

    final remaining = prefs.getInt(_autoSyncRecoveryAttemptsRemainingKey) ?? 0;
    if (remaining <= 0) return null;
    final attemptsRemaining =
        BackupSyncSchedule.attemptsRemainingAfterPowerRecoveryAttempt(
          remaining,
        );
    await prefs.setInt(
      _autoSyncRecoveryAttemptsRemainingKey,
      attemptsRemaining,
    );
    AppLogger.logEvent('DriveAutoSync', 'recovery_attempt_started', {
      'attemptsBeforeThisAttempt': remaining,
      'attemptsRemainingAfterThisAttempt': attemptsRemaining,
      'startedAt': DateTime.now().toIso8601String(),
    });
    return attemptsRemaining;
  }

  static Future<DateTime?> _resumePowerRecoveryIfNeeded(DateTime now) async {
    final prefs = CacheHelper.prefs;
    await _markRecoveryIfScheduleWasMissedWhilePoweredOff(now);
    if (prefs.getBool(_autoSyncRecoveryPendingKey) == true) {
      if (!prefs.containsKey(_autoSyncRecoveryAttemptsRemainingKey)) {
        await prefs.setInt(
          _autoSyncRecoveryAttemptsRemainingKey,
          BackupSyncSchedule.maxPowerRecoveryAttempts,
        );
      }
      await prefs.remove(_autoSyncRetryUntilKey);
      await prefs.remove(_autoSyncRecoveryPendingKey);
      final firstAttempt = now.add(const Duration(seconds: 5));
      await _scheduleAutoSyncAt(
        firstAttempt,
        reason: 'power_on_recovery_first_attempt',
      );
      return firstAttempt;
    }

    final remaining = prefs.getInt(_autoSyncRecoveryAttemptsRemainingKey) ?? 0;
    if (remaining <= 0) {
      if (prefs.containsKey(_autoSyncRecoveryAttemptsRemainingKey)) {
        await prefs.remove(_autoSyncRecoveryAttemptsRemainingKey);
      }
      return null;
    }

    final scheduledAtValue = prefs.getString(_autoSyncNextScheduledAtKey);
    final scheduledAt = scheduledAtValue == null
        ? null
        : DateTime.tryParse(scheduledAtValue);
    final nextAttempt = scheduledAt != null && scheduledAt.isAfter(now)
        ? scheduledAt
        : now.add(const Duration(seconds: 5));
    await _scheduleAutoSyncAt(
      nextAttempt,
      reason: 'power_on_recovery_followup',
    );
    return nextAttempt;
  }

  static Future<DateTime> getNextAutoSyncTime({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final prefs = CacheHelper.prefs;
    if (prefs.getBool(_autoSyncRecoveryPendingKey) == true) {
      return current.add(const Duration(seconds: 5));
    }
    final recoveryRemaining =
        prefs.getInt(_autoSyncRecoveryAttemptsRemainingKey) ?? 0;
    if (recoveryRemaining > 0) {
      final scheduledAtValue = prefs.getString(_autoSyncNextScheduledAtKey);
      final scheduledAt = scheduledAtValue == null
          ? null
          : DateTime.tryParse(scheduledAtValue);
      if (scheduledAt != null && scheduledAt.isAfter(current)) {
        return scheduledAt;
      }
      return current.add(const Duration(seconds: 5));
    }
    final retryUntilValue = prefs.getString(_autoSyncRetryUntilKey);
    final retryUntil = retryUntilValue == null
        ? null
        : DateTime.tryParse(retryUntilValue);

    if (retryUntil != null && retryUntil.isAfter(current)) {
      final retryAt = BackupSyncSchedule.nextHourlyRetry(
        now: current,
        fajr: retryUntil,
      );
      if (retryAt != null) return retryAt;
    }
    if (retryUntilValue != null) {
      await prefs.remove(_autoSyncRetryUntilKey);
    }

    return _getNextDailyAutoSyncTime(current);
  }

  static Future<DateTime> _getNextDailyAutoSyncTime(DateTime now) async {
    final todayTimes = await PrayerService.getPrayerTimesForDateStatic(now);
    if (todayTimes != null) {
      final todayTarget = todayTimes.isha.add(BackupSyncSchedule.afterIsha);
      if (todayTarget.isAfter(now)) return todayTarget;

      final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
      final tomorrowTimes = await PrayerService.getPrayerTimesForDateStatic(
        tomorrowDate,
      );
      if (tomorrowTimes != null) {
        return BackupSyncSchedule.nextDailyRun(
          now: now,
          todayIsha: todayTimes.isha,
          tomorrowIsha: tomorrowTimes.isha,
        );
      }
    }

    final fallbackToday = DateTime(now.year, now.month, now.day, 23);
    return fallbackToday.isAfter(now)
        ? fallbackToday
        : DateTime(now.year, now.month, now.day + 1, 23);
  }

  static Future<DateTime?> _fajrForNightOf(
    DateTime scheduledAt, {
    required DateTime now,
  }) async {
    final scheduledDate = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    );
    final todayTimes = await PrayerService.getPrayerTimesForDateStatic(
      scheduledDate,
    );
    if (todayTimes == null) return _nextFajrAfter(now);

    final tomorrowDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day + 1,
    );
    final tomorrowTimes = await PrayerService.getPrayerTimesForDateStatic(
      tomorrowDate,
    );
    final retryDeadline = BackupSyncSchedule.retryDeadline(
      now: now,
      scheduledAt: scheduledAt,
      ishaOnScheduledDate: todayTimes.isha,
      fajrOnScheduledDate: todayTimes.fajr,
      fajrOnNextDate: tomorrowTimes?.fajr,
    );
    if (retryDeadline != null && retryDeadline.isAfter(now)) {
      return retryDeadline;
    }
    return _nextFajrAfter(now);
  }

  static Future<DateTime?> _nextFajrAfter(DateTime now) async {
    final todayTimes = await PrayerService.getPrayerTimesForDateStatic(now);
    if (todayTimes != null && todayTimes.fajr.isAfter(now)) {
      return todayTimes.fajr;
    }

    final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
    final tomorrowTimes = await PrayerService.getPrayerTimesForDateStatic(
      tomorrowDate,
    );
    return tomorrowTimes?.fajr;
  }

  static Future<void> _scheduleAutoSyncAt(
    DateTime scheduledTime, {
    String reason = 'unspecified',
  }) async {
    await CacheHelper.prefs.setString(
      _autoSyncNextScheduledAtKey,
      scheduledTime.toIso8601String(),
    );
    await CacheHelper.prefs.setString(
      _autoSyncNextScheduledEpochMsKey,
      scheduledTime.millisecondsSinceEpoch.toString(),
    );
    final requestedAt = DateTime.now();
    AppLogger.logEvent('DriveAutoSync', 'schedule_requested', {
      'reason': reason,
      'requestedAt': requestedAt.toIso8601String(),
      'scheduledFor': scheduledTime.toIso8601String(),
      'alarmId': _autoSyncAlarmId,
    });
    try {
      final scheduled = await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        _autoSyncAlarmId,
        driveAutoSyncTask,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      AppLogger.logEvent(
        'DriveAutoSync',
        scheduled ? 'schedule_accepted' : 'schedule_failed',
        {
          'reason': reason,
          'requestedAt': requestedAt.toIso8601String(),
          'scheduledFor': scheduledTime.toIso8601String(),
          'exact': true,
          'allowWhileIdle': true,
          if (!scheduled) 'failureReason': 'alarm_manager_returned_false',
        },
      );
      if (!scheduled) {
        debugPrint('Google Drive: Auto-sync alarm scheduling failed.');
      }
    } catch (error) {
      AppLogger.logEvent('DriveAutoSync', 'schedule_failed', {
        'reason': reason,
        'requestedAt': requestedAt.toIso8601String(),
        'scheduledFor': scheduledTime.toIso8601String(),
        'failureReason': 'exception_${error.runtimeType}: $error',
      });
      rethrow;
    }
  }

  static Future<void> scheduleAfterSuccessfulAutoSync() async {
    final prefs = CacheHelper.prefs;
    await prefs.remove(_autoSyncRetryUntilKey);
    await prefs.remove(_autoSyncRecoveryAttemptsRemainingKey);
    await prefs.remove(_autoSyncRecoveryPendingKey);
    await scheduleNextAutoSync(reason: 'after_successful_auto_sync');
  }

  static Future<void> scheduleRetryAfterFailedAutoSync({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final prefs = CacheHelper.prefs;
    final recoveryRemaining =
        prefs.getInt(_autoSyncRecoveryAttemptsRemainingKey) ?? 0;
    if (recoveryRemaining > 0) {
      final recoveryRetry = BackupSyncSchedule.nextPowerRecoveryRetry(
        now: current,
        attemptsRemaining: recoveryRemaining,
      );
      if (recoveryRetry != null) {
        AppLogger.logEvent('DriveAutoSync', 'retry_decided', {
          'retryAt': recoveryRetry.toIso8601String(),
          'retryReason': 'power_recovery_attempt_failed',
          'attemptsRemaining': recoveryRemaining,
        });
        await _scheduleAutoSyncAt(
          recoveryRetry,
          reason: 'failed_power_recovery_retry',
        );
        return;
      }
    }
    if (prefs.containsKey(_autoSyncRecoveryAttemptsRemainingKey)) {
      await prefs.remove(_autoSyncRecoveryAttemptsRemainingKey);
    }

    final retryUntilValue = prefs.getString(_autoSyncRetryUntilKey);
    final savedRetryUntil = retryUntilValue == null
        ? null
        : DateTime.tryParse(retryUntilValue);
    DateTime? retryUntil;

    if (retryUntilValue != null) {
      if (savedRetryUntil != null && savedRetryUntil.isAfter(current)) {
        retryUntil = savedRetryUntil;
      }
    } else {
      final scheduledAtValue = prefs.getString(_autoSyncNextScheduledAtKey);
      final scheduledAt = scheduledAtValue == null
          ? null
          : DateTime.tryParse(scheduledAtValue);
      retryUntil = scheduledAt == null
          ? await _nextFajrAfter(current)
          : await _fajrForNightOf(scheduledAt, now: current);
    }

    if (retryUntil == null || !retryUntil.isAfter(current)) {
      await prefs.remove(_autoSyncRetryUntilKey);
      await scheduleNextAutoSync(reason: 'retry_window_unavailable');
      return;
    }

    await prefs.setString(_autoSyncRetryUntilKey, retryUntil.toIso8601String());
    final retryAt = BackupSyncSchedule.nextHourlyRetry(
      now: current,
      fajr: retryUntil,
    );
    if (retryAt == null) {
      await prefs.remove(_autoSyncRetryUntilKey);
      await scheduleNextAutoSync(reason: 'hourly_retry_window_closed');
      return;
    }
    AppLogger.logEvent('DriveAutoSync', 'retry_decided', {
      'retryAt': retryAt.toIso8601String(),
      'retryUntil': retryUntil.toIso8601String(),
      'retryReason': 'sync_failed_retry_hourly_until_fajr',
      'recoveryAttemptsRemaining': recoveryRemaining,
    });
    await _scheduleAutoSyncAt(
      retryAt,
      reason: 'hourly_retry_after_sync_failure',
    );
  }

  static Future<void> scheduleNextAutoSync({
    String reason = 'auto_sync_enabled_or_app_start',
  }) async {
    final recoveryTime = await _resumePowerRecoveryIfNeeded(DateTime.now());
    if (recoveryTime != null) {
      debugPrint('Google Drive: Power-on recovery scheduled for $recoveryTime');
      return;
    }
    final scheduledTime = await getNextAutoSyncTime();
    debugPrint('Google Drive: Auto-sync scheduled for $scheduledTime');
    await _scheduleAutoSyncAt(scheduledTime, reason: reason);
  }

  static Future<void> toggleAutoSync(bool enable) async {
    if (enable) {
      await scheduleNextAutoSync(reason: 'user_enabled_auto_sync');
    } else {
      await AndroidAlarmManager.cancel(_autoSyncAlarmId);
      AppLogger.logEvent('DriveAutoSync', 'schedule_cancelled', {
        'reason': 'user_disabled_auto_sync',
        'cancelledAt': DateTime.now().toIso8601String(),
        'alarmId': _autoSyncAlarmId,
      });
      final prefs = CacheHelper.prefs;
      await prefs.remove(_autoSyncRetryUntilKey);
      await prefs.remove(_autoSyncNextScheduledAtKey);
      await prefs.remove(_autoSyncNextScheduledEpochMsKey);
      await prefs.remove(_autoSyncRecoveryPendingKey);
      await prefs.remove(_autoSyncRecoveryAttemptsRemainingKey);
      await prefs.remove(_autoSyncLastShutdownEpochMsKey);
    }
  }
}
