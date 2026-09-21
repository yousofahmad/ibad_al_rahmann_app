import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';
import 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  test('Prayer Focus marks immediately reflect in temp_prayers and stats_date', () async {
    final todayKey = await IslamicDay.todayKey();
    final prefs = CacheHelper.prefs;

    // Simulate Fajr and Dhuhr logged in Prayer Focus
    final focusLog = {
      'الفجر': {'status': 'ontime', 'ts': DateTime.now().millisecondsSinceEpoch},
      'الظهر': {'status': 'late', 'ts': DateTime.now().millisecondsSinceEpoch},
    };
    await prefs.setString('prayer_focus_log_$todayKey', json.encode(focusLog));

    // Run sync
    await AccountabilitySyncService.syncAndSaveTodayStats();

    // Verify temp_prayers is updated
    final tempPrayersRaw = prefs.getString('temp_prayers');
    expect(tempPrayersRaw, isNotNull);
    final Map<String, dynamic> tempPrayers = json.decode(tempPrayersRaw!);
    expect(tempPrayers['الفجر'], isTrue);
    expect(tempPrayers['الظهر'], isTrue);
    expect(tempPrayers['العصر'], isFalse);

    // Verify stats_$todayKey is saved with non-zero prayer score and total score
    final statsRaw = prefs.getString('stats_$todayKey');
    expect(statsRaw, isNotNull);
    final Map<String, dynamic> stats = json.decode(statsRaw!);
    expect(stats['date'], equals(todayKey));
    expect(stats['prayer'], greaterThan(0.0));
    expect(stats['total'], greaterThan(0.0));
  });

  test('Friday (الجمعة) prayer in Prayer Focus maps to Dhuhr (الظهر) in accountability', () async {
    final todayKey = await IslamicDay.todayKey();
    final prefs = CacheHelper.prefs;

    final focusLog = {
      'الجمعة': {'status': 'ontime', 'ts': DateTime.now().millisecondsSinceEpoch},
    };
    await prefs.setString('prayer_focus_log_$todayKey', json.encode(focusLog));

    await AccountabilitySyncService.syncAndSaveTodayStats();

    final tempPrayersRaw = prefs.getString('temp_prayers');
    expect(tempPrayersRaw, isNotNull);
    final Map<String, dynamic> tempPrayers = json.decode(tempPrayersRaw!);
    expect(tempPrayers['الظهر'], isTrue);
  });
}
