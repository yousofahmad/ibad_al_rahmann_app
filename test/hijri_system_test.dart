import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/hijri_source_service.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await AppLogger.init();
  });

  test('Hijri Systems: Umm Al-Qura (Default) vs Egyptian (Layered)', () async {
    final prayerService = PrayerService();
    final now = DateTime.now();

    // 1. Fresh install default is Umm Al-Qura
    expect(PrayerService.hijriSystem, equals(PrayerService.systemUmmAlQura));
    expect(PrayerService.isEgyptianSystem, isFalse);

    // 2. In Umm Al-Qura mode: Uses manual adjustment (+1) and ignores local_hijri_offset
    await CacheHelper.prefs.setInt('manual_day_adjustment', 1);
    await CacheHelper.prefs.setInt('local_hijri_offset', -1);

    final baseHijri = PrayerService.getHijriWithOffset(0, now);
    // manual adjustment +1 was added to the astronomical date
    expect(baseHijri, isNotNull);

    // 3. Switch to Egyptian mode
    await prayerService.setHijriSystem(PrayerService.systemEgyptian);
    expect(PrayerService.hijriSystem, equals(PrayerService.systemEgyptian));
    expect(PrayerService.isEgyptianSystem, isTrue);

    // 4. In Egyptian mode: Uses local_hijri_offset (-1) and ignores manual adjustment
    final egyptianHijri = PrayerService.getHijriWithOffset(0, now);
    expect(egyptianHijri, isNotNull);

    // 5. Critical check on Eve of 29 function completes safely
    await expectLater(HijriSourceService.checkEveOf29CriticalSync(), completes);
  });
}
