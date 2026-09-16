import 'package:intl/intl.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/remote_config_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

class IslamicDay {
  /// Returns the Islamic-calendar date key (yyyy-MM-dd) for "now",
  /// advancing to the next day if current time is after today's Maghrib.
  static Future<String> todayKey() async {
    final now = DateTime.now();
    final times = await PrayerService.getPrayerTimesForDateStatic(now);
    final maghrib = times?.maghrib ?? DateTime(now.year, now.month, now.day, 18, 0);
    final date = now.isAfter(maghrib)
        ? now.add(const Duration(days: 1))
        : now;
        
    final h = PrayerService.getHijriWithOffset(
      RemoteConfigService.globalHijriOffset, 
      date
    );
    await CacheHelper.prefs.setInt('current_hijri_day', h.hDay);
    
    final key = DateFormat('yyyy-MM-dd').format(date);
    AppLogger.log("IslamicDay", "todayKey() -> now: ${now.toIso8601String()}, maghrib: ${maghrib.toIso8601String()}, key: $key");
    return key;
  }

  static String todayKeySync() {
    final now = DateTime.now();
    final times = PrayerService().getPrayerTimesForDate(now);
    final maghrib = times?.maghrib ?? DateTime(now.year, now.month, now.day, 18, 0);
    final date = now.isAfter(maghrib)
        ? now.add(const Duration(days: 1))
        : now;
        
    // Save current Hijri day for Kotlin background check
    final h = PrayerService.getHijriWithOffset(
      RemoteConfigService.globalHijriOffset, 
      date
    );
    CacheHelper.prefs.setInt('current_hijri_day', h.hDay);
        
    final key = DateFormat('yyyy-MM-dd').format(date);
    AppLogger.log("IslamicDay", "todayKeySync() -> now: ${now.toIso8601String()}, maghrib: ${maghrib.toIso8601String()}, key: $key");
    return key;
  }
}
