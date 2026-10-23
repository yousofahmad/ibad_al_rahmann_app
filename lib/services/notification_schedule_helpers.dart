/// Pure scheduling rules shared by the notification service and its tests.
class NotificationScheduleHelpers {
  const NotificationScheduleHelpers._();

  /// Calendar days are not always 24 elapsed hours across DST changes.
  /// Retain the wall-clock time and UTC/local representation of the input.
  static DateTime addCivilDays(DateTime date, int days) => date.isUtc
      ? DateTime.utc(
          date.year,
          date.month,
          date.day + days,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        )
      : DateTime(
          date.year,
          date.month,
          date.day + days,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );

  /// The night of Eid al-Fitr starts only when the following civil day is
  /// actually 1 Shawwal.  This avoids announcing Eid after a 29th Ramadan
  /// that is followed by the 30th.
  static bool isEidFitrNight({
    required int hijriMonth,
    required int hijriDay,
    required int nextHijriMonth,
    required int nextHijriDay,
  }) {
    return hijriMonth == 9 &&
        (hijriDay == 29 || hijriDay == 30) &&
        nextHijriMonth == 10 &&
        nextHijriDay == 1;
  }

  static bool isEidFitrDay({required int hijriMonth, required int hijriDay}) {
    return hijriMonth == 10 && hijriDay == 1;
  }

  static bool isFastingDayAllowed({required int month, required int day}) {
    if (month < 1 || month > 12 || day < 1 || day > 30) return false;
    return !(month == 10 && day == 1) &&
        !(month == 12 && day >= 10 && day <= 13);
  }

  static bool isVoluntaryOrQadaaFastAllowed({
    required int month,
    required int day,
  }) => month != 9 && isFastingDayAllowed(month: month, day: day);

  static int intervalMinutesFromPreference(int value, {int fallback = 60}) {
    if (value <= 0) return fallback;
    // Despite the legacy preference key, alarms_screen.dart stores minutes.
    return value.clamp(2, 240);
  }

  /// Legacy name retained for callers migrated independently.
  static int intervalMinutesFromHoursPreference(
    int value, {
    int fallback = 60,
  }) => intervalMinutesFromPreference(value, fallback: fallback);

  static int intervalMinutes(int value, {int fallback = 15}) {
    if (value <= 0) return fallback;
    return value.clamp(2, 240);
  }

  static int clampHour(int value, {int fallback = 0}) =>
      value >= 0 && value <= 23 ? value : fallback;

  static int clampMinute(int value, {int fallback = 0}) =>
      value >= 0 && value <= 59 ? value : fallback;
}
