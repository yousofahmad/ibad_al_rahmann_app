import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class DailyTrackerService {
  static const String _lastStreakDateKey = 'last_streak_date';
  static const String _dailyPrefix = 'daily_';

  /// Marks a specific Azkar category as done for today.
  /// [category] examples: 'morning_azkar', 'evening_azkar', 'prayer_azkar'.
  static Future<void> markAsDone(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String key = '$_dailyPrefix${today}_$category';

    if (!prefs.containsKey(key)) {
      await prefs.setBool(key, true);
      // Check if this contributes to a streak (only Morning/Evening usually count for "Daily Streak")
      if (category == 'morning_azkar' || category == 'evening_azkar') {
        await _updateStreak(prefs, today, category);
      }
    }
  }

  /// Checks if a category is done today.
  static Future<bool> isDone(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return prefs.getBool('$_dailyPrefix${today}_$category') ?? false;
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
    final prefs = await SharedPreferences.getInstance();
    final int storedStreak = prefs.getInt('streak_$azkarType') ?? 0;
    final String lastDateKey = '${_lastStreakDateKey}_$azkarType';
    final String? lastDateStr = prefs.getString(lastDateKey);

    if (storedStreak == 0 || lastDateStr == null) {
      return 0;
    }

    final DateTime lastDate = DateTime.parse(lastDateStr);
    final DateTime today = DateTime.now();

    final DateTime lastDateOnly = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);

    final int difference = todayOnly.difference(lastDateOnly).inDays;

    if (difference > 1) {
      // Streak broken - reset in storage
      await prefs.setInt('streak_$azkarType', 0);
      return 0;
    }

    return storedStreak;
  }

  /// Initializes a daily entry with 0% if it doesn't exist.
  static Future<void> initStatsForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
