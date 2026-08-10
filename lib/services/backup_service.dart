import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
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

class BackupService {
  static const String _backupFileName = 'ibad_al_rahmann_backup.json';
  static const String _currentVersion = '1.2.0';

  static bool _isGoogleSignInInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  /// Helper to get backup data as a Map
  static Future<Map<String, dynamic>> _generateBackupData() async {
    final Map<String, dynamic> backupData = {
      'version': _currentVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'preferences': {},
      'bookmarks': [],
      'khatmas': {},
    };

    // 1. Gather SharedPreferences
    final prefs = CacheHelper.prefs;
    final allKeys = prefs.getKeys();
    
    // Blacklist transient or machine-specific keys
    // ملاحظة: تم إزالة "temp_" للسماح بنسخ سجلات الصيام وصلاتي والأذكار
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
      
      if (!isBlacklisted) {
        backupData['preferences'][key] = prefs.get(key);
      }
    }

    // 2. Gather Hive Bookmarks (Quran)
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

    // 3. Gather Hive Khatmas (Wird progress) from appDataBox
    try {
      final appBox = Hive.box('appDataBox');
      final Map<String, dynamic> khatmasMap = {};
      for (var key in appBox.keys) {
        final keyStr = key.toString();
        if (keyStr.startsWith('khatma_')) {
          final value = appBox.get(key);
          if (value != null) {
            khatmasMap[keyStr] = value; // stored as JSON string
          }
        }
      }
      backupData['khatmas'] = khatmasMap;
      debugPrint('Backup: saved ${khatmasMap.length} khatmas');
    } catch (e) {
      debugPrint('Backup khatmas error: $e');
    }

    return backupData;
  }

  /// Export all settings and bookmarks to a JSON file and share it.
  static Future<bool> exportBackup() async {
    try {
      final backupData = await _generateBackupData();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$_backupFileName');
      await file.writeAsString(jsonEncode(backupData));
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية لإعدادات تطبيق عباد الرحمن');
      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }

  /// Save backup to device manually using file picker.
  static Future<bool> saveBackupToDevice() async {
    try {
      final backupData = await _generateBackupData();
      final content = jsonEncode(backupData);
      final bytes = utf8.encode(content);
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: _backupFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      return outputPath != null;
    } catch (e) {
      debugPrint('Save to device error: $e');
      return false;
    }
  }

  /// Import settings and bookmarks from a JSON file.
  static Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return false;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      return await _applyBackupData(jsonDecode(content));
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  static Future<bool> _applyBackupData(Map<String, dynamic> backupData) async {
    try {
      if (backupData['version'] == null) return false;

      // 1. Restore SharedPreferences
      final prefs = CacheHelper.prefs;
      final Map<String, dynamic> preferences = backupData['preferences'] ?? {};
      
      for (var entry in preferences.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }
      
      // Reschedule alarms with restored preferences
      try {
        PrayerService().scheduleNotificationsDebounced();
      } catch (_) {}

      // 2. Restore Hive Bookmarks (Quran)
      if (backupData['bookmarks'] != null) {
        if (!BookmarkService.box.isOpen) await BookmarkService.init();
        await BookmarkService.clearAllBookmarks();
        final List<dynamic> bookmarksData = backupData['bookmarks'];
        for (var bData in bookmarksData) {
          final verse = VerseModel(
            surahNumber: bData['surahNumber'],
            verseNumber: bData['verseNumber'],
            verse: bData['verse'],
            fontFamily: bData['fontFamily'],
            bookmarkedAt: DateTime.parse(bData['bookmarkedAt']),
            label: bData['label'],
          );
          await BookmarkService.addBookmark(verse);
        }
      }

      // 3. Restore Hive Khatmas (Wird progress)
      if (backupData['khatmas'] != null) {
        try {
          final appBox = Hive.box('appDataBox');
          final Map<String, dynamic> khatmasMap = Map<String, dynamic>.from(backupData['khatmas']);
          for (var entry in khatmasMap.entries) {
            if (entry.key.startsWith('khatma_')) {
              await appBox.put(entry.key, entry.value);
            }
          }
          debugPrint('Restore: restored ${khatmasMap.length} khatmas to appDataBox');
        } catch (e) {
          debugPrint('Restore khatmas error: $e');
        }
      }

      // 4. Reschedule all notifications with newly restored settings
      PrayerService().scheduleNotifications();
      NotificationService.rescheduleWird();
      
      return true;
    } catch (e) {
      debugPrint('Apply backup error: $e');
      return false;
    }
  }

  // ── Google Drive Sync Methods ──────────────────────────────────────────

  static Future<GoogleSignInAccount?> _getSignedInAccount({bool allowUI = true}) async {
    try {
      await _ensureInitialized();
      // 1. Try lightweight authentication first
      GoogleSignInAccount? account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      
      // 2. If silent failed and UI is allowed, try full sign-in
      if (account == null && allowUI) {
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: [drive.DriveApi.driveAppdataScope],
        );
      }

      if (account != null) {
        // Double check scopes
        final authClient = GoogleSignIn.instance.authorizationClient;
        bool hasScope = (await authClient.authorizationForScopes([drive.DriveApi.driveAppdataScope])) != null;
        if (!hasScope && allowUI) {
          await authClient.authorizeScopes([drive.DriveApi.driveAppdataScope]);
        }
      }
      return account;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
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

  static Future<bool> syncToDrive({bool allowUI = true}) async {
    try {
      debugPrint('Google Drive: Starting Sync to Drive...');
      final account = await _getSignedInAccount(allowUI: allowUI);
      if (account == null) {
        debugPrint('Google Drive: Auth failed or cancelled.');
        return false;
      }

      final authHeaders = await GoogleSignIn.instance.authorizationClient.authorizationHeaders(
        [drive.DriveApi.driveAppdataScope],
        promptIfNecessary: allowUI,
      );
      if (authHeaders == null) {
        debugPrint('Google Drive: Auth headers failed.');
        return false;
      }
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final backupData = await _generateBackupData();
      final content = jsonEncode(backupData);
      final bytes = utf8.encode(content);

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      ).timeout(const Duration(minutes: 2));

      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final driveFile = drive.File()..name = _backupFileName;
        await driveApi.files.update(driveFile, fileId, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
      } else {
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media)
            .timeout(const Duration(minutes: 2));
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

  static Future<bool> syncFromDrive({bool allowUI = true}) async {
    try {
      debugPrint('Google Drive: Starting Sync from Drive...');
      final account = await _getSignedInAccount(allowUI: allowUI);
      if (account == null) return false;

      final authHeaders = await GoogleSignIn.instance.authorizationClient.authorizationHeaders(
        [drive.DriveApi.driveAppdataScope],
        promptIfNecessary: allowUI,
      );
      if (authHeaders == null) {
        debugPrint('Google Drive: Auth headers failed.');
        return false;
      }
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('Google Drive: No backup found.');
        return false;
      }

      final fileId = fileList.files!.first.id!;
      final response = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final List<int> dataBytes = [];
      await for (var chunk in response.stream) {
        dataBytes.addAll(chunk);
      }
      
      final content = utf8.decode(dataBytes);
      final result = await _applyBackupData(jsonDecode(content));
      
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
    await _ensureInitialized();
    return (await GoogleSignIn.instance.attemptLightweightAuthentication()) != null;
  }

  static Future<String?> getSignedInEmail() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account?.email != null) {
        final prefs = CacheHelper.prefs;
        await prefs.setString('last_sync_email', account!.email);
        return account.email;
      }
    } catch (_) {}
    
    // Fallback to cached email if offline or silent sign-in delayed
    final prefs = CacheHelper.prefs;
    return prefs.getString('last_sync_email');
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
