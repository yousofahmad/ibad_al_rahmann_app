import 'package:adhan/adhan.dart';

/// Determines whether an accountability prayer should count as due.
/// Non-obligatory custom items retain the existing behavior and are counted.
class AccountabilityPrayerStatus {
  const AccountabilityPrayerStatus._();

  /// Treats the focus log as the source of truth for obligatory prayers.
  /// Missing entries are false, so stale checked values cannot survive a sync.
  static void applyFocusLog(
    Map<String, bool> prayerStatuses,
    Map<String, dynamic> focusLog,
  ) {
    const obligatoryPrayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    for (final prayer in obligatoryPrayers) {
      if (!prayerStatuses.containsKey(prayer)) continue;
      var entry = focusLog[prayer];
      if (prayer == 'الظهر' && (entry == null || entry == false)) {
        entry = focusLog['الجمعة'];
      }
      prayerStatuses[prayer] = _isLoggedAsDone(entry);
    }
  }

  static bool _isLoggedAsDone(Object? entry) {
    if (entry is Map) {
      final status = entry['status'];
      return status != null && status != 'missed';
    }
    if (entry is bool) return entry;
    if (entry is String) return entry.isNotEmpty && entry != 'missed';
    return false;
  }

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
