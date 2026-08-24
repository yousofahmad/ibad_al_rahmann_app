import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

@pragma('vm:entry-point')
Future<void> driveAutoSyncTask() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await CacheHelper.init();
      // تهيئة Hive بالمسار الصحيح لمعالجة الخلفية
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(VerseModelAdapter());
      }
      try {
        await BookmarkService.init();
      } catch (_) {} // لا توقف لو فشلت المفاتيح — الإعدادات أهم
      try {
        if (!Hive.isBoxOpen('appDataBox')) await Hive.openBox('appDataBox');
      } catch (_) {}

      // 1. مزامنة مع مهلة دقيقتين للنت الضعيف
      final success = await BackupService.syncToDrive(allowUI: false);

      final prefs = CacheHelper.prefs;
      await prefs.setString('last_auto_sync_status', '${DateTime.now().toIso8601String()}: $success');

      // إشعار تأكيد المزامنة (مهم لتأكيد أن الميزة تعمل)
      try {
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
        const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
        await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

        final title = success ? "المزامنة التلقائية ✓" : "فشل المزامنة التلقائية";
        final body = success
            ? "تمت مزامنة بياناتك مع جوجل درايف بنجاح."
            : "تعذرت المزامنة، يرجى التحقق من الاتصال أو تسجيل الدخول.";

        await flutterLocalNotificationsPlugin.show(
          id: 99999,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'strictly_silent_channel_v8',
              'التنبيهات الصامتة',
              importance: Importance.low,
              priority: Priority.low,
              silent: true,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Drive sync notification error: $e');
      }

      // جدولة المزامنة لليوم التالي بعد العشاء بساعة
      await BackupService.scheduleNextAutoSync();

      debugPrint('Auto-sync to Google Drive completed: $success');
    } catch (e) {
      debugPrint('driveAutoSyncTask error: $e');
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

enum BackupCategory {
  bookmarks,
  khatmas,
  prayers,
  tracker,
  settings,
}

class BackupService {
  static const String _backupFileName = 'ibad_al_rahmann_backup.json';
  static const String _currentVersion = '1.2.0';

  static const String _serverClientId = '1029405862241-u0m400hgjnmjsb60g6e4qcop3gd41fbp.apps.googleusercontent.com';
  static bool _isGoogleSignInInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );
      _isGoogleSignInInitialized = true;
    }
  }

  /// Helper to get backup data as a Map (supports full or selective backup)
  static Future<Map<String, dynamic>> _generateBackupData({Set<BackupCategory>? categories}) async {
    final Map<String, dynamic> backupData = {
      'version': _currentVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'preferences': {},
      'bookmarks': [],
      'khatmas': {},
    };

    final includeAll = categories == null;
    final includeBookmarks = includeAll || categories.contains(BackupCategory.bookmarks);
    final includeKhatmas = includeAll || categories.contains(BackupCategory.khatmas);
    final includePrayers = includeAll || categories.contains(BackupCategory.prayers);
    final includeTracker = includeAll || categories.contains(BackupCategory.tracker);
    final includeSettings = includeAll || categories.contains(BackupCategory.settings);

    // 1. Gather SharedPreferences
    final prefs = CacheHelper.prefs;
    final allKeys = prefs.getKeys();
    
    // Blacklist transient or machine-specific keys
    final blacklist = {
      'last_sync_time', 
      'cache_', 
      'lib_cash',
      'firebase_token',
      'last_auto_sync_status',
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

      bool isPrayerKey = key.startsWith('adhan_') || key.startsWith('iqama_') || key.startsWith('notif_prayer_') || key.startsWith('adjust_') || key.startsWith('sound_') || key.startsWith('calc_method') || key.startsWith('asr_calc') || key.startsWith('city_') || key.startsWith('lat') || key.startsWith('long');
      bool isTrackerKey = key.startsWith('temp_') || key.startsWith('prayer_focus_log_') || key.startsWith('accountability_') || key.startsWith('fasting_') || key.startsWith('sabah_') || key.startsWith('masaa_') || key.startsWith('daily_tracker_') || key.startsWith('prayer_streak_') || key.startsWith('azkar_') || key.startsWith('count_') || key.startsWith('streak_');
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
        backupData['bookmarks'] = bookmarks.map((b) => {
          'surahNumber': b.surahNumber,
          'verseNumber': b.verseNumber,
          'verse': b.verse,
          'fontFamily': b.fontFamily,
          'bookmarkedAt': b.bookmarkedAt.toIso8601String(),
          'label': b.label,
        }).toList();
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
          if (keyStr.startsWith('khatma_')) {
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
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية لإعدادات تطبيق عباد الرحمن');
      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }

  /// Save backup to device manually using file picker (supports selective backup).
  static Future<bool> saveBackupToDevice({Set<BackupCategory>? categories, void Function(double)? onProgress}) async {
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
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
        );
      }

      if (result == null || result.files.single.path == null) return false;
      final file = File(result.files.single.path!);
      onProgress?.call(0.2);
      final content = await file.readAsString();
      final decoded = await compute(jsonDecode, content) as Map<String, dynamic>;
      onProgress?.call(0.4);
      onProgress?.call(0.5);
      return await _applyBackupData(decoded, onProgress: onProgress, startProgress: 0.4);
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  static Future<bool> _applyBackupData(Map<String, dynamic> backupData, {void Function(double)? onProgress, double startProgress = 0.5}) async {
    try {
      if (backupData['version'] == null) {
        debugPrint('Restore: ❌ invalid backup — missing version');
        return false;
      }
      debugPrint('Restore: starting from backup version ${backupData['version']}');

      
        final Map<String, dynamic> prefsMap = (backupData['preferences'] as Map<String, dynamic>?) ?? {};
        final List<dynamic> bMap = (backupData['bookmarks'] as List<dynamic>?) ?? [];
        final Map<String, dynamic> kMap = backupData['khatmas'] != null ? Map<String, dynamic>.from(backupData['khatmas'] as Map) : {};
        int totalItems = prefsMap.length + bMap.length + kMap.length;
        if (totalItems == 0) totalItems = 1;
        int currentItem = 0;
// 1. Restore SharedPreferences ────────────────────────────────────────
      final prefs = CacheHelper.prefs;
      final Map<String, dynamic> preferences =
          (backupData['preferences'] as Map<String, dynamic>?) ?? {};

      int restoredCount = 0;
      int skippedCount  = 0;

      for (final entry in preferences.entries) {
        final key   = entry.key;
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
            debugPrint('Restore: ⚠️ skipped key "$key" — unknown type ${value.runtimeType}');
            skippedCount++;
            continue;
          }
          restoredCount++;
        } catch (e) {
          debugPrint('Restore: ❌ error writing key "$key": $e');
          skippedCount++;
        }
      }
      debugPrint('Restore: ✅ preferences — $restoredCount restored, $skippedCount skipped');

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
          final Map<String, dynamic> khatmasMap =
              Map<String, dynamic>.from(backupData['khatmas'] as Map);
          int kCount = 0;
          for (final entry in khatmasMap.entries) {
            if (entry.key.startsWith('khatma_')) {
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

  // ── Google Drive Sync Methods ──────────────────────────────────────────

  static Future<GoogleSignInAccount?> _getSignedInAccount({bool allowUI = true}) async {
    try {
      await _ensureInitialized();

      // 1. Try silent/lightweight authentication first
      GoogleSignInAccount? account;
      try {
        final authFuture = GoogleSignIn.instance.attemptLightweightAuthentication();
        if (authFuture != null) {
          account = await authFuture.timeout(const Duration(seconds: 3));
        }
        if (account != null) {
          AppLogger.log('GoogleDrive', 'silent auth OK: ${account.email}');
          debugPrint('Google Sign-In: silent auth OK — ${account.email}');
        } else {
          AppLogger.log('GoogleDrive', 'silent auth: no cached session');
          debugPrint('Google Sign-In: silent auth returned null (no cached session)');
        }
      } on TimeoutException {
        AppLogger.log('GoogleDrive', 'silent auth timed-out (3s)');
        debugPrint('Google Sign-In: silent auth timed-out after 3s');
        account = null;
      } catch (e) {
        AppLogger.log('GoogleDrive', 'silent auth error: $e');
        debugPrint('Google Sign-In: silent auth error — $e');
        account = null;
      }

      // 2. If silent failed and UI is allowed, trigger interactive sign-in
      if (account == null && allowUI) {
        AppLogger.log('GoogleDrive', 'triggering interactive authenticate()');
        debugPrint('Google Sign-In: triggering interactive authenticate()');
        try {
          account = await GoogleSignIn.instance.authenticate(
            scopeHint: [drive.DriveApi.driveAppdataScope],
          );
          AppLogger.log('GoogleDrive', 'interactive auth OK: ${account.email}');
          debugPrint('Google Sign-In: interactive auth OK — ${account.email}');
        } catch (e) {
          AppLogger.log('GoogleDrive', 'interactive auth error: $e');
          debugPrint('Google Sign-In: interactive auth error: $e');
        }
      }
      return account;
    } catch (e, st) {
      AppLogger.log('GoogleDrive', 'Google Sign-In Error: $e');
      debugPrint('Google Sign-In Error: $e\n$st');
      return null;
    }
  }

  /// Gets authenticated Drive API client. Returns null if auth fails.
  static Future<drive.DriveApi?> _getDriveApi({bool allowUI = true}) async {
    try {
      final account = await _getSignedInAccount(allowUI: allowUI);
      if (account == null) {
        AppLogger.log('GoogleDrive', 'No signed-in account — cannot get DriveApi');
        debugPrint('Google Drive: No signed-in account — cannot get DriveApi');
        return null;
      }

      final duration = allowUI ? const Duration(seconds: 30) : const Duration(seconds: 15);

      Map<String, String>? authHeaders;
      try {
        authHeaders = await GoogleSignIn.instance.authorizationClient
            .authorizationHeaders(
              [drive.DriveApi.driveAppdataScope],
              promptIfNecessary: allowUI,
            )
            .timeout(duration);
      } on TimeoutException {
        AppLogger.log('GoogleDrive', 'authorizationHeaders timed-out (${duration.inSeconds}s)');
        debugPrint('Google Drive: authorizationHeaders timed-out (${duration.inSeconds}s)');
        authHeaders = null;
      } catch (e) {
        AppLogger.log('GoogleDrive', 'authorizationHeaders error: $e');
        debugPrint('Google Drive: authorizationHeaders error — $e');
        authHeaders = null;
      }

      if (authHeaders == null) {
        AppLogger.log('GoogleDrive', 'authorizationHeaders null — trying forced re-authorize');
        debugPrint('Google Drive: authorizationHeaders null — trying forced re-authorize');
        if (allowUI) {
          try {
            await GoogleSignIn.instance.authorizationClient
                .authorizeScopes([drive.DriveApi.driveAppdataScope]);
            authHeaders = await GoogleSignIn.instance.authorizationClient
                .authorizationHeaders([drive.DriveApi.driveAppdataScope]);
          } catch (e) {
            AppLogger.log('GoogleDrive', 'forced re-authorize failed: $e');
            debugPrint('Google Drive: forced re-authorize failed — $e');
          }
        }
        if (authHeaders == null) {
          AppLogger.log('GoogleDrive', 'giving up — no valid auth headers');
          debugPrint('Google Drive: giving up — no valid auth headers');
          return null;
        }
      }

      AppLogger.log('GoogleDrive', 'DriveApi client ready for ${account.email}');
      debugPrint('Google Drive: DriveApi client ready');
      return drive.DriveApi(GoogleAuthClient(authHeaders));
    } catch (e) {
      AppLogger.log('GoogleDrive', '_getDriveApi error: $e');
      debugPrint('Google Drive: _getDriveApi error: $e');
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    return await _getSignedInAccount(allowUI: true);
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    final prefs = CacheHelper.prefs;
    await prefs.remove('last_sync_email');
    await prefs.remove('last_sync_time');
  }

  static Future<bool> syncToDrive({bool allowUI = true, void Function(double)? onProgress}) async {
    try {
      debugPrint('Google Drive: Starting Sync to Drive...');
      final driveApi = await _getDriveApi(allowUI: allowUI);
      if (driveApi == null) {
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

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      ).timeout(const Duration(minutes: 2));
        onProgress?.call(1.0);

      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final driveFile = drive.File()..name = _backupFileName;
        await driveApi.files.update(driveFile, fileId, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
        onProgress?.call(1.0);
      } else {
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
        onProgress?.call(1.0);
      }

      final prefs = CacheHelper.prefs;
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      debugPrint('Google Drive: Sync Up Successful.');
      return true;
    } catch (e) {
      debugPrint('Google Drive Sync Up Error: $e');
      return false;
    }
  }

  static Future<bool> syncFromDrive({bool allowUI = true, void Function(double)? onProgress}) async {
    try {
      debugPrint('Google Drive: Starting Sync from Drive...');
      final driveApi = await _getDriveApi(allowUI: allowUI);
      if (driveApi == null) return false;

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      ).timeout(const Duration(minutes: 2));
        onProgress?.call(1.0);

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('Google Drive: No backup found.');
        return false;
      }

      final fileId = fileList.files!.first.id!;
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ).timeout(const Duration(minutes: 3)) as drive.Media;

      final List<int> dataBytes = [];
      await for (var chunk in response.stream) {
        dataBytes.addAll(chunk);
      }

      onProgress?.call(0.3);
      final content = utf8.decode(dataBytes);
      final decoded = await compute(jsonDecode, content) as Map<String, dynamic>;
      onProgress?.call(0.4);
      onProgress?.call(0.5);
      final result = await _applyBackupData(decoded, onProgress: onProgress);

      if (result) {
        final prefs = CacheHelper.prefs;
        await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
        debugPrint('Google Drive: Sync Down Successful.');
      }
      return result;
    } catch (e) {
      debugPrint('Google Drive Sync Down Error: $e');
      return false;
    }
  }

  static Future<bool> isGoogleSignedIn() async {
    final prefs = CacheHelper.prefs;
    return prefs.getString('last_sync_email') != null;
  }

  static Future<String?> getSignedInEmail({bool forceCheck = false}) async {
    final prefs = CacheHelper.prefs;
    final cachedEmail = prefs.getString('last_sync_email');
    
    // تجنب محاولة تسجيل الدخول في كل مرة يتم فتح الإعدادات فيها
    // إلا إذا طلبنا التحديث صراحة أو كان المستخدم قد سجل دخوله بالفعل ونريد التأكد
    if (!forceCheck) {
      return cachedEmail;
    }

    try {
      await _ensureInitialized();
      GoogleSignInAccount? account;
      try {
        account = await (GoogleSignIn.instance
            .attemptLightweightAuthentication() ?? Future.value(null))
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        account = null;
      } catch (_) {
        account = null;
      }
      if (account?.email != null) {
        await prefs.setString('last_sync_email', account!.email);
        return account.email;
      }
    } catch (_) {}

    return cachedEmail;
  }

  static Future<String?> getLastSyncTime() async {
    final prefs = CacheHelper.prefs;
    await prefs.reload();
    return prefs.getString('last_sync_time');
  }

  static Future<void> scheduleNextAutoSync() async {
    const int autoSyncAlarmId = 888;
    final times = await PrayerService.getPrayerTimesForDateStatic(DateTime.now());
    DateTime scheduledTime;
    
    if (times != null) {
      // One hour after Isha
      scheduledTime = times.isha.add(const Duration(hours: 1));
    } else {
      // Fallback to 11:00 PM
      scheduledTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        23,
      );
    }
    
    // If the scheduled time for today has already passed, schedule for tomorrow
    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    debugPrint('Google Drive: Auto-sync scheduled for $scheduledTime');

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      autoSyncAlarmId,
      driveAutoSyncTask,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> toggleAutoSync(bool enable) async {
    const int autoSyncAlarmId = 888;
    if (enable) {
      await scheduleNextAutoSync();
    } else {
      await AndroidAlarmManager.cancel(autoSyncAlarmId);
    }
  }
}
