import 'package:intl/intl.dart';
import '../../services/prayer_service.dart';

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
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String todayKeySync() {
    final now = DateTime.now();
    final times = PrayerService().getPrayerTimesForDate(now);
    final maghrib = times?.maghrib ?? DateTime(now.year, now.month, now.day, 18, 0);
    final date = now.isAfter(maghrib)
        ? now.add(const Duration(days: 1))
        : now;
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
