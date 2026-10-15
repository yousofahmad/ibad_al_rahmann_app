import 'package:adhan/adhan.dart';

/// Determines whether an accountability prayer should count as due.
/// Non-obligatory custom items retain the existing behavior and are counted.
class AccountabilityPrayerStatus {
  const AccountabilityPrayerStatus._();

  static bool isPast(
    String prayerName,
    PrayerTimes? times, {
    DateTime? now,
  }) {
    if (times == null) return true;

    final currentTime = now ?? DateTime.now();
    final DateTime? prayerTime = switch (prayerName) {
      'الفجر' => times.fajr,
      'الظهر' || 'الجمعة' => times.dhuhr,
      'العصر' => times.asr,
      'المغرب' => times.maghrib,
      'العشاء' => times.isha,
      _ => null,
    };

    // Custom/non-obligatory accountability items are not filtered by adhan.
    return prayerTime == null || currentTime.isAfter(prayerTime);
  }
}
