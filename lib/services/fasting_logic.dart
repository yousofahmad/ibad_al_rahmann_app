import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/models/fasting_day.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class FastingLogic {
  static List<FastingDay> getFastingDaysForMonth(int hMonth, int hYear) {
    List<FastingDay> fastingDays = [];
    final offset = PrayerService().hijriOffset;

    // ── Robust Calculation Strategy ──────────────────────────────────────────
    // Instead of setting Hijri properties (which causes LateInitializationError),
    // we start from a safe Gregorian date and loop forward for ~35 days.
    // ─────────────────────────────────────────────────────────────────────────

    // Estimate starting Gregorian date for Hijri month 1.
    // Hijri 1445-01-01 is roughly 2023-07-19.
    // We'll create a HijriCalendar for the target month/day 1 and convert it
    // to Gregorian as our "center point", then search around it.

    HijriCalendar targetH = HijriCalendar();
    targetH.hYear = hYear;
    targetH.hMonth = hMonth;
    targetH.hDay = 1;

    DateTime baseGreg = targetH.hijriToGregorian(hYear, hMonth, 1);
    // Start searching 5 days before just in case of offsets/month boundaries
    DateTime currentGreg = baseGreg.subtract(const Duration(days: 5));

    // Loop for 40 days to cover any Hijri month (max 30 days) plus buffer
    for (int i = 0; i < 40; i++) {
      DateTime date = currentGreg.add(Duration(days: i));
      // Convert Gregorian + Offset back to Hijri to get the "Actual" Hijri date shown in app
      DateTime shiftedDate = date.add(Duration(days: offset));
      HijriCalendar hDate = HijriCalendar.fromDate(shiftedDate);

      // Only process days belonging to the target Hijri month
      if (hDate.hMonth == hMonth && hDate.hYear == hYear) {
        // --- Forbidden Fasting Days Filter ---
        // 1. Eid al-Fitr (1 Shawwal)
        if (hDate.hMonth == 10 && hDate.hDay == 1) continue;

        // 2. Eid al-Adha and Days of Tashreeq (10, 11, 12, 13 Dhu al-Hijjah)
        if (hDate.hMonth == 12 && (hDate.hDay >= 10 && hDate.hDay <= 13)) {
          continue;
        }

        // 1. Weekly: Monday and Thursday
        if (date.weekday == DateTime.monday) {
          fastingDays.add(
            FastingDay(
              title: 'صيام الاثنين',
              date: date,
              hijriDate: hDate,
              type: FastingType.monday,
            ),
          );
        } else if (date.weekday == DateTime.thursday) {
          fastingDays.add(
            FastingDay(
              title: 'صيام الخميس',
              date: date,
              hijriDate: hDate,
              type: FastingType.thursday,
            ),
          );
        }

        // 2. Monthly: White Days (13, 14, 15)
        if (hDate.hDay == 13 || hDate.hDay == 14 || hDate.hDay == 15) {
          fastingDays.add(
            FastingDay(
              title: 'الأيام البيض (${hDate.hDay})',
              date: date,
              hijriDate: hDate,
              type: FastingType.whiteDay,
            ),
          );
        }

        // 3. Special Days
        if (hMonth == 1) {
          // Muharram
          if (hDate.hDay == 9) {
            fastingDays.add(
              FastingDay(
                title: 'صيام تاسوعاء',
                date: date,
                hijriDate: hDate,
                type: FastingType.tasua,
              ),
            );
          } else if (hDate.hDay == 10) {
            fastingDays.add(
              FastingDay(
                title: 'صيام عاشوراء',
                date: date,
                hijriDate: hDate,
                type: FastingType.ashura,
              ),
            );
          }
        } else if (hMonth == 12) {
          // Dhu al-Hijjah
          if (hDate.hDay >= 1 && hDate.hDay <= 8) {
            fastingDays.add(
              FastingDay(
                title: 'عشر ذي الحجة (${hDate.hDay})',
                date: date,
                hijriDate: hDate,
                type: FastingType.dhuAlHijjah,
              ),
            );
          } else if (hDate.hDay == 9) {
            fastingDays.add(
              FastingDay(
                title: 'صيام يوم عرفة (9)',
                date: date,
                hijriDate: hDate,
                type: FastingType.arafah,
              ),
            );
          }
        }
      }
    }

    return _mergeFastingDays(fastingDays);
  }

  static List<FastingDay> _mergeFastingDays(List<FastingDay> days) {
    Map<DateTime, FastingDay> merged = {};
    for (var d in days) {
      // Normalize date to remove time
      DateTime dateOnly = DateTime(d.date.year, d.date.month, d.date.day);
      if (merged.containsKey(dateOnly)) {
        var existing = merged[dateOnly]!;
        merged[dateOnly] = FastingDay(
          title: '${existing.title} و ${d.title}',
          date: existing.date,
          hijriDate: existing.hijriDate,
          type: existing.type, // Keep first type or maybe other
          description: existing.description,
        );
      } else {
        merged[dateOnly] = d;
      }
    }
    return merged.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}
