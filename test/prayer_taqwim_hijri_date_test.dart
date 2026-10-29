import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrayerService.keyHijriSystem: PrayerService.systemEgyptian,
      'local_hijri_offset': 1,
    });
    await CacheHelper.init();
    await EgyptianHijriCalendar.instance.initialize();
  });

  tearDown(() => EgyptianHijriCalendar.instance.resetForTesting());

  test(
    'result card uses the national ESA row even if another system is selected',
    () async {
      await CacheHelper.prefs.setString(
        PrayerService.keyHijriSystem,
        PrayerService.systemUmmAlQura,
      );

      final resultDate = PrayerService.getEgyptianResultHijriForDate(
        DateTime(2026, 10, 28),
      );

      expect(resultDate?.hDay, 17);
      expect(resultDate?.hMonth, 5);
      expect(resultDate?.hYear, 1448);
    },
  );

  test(
    'result card does not fabricate a Hijri date when the ESA row is absent',
    () {
      final resultDate = PrayerService.getEgyptianResultHijriForDate(
        DateTime(2027, 1, 1),
      );

      expect(resultDate, isNull);
    },
  );

  test('the official Egyptian table remains primary without confirmation', () {
    final octoberEleventh = PrayerService.getDisplayHijriForDate(
      1,
      DateTime(2026, 10, 11),
    );
    final octoberTwelfth = PrayerService.getHijriWithOffset(
      1,
      DateTime(2026, 10, 12),
    );

    expect(octoberEleventh.hDay, 29);
    expect(octoberEleventh.hMonth, 4);
    expect(octoberTwelfth.hDay, 1);
    expect(octoberTwelfth.hMonth, 5);
    expect(
      PrayerService.hijriToGregorianDate(1448, 5, 1),
      DateTime(2026, 10, 12),
    );
  });

  test(
    'user confirmation overrides conflicting rows through day 29, then ESA resumes',
    () {
      final calendar = EgyptianHijriCalendar.instance;
      expect(
        calendar.surveyDates['2026-10-09'],
        const EgyptianHijriDate(hDay: 27, hMonth: 4, hYear: 1448),
      );
      expect(
        calendar.surveyDates['2026-10-10'],
        const EgyptianHijriDate(hDay: 28, hMonth: 4, hYear: 1448),
      );
      calendar.applyUserConfirmation(
        EgyptianHijriUserConfirmation(
          anchorDate: DateTime(2026, 10, 9),
          hijri: const EgyptianHijriDate(hDay: 28, hMonth: 4, hYear: 1448),
          confirmedAt: '2026-10-09T00:00:00Z',
        ),
      );

      // The stored user anchor conflicts with ESA (28 vs 27), as does its
      // continuation through day 29 on October 10 (29 vs 28).
      expect(calendar.lookup(DateTime(2026, 10, 9))?.hDay, 28);
      expect(calendar.lookup(DateTime(2026, 10, 10))?.hDay, 29);
      expect(
        calendar.userConfirmation!.recheckDue(DateTime(2026, 10, 10)),
        isTrue,
      );
      expect(
        calendar.dateSourceLabel(DateTime(2026, 10, 10)),
        'بتأكيد المستخدم',
      );

      final anchorDisplay = PrayerService.getEgyptianResultHijriForDate(
        DateTime(2026, 10, 9),
      );
      final dayTwentyNineDisplay = PrayerService.getEgyptianResultHijriForDate(
        DateTime(2026, 10, 10),
      );
      expect(anchorDisplay, isNotNull);
      expect(dayTwentyNineDisplay, isNotNull);
      expect(anchorDisplay!.hDay, 28);
      expect(dayTwentyNineDisplay!.hDay, 29);
      expect(dayTwentyNineDisplay.hMonth, 4);

      // Notifications share the same confirmation-aware lookup as displays.
      expect(
        PrayerService.getNotificationHijriForDate(DateTime(2026, 10, 10))?.hDay,
        29,
      );

      // Inverse conversion prefers the confirmed day 29 over the conflicting
      // official occurrence on October 11.
      expect(
        PrayerService.hijriToGregorianDate(1448, 4, 29),
        DateTime(2026, 10, 10),
      );

      // Day 30 is not projected from the confirmation. The lookup and inverse
      // conversion return to the published table after the confirmed day 29.
      expect(calendar.userConfirmation!.lookup(DateTime(2026, 10, 11)), isNull);
      expect(
        calendar.dateSourceLabel(DateTime(2026, 10, 11)),
        EgyptianHijriCalendar.sourceName,
      );
      expect(
        PrayerService.getHijriWithOffset(1, DateTime(2026, 10, 11)).hDay,
        29,
      );
      expect(
        PrayerService.hijriToGregorianDate(1448, 5, 1),
        DateTime(2026, 10, 12),
      );
    },
  );

  test(
    'native notification cache marks an active manual confirmation',
    () async {
      final today = DateTime.now();
      final todayKey = EgyptianHijriCalendar.civilKey(today);
      EgyptianHijriCalendar.instance.applyUserConfirmation(
        EgyptianHijriUserConfirmation(
          anchorDate: today,
          hijri: const EgyptianHijriDate(hDay: 28, hMonth: 5, hYear: 1448),
          confirmedAt: today.toUtc().toIso8601String(),
        ),
      );

      await PrayerService.cacheHijriDatesForNative(0);

      expect(
        CacheHelper.prefs.getString('notification_hijri_$todayKey'),
        '28,5,1448',
      );
      expect(
        CacheHelper.prefs.getString('local_hijri_confirmed_source_$todayKey'),
        'user_confirmation',
      );
    },
  );
}
