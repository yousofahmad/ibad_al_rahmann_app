import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'prayer_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class DailyTrackerService {
  static const String _lastStreakDateKey = 'last_streak_date';
  static const String _dailyPrefix = 'daily_';

  /// Internal helper to get the logical "Cycle Date" for Azkar.
  /// Morning Azkar cycle resets at Maghrib. Evening Azkar cycle resets at Fajr.
  static Future<String> _getCycleDate(String category) async {
    final now = DateTime.now();
    DateTime cycleDate = DateTime(now.year, now.month, now.day);

    if (category == 'morning_azkar' || category == 'evening_azkar') {
      try {
        final prayers = await PrayerService().getExtendedPrayers(date: now);
        if (category == 'morning_azkar') {
          final maghrib = prayers.firstWhere((p) => p.id == 'maghrib').time;
          if (now.isAfter(maghrib)) {
            cycleDate = now.add(const Duration(days: 1));
          }
        } else {
          final fajr = prayers.firstWhere((p) => p.id == 'fajr').time;
          if (now.isBefore(fajr)) {
            cycleDate = now.subtract(const Duration(days: 1));
          }
        }
      } catch (_) {}
    }
    return DateFormat('yyyy-MM-dd').format(cycleDate);
  }

  /// Marks a specific category as started for today.
  static Future<void> markAsStarted(String category) async {
    final prefs = CacheHelper.prefs;
    final String dateStr = await _getCycleDate(category);
    final String key = '$_dailyPrefix${dateStr}_${category}_started';
    await prefs.setBool(key, true);
  }

  /// Checks if a category is started today.
  static Future<bool> isStarted(String category) async {
    final prefs = CacheHelper.prefs;
    final String dateStr = await _getCycleDate(category);
    return prefs.getBool('$_dailyPrefix${dateStr}_${category}_started') ??
        false;
  }

  /// Marks a specific Azkar category as done for today.
  static Future<void> markAsDone(String category) async {
    final prefs = CacheHelper.prefs;
    final String dateStr = await _getCycleDate(category);
    final String key = '$_dailyPrefix${dateStr}_$category';

    if (!prefs.containsKey(key)) {
      await prefs.setBool(key, true);
      if (category == 'morning_azkar' || category == 'evening_azkar') {
        await _updateStreak(prefs, dateStr, category);
      }
    }
  }

  /// Checks if a category is done today.
  static Future<bool> isDone(String category) async {
    final prefs = CacheHelper.prefs;
    final String dateStr = await _getCycleDate(category);
    return prefs.getBool('$_dailyPrefix${dateStr}_$category') ?? false;
  }

  /// Updates the streak counter.
  static Future<void> _updateStreak(
    SharedPreferences prefs,
    String today,
    String azkarType,
  ) async {
    // Use per-type last date key to avoid cross-contamination
    final String lastDateKey = '${_lastStreakDateKey}_$azkarType';
    String? lastDate = prefs.getString(lastDateKey);
    int currentStreak = prefs.getInt('streak_$azkarType') ?? 0;

    if (lastDate == today) {
      // Already counted for today
      return;
    }

    if (lastDate != null) {
      DateTime last = DateTime.parse(lastDate);
      DateTime now = DateTime.parse(today);

      int difference = now.difference(last).inDays;

      if (difference == 1) {
        currentStreak++;
      } else {
        // Streak broken - reset to 1
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    await prefs.setInt('streak_$azkarType', currentStreak);
    await prefs.setString(lastDateKey, today);
  }

  /// Returns current streak count.
  static Future<int> getStreak(String azkarType) async {
    final prefs = CacheHelper.prefs;
    final int storedStreak = prefs.getInt('streak_$azkarType') ?? 0;
    final String lastDateKey = '${_lastStreakDateKey}_$azkarType';
    final String? lastDateStr = prefs.getString(lastDateKey);

    if (storedStreak == 0 || lastDateStr == null) {
      return 0;
    }

    final DateTime lastDate = DateTime.parse(lastDateStr);
    // Use the logical cycle date (e.g., past Maghrib = tomorrow's morning cycle)
    final String currentCycleDateStr = await _getCycleDate(azkarType);
    final DateTime currentCycleDate = DateTime.parse(currentCycleDateStr);

    final DateTime lastDateOnly = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );
    final DateTime currentCycleDateOnly = DateTime(
      currentCycleDate.year,
      currentCycleDate.month,
      currentCycleDate.day,
    );

    final int difference = currentCycleDateOnly.difference(lastDateOnly).inDays;

    if (difference > 1) {
      // Streak broken - reset in storage
      await prefs.setInt('streak_$azkarType', 0);
      return 0;
    }

    return storedStreak;
  }

  /// Sets the progress for a specific session (e.g. Wird or Azkar)
  static Future<void> saveProgress(String key, dynamic value) async {
    final prefs = CacheHelper.prefs;
    if (value is int) {
      await prefs.setInt('progress_$key', value);
    } else if (value is String) {
      await prefs.setString('progress_$key', value);
    } else if (value is bool) {
      await prefs.setBool('progress_$key', value);
    }
  }

  /// Gets the progress for a specific session
  static Future<dynamic> getProgress(String key) async {
    final prefs = CacheHelper.prefs;
    return prefs.get('progress_$key');
  }

  /// Clears progress for a specific key
  static Future<void> clearProgress(String key) async {
    final prefs = CacheHelper.prefs;
    await prefs.remove('progress_$key');
  }

  /// Special helper for Wird
  static Future<void> saveWirdProgress(int sessionIndex, int lastPage) async {
    await saveProgress('active_wird_session', sessionIndex);
    await saveProgress('active_wird_page', lastPage);
  }

  static Future<Map<String, int?>> getWirdProgress() async {
    return {
      'sessionIndex': await getProgress('active_wird_session') as int?,
      'page': await getProgress('active_wird_page') as int?,
    };
  }

  static Future<void> clearWirdProgress() async {
    await clearProgress('active_wird_session');
    await clearProgress('active_wird_page');
  }

  // ─── Surah Al-Kahf (Friday) Helpers ─────────────────────────────────────

  /// Returns a unique ID for the current "Kahf Week" based on the date of the
  /// Friday that concludes the period (Thu Maghrib → Fri Maghrib).
  static String getKahfWeekId() {
    final now = DateTime.now();
    // Friday is 5. If today is Sat(6), Sun(7), Mon(1)... it belongs to next Fri.
    // However, our UI only shows this during the Thu-Fri window.
    int daysUntilFriday = (DateTime.friday - now.weekday);
    if (daysUntilFriday < 0) daysUntilFriday += 7;
    final fridayDate = now.add(Duration(days: daysUntilFriday));
    return DateFormat('yyyy-MM-dd').format(fridayDate);
  }

  static Future<int?> getKahfProgress() async {
    final prefs = CacheHelper.prefs;
    final weekId = getKahfWeekId();
    final lastWeek = prefs.getString('kahf_last_week_reset');
    
    if (lastWeek != weekId) {
      // It's a new week, reset progress automatically
      await prefs.setString('kahf_last_week_reset', weekId);
      await prefs.remove('progress_kahf_page');
      return null;
    }
    
    return prefs.getInt('progress_kahf_page');
  }

  static Future<void> saveKahfProgress(int page) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt('progress_kahf_page', page);
    await prefs.setString('kahf_last_week_reset', getKahfWeekId());
  }

  static Future<void> markKahfDone() async {
    final prefs = CacheHelper.prefs;
    await prefs.setBool('kahf_done_${getKahfWeekId()}', true);
  }

  static Future<bool> isKahfDone() async {
    final prefs = CacheHelper.prefs;
    return prefs.getBool('kahf_done_${getKahfWeekId()}') ?? false;
  }

  /// Initializes a daily entry with 0% if it doesn't exist.
  /// Also handles resetting temporary progress keys for the new day.
  static Future<void> initStatsForToday() async {
    final prefs = CacheHelper.prefs;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Handle Reset of Temporary Keys
    final String? lastResetDate = prefs.getString('current_day_date');
    if (lastResetDate != today) {
      // Save current day date first to prevent multiple resets
      await prefs.setString('current_day_date', today);

      // Clear temporary keys used by AccountabilityScreen
      await prefs.remove('temp_prayers');
      await prefs.remove('temp_quran');
      await prefs.remove('temp_azkar');
      await prefs.remove('temp_deeds');

      // Clear any other daily transient progress if needed
      await clearProgress('active_wird_page'); // Example

      debugPrint(
        'DailyTrackerService: New day detected ($today). Temporary data reset.',
      );
    }

    // 2. Initialize Stats Entry for Today
    final String key = 'stats_$today';
    if (!prefs.containsKey(key)) {
      Map<String, dynamic> initialData = {
        'date': today,
        'prayer': 0.0,
        'quran': 0.0,
        'azkar': 0.0,
        'deeds': 0.0,
        'total': 0.0,
      };
      await prefs.setString(key, json.encode(initialData));
    }
  }
}
