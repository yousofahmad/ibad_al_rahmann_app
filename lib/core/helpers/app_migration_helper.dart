import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/prayer_times_cache.dart';
import '../../services/prayer_service.dart';

class AppMigrationHelper {
  static const int currentVersionCode = 10;
  static const String keyAppVersionCode = 'app_version_code_migrated';

  static Future<void> checkAndPerformMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getInt(keyAppVersionCode) ?? 0;

      if (lastVersion < currentVersionCode) {
        debugPrint('🚀 AppMigrationHelper: Running migration from v$lastVersion to v$currentVersionCode...');
        
        // 1. Clear obsolete prayer caches & old cached hijri epochs
        await PrayerTimesCache.clearStaleEntries();
        await prefs.remove('prayer_times_30d');
        await prefs.remove('hijri_cache_start_epoch');
        
        // 2. Remove obsolete / buggy legacy preference keys
        final allKeys = prefs.getKeys();
        for (final k in allKeys) {
          if (k.startsWith('temp_prayer_') || k.startsWith('old_alarm_') || k.startsWith('legacy_')) {
            await prefs.remove(k);
          }
        }

        // 3. Clear stale Google Sign-In session to ensure clean fresh sync
        try {
          await prefs.remove('google_signed_in_email');
          await prefs.remove('last_sync_time');
          await GoogleSignIn.instance.signOut();
        } catch (_) {}

        // 4. Immediately refresh prayer calculations & native cache
        final prayerService = PrayerService();
        await prayerService.init();
        await prayerService.scheduleNotifications(isUserAction: true);

        // 5. Mark migration as done
        await prefs.setInt(keyAppVersionCode, currentVersionCode);
        debugPrint('✅ AppMigrationHelper: Migration to v$currentVersionCode complete!');
      }
    } catch (e) {
      debugPrint('⚠️ AppMigrationHelper error: $e');
    }
  }
}
