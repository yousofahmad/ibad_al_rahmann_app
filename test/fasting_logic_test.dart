import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/fasting_logic.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await AppLogger.init();
  });

  test(
    'FastingLogic: Synchronizes with PrayerService and Egyptian offset',
    () async {
      final prayerService = PrayerService();
      await prayerService.setHijriSystem(PrayerService.systemEgyptian);
      await CacheHelper.prefs.setInt('local_hijri_offset', -1);

      final currentHijri = prayerService.getAdjustedHijri();
      final days = FastingLogic.getFastingDaysForMonth(
        currentHijri.hMonth,
        currentHijri.hYear,
      );

      expect(days, isNotEmpty);

      // Every fasting day's hijriDate must match PrayerService.getHijriWithOffset for that Gregorian date
      for (final day in days) {
        final expectedHijri = PrayerService.getHijriWithOffset(
          prayerService.hijriOffset,
          day.date,
        );
        expect(
          day.hijriDate.hDay,
          equals(expectedHijri.hDay),
          reason:
              'Fasting day on ${day.date} should have Hijri day ${expectedHijri.hDay}',
        );
        expect(day.hijriDate.hMonth, equals(expectedHijri.hMonth));
        expect(day.hijriDate.hYear, equals(expectedHijri.hYear));
      }
    },
  );
}
