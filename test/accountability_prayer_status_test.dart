import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/accountability/accountability_prayer_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PrayerTimes times;

  setUp(() {
    final today = DateTime.now();
    times = PrayerTimes(
      Coordinates(30.0444, 31.2357),
      DateComponents(today.year, today.month, today.day),
      CalculationMethod.egyptian.getParameters(),
    );
  });

  test('future obligatory prayers are excluded and past prayers are counted', () {
    final prayerTimes = <String, DateTime>{
      'الفجر': times.fajr,
      'الظهر': times.dhuhr,
      'العصر': times.asr,
      'المغرب': times.maghrib,
      'العشاء': times.isha,
    };

    for (final entry in prayerTimes.entries) {
      expect(
        AccountabilityPrayerStatus.isPast(
          entry.key,
          times,
          now: entry.value.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
        reason: '${entry.key} should not count before its time',
      );
      expect(
        AccountabilityPrayerStatus.isPast(
          entry.key,
          times,
          now: entry.value.add(const Duration(seconds: 1)),
        ),
        isTrue,
        reason: '${entry.key} should count after its time',
      );
    }
  });

  test('Friday maps to Dhuhr and custom items keep the existing behavior', () {
    expect(
      AccountabilityPrayerStatus.isPast(
        'الجمعة',
        times,
        now: times.dhuhr.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      AccountabilityPrayerStatus.isPast(
        'الجمعة',
        times,
        now: times.dhuhr.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
    expect(
      AccountabilityPrayerStatus.isPast('الضحى', times, now: DateTime.now()),
      isTrue,
    );
  });
}
