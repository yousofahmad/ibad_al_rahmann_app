import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

@pragma('vm:entry-point')
Future<void> driveAutoSyncTask() async {
  // Required for background tasks
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(VerseModelAdapter());
  }
  await BookmarkService.init();

  final success = await BackupService.syncToDrive(allowUI: false);
  
  // Log the result for debugging
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_auto_sync_status', '${DateTime.now().toIso8601String()}: $success');
    
    if (success) {
      await NotificationService.showImmediateNotification(
        title: "النسخ الاحتياطي",
        body: "تمت مزامنة بياناتك مع جوجل درايف بنجاح.",
        payload: "settings",
      );
    }
  } catch (_) {}
  
  debugPrint('Auto-sync to Google Drive: $success');
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
  static const String _currentVersion = '1.1.0';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  /// Helper to get backup data as a Map
  static Future<Map<String, dynamic>> _generateBackupData() async {
    final Map<String, dynamic> backupData = {
      'version': _currentVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'preferences': {},
      'bookmarks': [],
    };

    // 1. Gather SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    // Blacklist transient or machine-specific keys
    final blacklist = {
      'last_sync_time', 
      'temp_', 
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

    // 2. Gather Hive Bookmarks
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
      final prefs = await SharedPreferences.getInstance();
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

      // 2. Restore Hive Bookmarks
      if (backupData['bookmarks'] != null) {
        if (!BookmarkService.box.isOpen) await BookmarkService.init();
        await BookmarkService.clearAllBookmarks(); // Clear old ones to prevent duplicates
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

      // 3. Reschedule all notifications with newly restored settings
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
      // 1. Try silent sign-in first
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      
      // 2. If silent failed and UI is allowed, try full sign-in
      if (account == null && allowUI) {
        account = await _googleSignIn.signIn();
      }

      if (account != null) {
        // Double check scopes
        bool hasScope = await _googleSignIn.canAccessScopes([drive.DriveApi.driveAppdataScope]).catchError((_) => true);
        if (!hasScope && allowUI) {
          await _googleSignIn.requestScopes([drive.DriveApi.driveAppdataScope]);
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
    await _googleSignIn.signOut();
  }

  static Future<bool> syncToDrive({bool allowUI = true}) async {
    try {
      debugPrint('Google Drive: Starting Sync to Drive...');
      final account = await _getSignedInAccount(allowUI: allowUI);
      if (account == null) {
        debugPrint('Google Drive: Auth failed or cancelled.');
        return false;
      }

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final backupData = await _generateBackupData();
      final content = jsonEncode(backupData);
      final bytes = utf8.encode(content);

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final driveFile = drive.File()..name = _backupFileName;
        await driveApi.files.update(driveFile, fileId, uploadMedia: media);
      } else {
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      
      final prefs = await SharedPreferences.getInstance();
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

      final authHeaders = await account.authHeaders;
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
        final prefs = await SharedPreferences.getInstance();
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
    return await _googleSignIn.isSignedIn();
  }

  static Future<String?> getSignedInEmail() async {
    try {
      final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (account?.email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sync_email', account!.email);
        return account.email;
      }
    } catch (_) {}
    
    // Fallback to cached email if offline or silent sign-in delayed
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_email');
  }

  static Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_time');
  }

  static Future<void> toggleAutoSync(bool enable) async {
    const int autoSyncAlarmId = 888;
    if (enable) {
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

      await AndroidAlarmManager.periodic(
        const Duration(hours: 24),
        autoSyncAlarmId,
        driveAutoSyncTask,
        startAt: scheduledTime,
        exact: false, // More reliable for periodic background tasks on some devices
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } else {
      await AndroidAlarmManager.cancel(autoSyncAlarmId);
    }
  }
}
