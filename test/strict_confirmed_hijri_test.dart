import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await AppLogger.init();
  });

  test('Strict Confirmed Mode Behavior (Default Off vs Turned On)', () async {
    final prayerService = PrayerService();
    final todayStr = DateTime.now().toString().substring(0, 10);

    // 1. Default (Switch Off): Normal offline display
    expect(PrayerService.isStrictConfirmedMode, isFalse);
    expect(PrayerService.isHijriDateReadyForDisplay, isTrue);
    final defaultString = prayerService.getAdjustedHijriString();
    expect(defaultString.contains('محتاج اتصال إنترنت'), isFalse);
    expect(defaultString.contains('هـ'), isTrue);

    // 2. Switch ON without today confirmation -> Displays warning message
    await CacheHelper.prefs.setBool('strict_confirmed_hijri_mode', true);
    expect(PrayerService.isStrictConfirmedMode, isTrue);
    expect(PrayerService.isHijriDateReadyForDisplay, isFalse);
    expect(
      prayerService.getAdjustedHijriString(),
      equals(PrayerService.unconfirmedHijriMessage),
    );

    // 3. Switch ON WITH today confirmation -> Displays confirmed date
    await CacheHelper.prefs.setString('local_hijri_confirmed_date', todayStr);
    expect(PrayerService.isHijriDateReadyForDisplay, isTrue);
    final confirmedString = prayerService.getAdjustedHijriString();
    expect(confirmedString.contains('محتاج اتصال إنترنت'), isFalse);
    expect(confirmedString.contains('هـ'), isTrue);
  });
}
