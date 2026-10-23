import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calendar = EgyptianHijriCalendar.instance;
  final beforeRamadan = DateTime(2026, 1, 9);
  final firstRamadan = DateTime(2026, 1, 10);
  final lastRamadan = DateTime(2026, 2, 8);
  final firstShawwal = DateTime(2026, 2, 9);
  final outside = DateTime(2026, 2, 15);
  EgyptianHijriDate h(int day, int month) =>
      EgyptianHijriDate(hDay: day, hMonth: month, hYear: 1447);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'hijri_system': 'egyptian',
      'last_lat': 30.0444,
      'last_lng': 31.2357,
      'calculation_method': 'egypt',
      'madhab': 'shafi',
      'ramadan_isha_delay': 120,
      'adjust_Fajr': 7,
      'adjust_Sunrise': 3,
      'adjust_Dhuhr': -4,
      'adjust_Asr': 5,
      'adjust_Maghrib': 9,
      'adjust_Isha': 6,
    });
    await CacheHelper.init();
    calendar.resetForTesting();
    // Entirely synthetic, not published Ramadan dates.
    calendar.replaceSnapshot({
      EgyptianHijriCalendar.civilKey(beforeRamadan): h(30, 8),
      EgyptianHijriCalendar.civilKey(firstRamadan): h(1, 9),
      EgyptianHijriCalendar.civilKey(DateTime(2026, 1, 11)): h(2, 9),
      EgyptianHijriCalendar.civilKey(lastRamadan): h(30, 9),
      EgyptianHijriCalendar.civilKey(firstShawwal): h(1, 10),
      EgyptianHijriCalendar.civilKey(DateTime(2026, 2, 10)): h(2, 10),
      EgyptianHijriCalendar.civilKey(outside): h(7, 10),
      EgyptianHijriCalendar.civilKey(DateTime(2026, 2, 16)): h(8, 10),
    });
  });
  tearDown(calendar.resetForTesting);

  test(
    'Shaaban 29 followed by Ramadan 1 starts Ramadan Isha on its eve',
    () async {
      calendar.replaceSnapshot({
        EgyptianHijriCalendar.civilKey(beforeRamadan): h(29, 8),
        EgyptianHijriCalendar.civilKey(firstRamadan): h(1, 9),
        EgyptianHijriCalendar.civilKey(DateTime(2026, 1, 11)): h(2, 9),
      });
      final service = PrayerService();
      expect(PrayerService.isRamadanNightForDate(beforeRamadan), isTrue);
      final times = service.getPrayerTimesForDate(beforeRamadan)!;
      expect(times.isha.difference(times.maghrib).inMinutes, 120);
    },
  );

  test(
    'Ramadan 29 followed by Shawwal 1 stops Ramadan Isha immediately at the Eid night',
    () async {
      calendar.replaceSnapshot({
        EgyptianHijriCalendar.civilKey(lastRamadan): h(29, 9),
        EgyptianHijriCalendar.civilKey(firstShawwal): h(1, 10),
      });
      final service = PrayerService();
      expect(PrayerService.isRamadanNightForDate(lastRamadan), isFalse);
      final times = service.getPrayerTimesForDate(lastRamadan)!;
      await CacheHelper.prefs.setInt('ramadan_isha_delay', 0);
      final baseline = (await PrayerService.getPrayerTimesForDateStatic(
        lastRamadan,
      ))!;
      expect(times.isha, baseline.isha);
    },
  );

  test(
    'missing next-date data permits only certain interior Ramadan nights, never an assumed day30',
    () async {
      calendar.replaceSnapshot({
        EgyptianHijriCalendar.civilKey(firstRamadan): h(28, 9),
      });
      expect(PrayerService.isRamadanNightForDate(firstRamadan), isTrue);
      calendar.replaceSnapshot({
        EgyptianHijriCalendar.civilKey(firstRamadan): h(29, 9),
      });
      expect(PrayerService.isRamadanNightForDate(firstRamadan), isFalse);
      expect(
        PrayerService.getNotificationHijriForDate(DateTime(2026, 1, 11)),
        isNull,
      );
    },
  );

  test('extended screen uses each adjusted prayer time exactly once', () async {
    final service = PrayerService();
    final raw = service.getPrayerTimesForDate(outside)!;
    final prayers = await service.getExtendedPrayers(date: outside);
    for (final entry in {
      'fajr': raw.fajr,
      'sunrise': raw.sunrise,
      'dhuhr': raw.dhuhr,
      'asr': raw.asr,
      'maghrib': raw.maghrib,
      'isha': raw.isha,
    }.entries) {
      expect(
        prayers.singleWhere((p) => p.id == entry.key).time,
        entry.value,
        reason: '${entry.key} must not get the manual offset twice.',
      );
    }
  });

  for (final date in [beforeRamadan, firstRamadan]) {
    test(
      'Ramadan Isha delay applies to the night beginning on civil ${date.toIso8601String()}',
      () async {
        final static = (await PrayerService.getPrayerTimesForDateStatic(date))!;
        expect(static.isha.difference(static.maghrib).inMinutes, 120);
        final service = PrayerService();
        final raw = service.getPrayerTimesForDate(date)!;
        expect(raw.isha.difference(raw.maghrib).inMinutes, 120);
        final prayers = await service.getExtendedPrayers(date: date);
        expect(prayers.singleWhere((p) => p.id == 'isha').time, raw.isha);
        expect(prayers.singleWhere((p) => p.id == 'maghrib').time, raw.maghrib);
      },
    );
  }

  test(
    'last Ramadan evening is Shawwal night and must not retain Ramadan-only Isha delay',
    () async {
      final delayed = (await PrayerService.getPrayerTimesForDateStatic(
        lastRamadan,
      ))!;
      await CacheHelper.prefs.setInt('ramadan_isha_delay', 0);
      final baseline = (await PrayerService.getPrayerTimesForDateStatic(
        lastRamadan,
      ))!;
      expect(delayed.isha, baseline.isha);
      final raw = PrayerService().getPrayerTimesForDate(lastRamadan)!;
      expect(raw.isha, baseline.isha);
      final prayers = await PrayerService().getExtendedPrayers(
        date: lastRamadan,
      );
      expect(prayers.singleWhere((p) => p.id == 'isha').time, baseline.isha);
    },
  );
}
