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
    'daily result uses the official Egyptian date at the month boundary',
    () {
      final calendar = EgyptianHijriCalendar.instance;
      calendar.applyUserConfirmation(
        EgyptianHijriUserConfirmation(
          anchorDate: DateTime(2026, 10, 11),
          hijri: const EgyptianHijriDate(
            hDay: 30,
            hMonth: 4,
            hYear: 1448,
          ),
          confirmedAt: '2026-10-11T00:00:00Z',
        ),
      );
      expect(calendar.lookup(DateTime(2026, 10, 11))?.hDay, 30);

      final octoberEleventh = PrayerService.getDisplayHijriForDate(
        1,
        DateTime(2026, 10, 11),
      );
      final octoberTwelfth = PrayerService.getDisplayHijriForDate(
        1,
        DateTime(2026, 10, 12),
      );

      expect(octoberEleventh.hDay, 29);
      expect(octoberEleventh.hMonth, 4);
      expect(octoberEleventh.hYear, 1448);
      expect(octoberTwelfth.hDay, 1);
      expect(octoberTwelfth.hMonth, 5);
      expect(octoberTwelfth.hYear, 1448);
    },
  );
}
