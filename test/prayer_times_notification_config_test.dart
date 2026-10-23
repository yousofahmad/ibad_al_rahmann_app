import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ramadanDay = DateTime(2026, 10, 23);
  final outsideDay = DateTime(2026, 10, 25);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'latitude': 30.0444,
      'longitude': 31.2357,
      'calculation_method': 'egypt',
      'madhab': 'shafi',
      'hijri_system': PrayerService.systemEgyptian,
      'ramadan_isha_delay': 0,
    });
    await CacheHelper.init();
    EgyptianHijriCalendar.instance.replaceSnapshot({
      EgyptianHijriCalendar.civilKey(ramadanDay): const EgyptianHijriDate(
        hDay: 29,
        hMonth: 9,
        hYear: 1448,
      ),
      EgyptianHijriCalendar.civilKey(DateTime(2026, 10, 24)):
          const EgyptianHijriDate(hDay: 30, hMonth: 9, hYear: 1448),
      EgyptianHijriCalendar.civilKey(outsideDay): const EgyptianHijriDate(
        hDay: 1,
        hMonth: 10,
        hYear: 1448,
      ),
      EgyptianHijriCalendar.civilKey(DateTime(2026, 10, 26)):
          const EgyptianHijriDate(hDay: 2, hMonth: 10, hYear: 1448),
    });
  });

  tearDown(() => EgyptianHijriCalendar.instance.resetForTesting());

  test(
    'static schedule respects restored latitude/longitude without last_lat keys',
    () async {
      await CacheHelper.prefs.setDouble('latitude', 21.4225);
      await CacheHelper.prefs.setDouble('longitude', 39.8262);
      final actual = (await PrayerService.getPrayerTimesForDateStatic(
        outsideDay,
      ))!;
      final params = CalculationMethod.egyptian.getParameters()
        ..madhab = Madhab.shafi;
      final expected = PrayerTimes(
        Coordinates(21.4225, 39.8262),
        DateComponents(outsideDay.year, outsideDay.month, outsideDay.day),
        params,
      );
      expect(actual.fajr, expected.fajr);
      expect(actual.dhuhr, expected.dhuhr);
    },
  );

  test(
    'legacy Umm al-Qura method aliases all select the same calculation',
    () async {
      for (final alias in [
        'makkah',
        'umm_al_qura',
        'ummal_qura',
        'ummalqura',
      ]) {
        await CacheHelper.prefs.setString('calculation_method', alias);
        final actual = (await PrayerService.getPrayerTimesForDateStatic(
          outsideDay,
        ))!;
        final params = CalculationMethod.umm_al_qura.getParameters()
          ..madhab = Madhab.shafi;
        final expected = PrayerTimes(
          Coordinates(30.0444, 31.2357),
          DateComponents(outsideDay.year, outsideDay.month, outsideDay.day),
          params,
        );
        expect(actual.fajr, expected.fajr, reason: alias);
        expect(actual.isha, expected.isha, reason: alias);
      }
    },
  );

  test(
    'official notification lookup does not fabricate future Egyptian dates',
    () {
      expect(PrayerService.getNotificationHijriForDate(ramadanDay)?.hDay, 29);
      expect(
        PrayerService.getNotificationHijriForDate(DateTime(2099, 1, 1)),
        isNull,
      );
    },
  );

  test(
    'static prayer config applies method, madhab and manual adjustments',
    () async {
      final baseline = await PrayerService.getPrayerTimesForDateStatic(
        outsideDay,
      );
      expect(baseline, isNotNull);

      await CacheHelper.prefs.setString('calculation_method', 'umm_al_qura');
      await CacheHelper.prefs.setString('madhab', 'hanafi');
      final configured = await PrayerService.getPrayerTimesForDateStatic(
        outsideDay,
      );
      expect(configured, isNotNull);
      expect(configured!.asr, isNot(baseline!.asr));
      await CacheHelper.prefs.setInt('adjust_Fajr', 7);
      final changed = await PrayerService.getPrayerTimesForDateStatic(
        outsideDay,
      );
      expect(changed, isNotNull);
      expect(changed!.fajr.difference(configured.fajr).inMinutes, 7);
      expect(changed.fajr, isNot(baseline.fajr));
    },
  );

  test('static prayer config honors active city and its offsets', () async {
    await CacheHelper.prefs.setString(
      'saved_cities',
      jsonEncode([
        {
          'id': 'test-city',
          'name': 'Synthetic City',
          'latitude': 31.2,
          'longitude': 29.9,
          'calculationMethod': 'makkah',
          'madhab': 'hanafi',
          'offsets': {
            'Fajr': 11,
            'Sunrise': 0,
            'Dhuhr': 0,
            'Asr': 0,
            'Maghrib': 0,
            'Isha': 0,
          },
        },
      ]),
    );
    await CacheHelper.prefs.setString('active_city_id', 'test-city');
    final times = await PrayerService.getPrayerTimesForDateStatic(outsideDay);
    expect(times, isNotNull);
    final expectedParams = CalculationMethod.umm_al_qura.getParameters()
      ..madhab = Madhab.hanafi;
    expectedParams.adjustments.fajr = 11;
    final expected = PrayerTimes(
      Coordinates(31.2, 29.9),
      DateComponents(outsideDay.year, outsideDay.month, outsideDay.day),
      expectedParams,
    );
    expect(times!.fajr, expected.fajr);
    expect(times.asr, expected.asr);
    expect(times.isha, expected.isha);
  });

  test(
    'Ramadan delay 90/120 applies to the confirmed Ramadan night, not Shawwal',
    () async {
      for (final delay in [90, 120]) {
        await CacheHelper.prefs.setInt('ramadan_isha_delay', delay);
        final ramadan = await PrayerService.getPrayerTimesForDateStatic(
          ramadanDay,
        );
        expect(ramadan, isNotNull);
        expect(ramadan!.isha.difference(ramadan.maghrib).inMinutes, delay);

        final outside = await PrayerService.getPrayerTimesForDateStatic(
          outsideDay,
        );
        expect(outside, isNotNull);
        expect(
          outside!.isha.difference(outside.maghrib).inMinutes,
          isNot(delay),
        );
      }
    },
  );
}
