import 'package:ibad_al_rahmann/features/prayer_times/data/models/prayer_times_model.dart';

// String reformatTime(String time) {
//   List timeSections = time.split(':');
//   int hours = int.parse(timeSections[0]);
//   if (hours > 12) {
//     hours -= 12;
//     return '$hours:${timeSections[1]} م';
//   } else if (hours == 12) {
//     return '$hours:${timeSections[1]} م';
//   }
//   return '$time ص';
// }

// String prayerToString(PrayerTimes prayerTime) {
//   switch (prayerTime) {
//     case PrayerTimes.fajr:
//       return 'الفجر';
//     case PrayerTimes.shrouk:
//       return 'الشروق';
//     case PrayerTimes.duhur:
//       return 'الظهر';
//     case PrayerTimes.asr:
//       return 'العصر';
//     case PrayerTimes.maghrib:
//       return 'المغرب';
//     case PrayerTimes.isha:
//       return 'العشاء';
//   }
// }

/// Converts a time string like "19:11" to a DateTime object
/// The returned DateTime will have today's date with the specified time
/// Optionally adds increment minutes to the time
DateTime convertTimeStringToDateTime(String timeString,
    {int? incrementMinutes}) {
  try {
    // Split the time string by colon
    List<String> timeParts = timeString.split(':');

    if (timeParts.length != 2) {
      throw const FormatException(
          'Invalid time format. Expected format: "HH:mm"');
    }

    // Parse hour and minute
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Validate hour and minute ranges
    if (hour < 0 || hour > 23) {
      throw const FormatException('Hour must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw const FormatException('Minute must be between 0 and 59');
    }

    // Create DateTime with today's date and the specified time
    final now = DateTime.now();
    final finalDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (incrementMinutes != null) {
      return finalDate.add(Duration(minutes: incrementMinutes));
    } else {
      return finalDate;
    }
  } catch (e) {
    throw FormatException('Failed to parse time string "$timeString": $e');
  }
}

PrayerTimeModel? getCurrentPrayerTime(List<PrayerTimeModel> prayers) {
  // This function returns the current active prayer time.
  // A prayer is considered "current" if:
  // 1. The prayer time has passed (date <= now)
  // 2. The iqama time hasn't arrived yet (iqamaDate > now)
  // If no prayer is currently active, returns the next upcoming prayer.
  if (prayers.isEmpty) return null;

  final now = DateTime.now();

  // First, try to find a prayer that is currently active
  for (final prayer in prayers) {
    if (prayer.date.isBefore(now) || prayer.date.isAtSameMomentAs(now)) {
      // Prayer time has passed, check if iqama time hasn't arrived yet
      if (prayer.iqamaDate.isAfter(now)) {
        return prayer; // This prayer is currently active
      }
    }
  }

  // If no prayer is currently active, find the next upcoming prayer
  for (final prayer in prayers) {
    if (prayer.date.isAfter(now)) {
      return prayer; // This is the next prayer
    }
  }

  // If all prayers have passed (including iqama times), return the last one
  return prayers.last;
}
