import 'islamic_day.dart';

/// Date keys for the active prayer cycle, which changes at Maghrib.
class PrayerDayHelper {
  const PrayerDayHelper._();

  /// Returns the date key used by all records in the currently active cycle.
  static String getActivePrayerCycleDate() => IslamicDay.todayKeySync();

  /// Prayer records are grouped by the active cycle date, not their save time.
  static String getPrayerDateKey(String prayerName) =>
      getActivePrayerCycleDate();
}
