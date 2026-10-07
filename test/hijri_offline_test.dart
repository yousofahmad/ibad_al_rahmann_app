import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/hijri_source_service.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:hijri/hijri_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Clear all preferences to simulate fresh clean install
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await AppLogger.init();
  });

  test(
    'Offline Fresh Install Hijri calculation works instantly without internet or cached offset',
    () async {
      // 1. Verify preferences are completely empty (Fresh install)
      expect(CacheHelper.prefs.getInt('local_hijri_offset'), isNull);
      expect(CacheHelper.prefs.getString('shared_hijri_date'), isNull);
      expect(CacheHelper.prefs.getString('local_hijri_confirmed_date'), isNull);

      // 2. Call getHijriWithOffset without internet or cached data
      final now = DateTime.now();
      final hijri = PrayerService.getHijriWithOffset(0, now);

      // 3. Verify valid Hijri date output
      expect(hijri, isNotNull);
      expect(hijri.hYear, greaterThanOrEqualTo(1445));
      expect(hijri.hMonth, inInclusiveRange(1, 12));
      expect(hijri.hDay, inInclusiveRange(1, 30));
      expect(hijri.longMonthName, isNotEmpty);

      // 4. Verify formatted string is non-empty and valid
      HijriCalendar.setLocal('ar');
      final formatted =
          '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} هـ';
      expect(formatted, isNotEmpty);
      expect(formatted.contains('null'), isFalse);

      // 5. Verify syncOffsetIfNeeded handles network failure (Airplane mode) gracefully
      // and does NOT throw or crash
      await expectLater(HijriSourceService.syncOffsetIfNeeded(), completes);
    },
  );
}
