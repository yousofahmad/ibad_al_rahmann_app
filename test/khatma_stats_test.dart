import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/features/wird/data/completed_khatma_model.dart';
import 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';
import 'package:ibad_al_rahmann/features/wird/data/khatm_quran_duaa.dart';
import 'package:ibad_al_rahmann/features/wird/data/wird_model.dart';
import 'package:ibad_al_rahmann/features/wird/utils/wird_calculator.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();

    // Setup in-memory / mock box for testing
    final tempDir = '/tmp/hive_test_${DateTime.now().millisecondsSinceEpoch}';
    try {
      Hive.init(tempDir);
    } catch (_) {}
    if (!Hive.isBoxOpen('appDataBox')) {
      await Hive.openBox('appDataBox');
    }
  });

  group('CompletedKhatmaModel Tests', () {
    test('JSON serialization and deserialization works correctly', () {
      final startDate = DateTime(2026, 1, 1);
      final completedDate = DateTime(2026, 1, 30);
      final model = CompletedKhatmaModel(
        id: 'khatma_test_1',
        name: 'ختمة رمضان المبارك',
        startDate: startDate,
        completedDate: completedDate,
        daysPlanned: 30,
        actualDays: 29,
        totalWirds: 30,
        pagesCount: 604,
        notificationType: 'daily',
      );

      final json = model.toJson();
      expect(json['id'], 'khatma_test_1');
      expect(json['name'], 'ختمة رمضان المبارك');
      expect(json['daysPlanned'], 30);
      expect(json['actualDays'], 29);
      expect(json['pagesCount'], 604);

      final reconstructed = CompletedKhatmaModel.fromJson(json);
      expect(reconstructed.id, model.id);
      expect(reconstructed.name, model.name);
      expect(reconstructed.daysPlanned, model.daysPlanned);
      expect(reconstructed.actualDays, model.actualDays);
      expect(reconstructed.pagesCount, model.pagesCount);
      expect(reconstructed.notificationType, model.notificationType);
    });
  });

  group('KhatmQuranDuaa Dataset Tests', () {
    test('Duaa text is not empty and has structured sections', () {
      expect(KhatmQuranDuaa.title, isNotEmpty);
      expect(KhatmQuranDuaa.sections.length, greaterThanOrEqualTo(5));
      expect(
        KhatmQuranDuaa.fullText,
        contains('اللَّهُمَّ ارْحَمْنِي بِالقُرْآنِ'),
      );
    });
  });

  group('KhatmaCubit Statistics & Archiving Tests', () {
    late KhatmaCubit cubit;

    setUp(() async {
      cubit = KhatmaCubit();
      final box = Hive.box('appDataBox');
      await box.clear();
      await CacheHelper.prefs.clear();
    });

    tearDown(() {
      cubit.close();
    });

    test('Initial completed count is 0', () {
      expect(cubit.getCompletedKhatmas(), isEmpty);
      expect(cubit.getManualCompletedCount(), 0);
      expect(cubit.totalCompletedCount, 0);
    });

    test(
      'Setting manual completed count updates totalCompletedCount',
      () async {
        await cubit.setManualCompletedCount(5);
        expect(cubit.getManualCompletedCount(), 5);
        expect(cubit.totalCompletedCount, 5);

        await cubit.setManualCompletedCount(0);
        expect(cubit.getManualCompletedCount(), 0);
        expect(cubit.totalCompletedCount, 0);
      },
    );

    test(
      'Archiving a completed khatma stores it in history and increments total count',
      () async {
        final startDate = DateTime.now().subtract(const Duration(days: 25));
        final khatma = KhatmaModel(
          id: 'test_khatma_arch_1',
          name: 'ختمة التجربة',
          wirds: [
            WirdModel(
              wirdIndex: 0,
              startSurahName: 'الفاتحة',
              startAyah: 1,
              endSurahName: 'البقرة',
              endAyah: 141,
              startPage: 1,
              endPage: 20,
              startSuraNumber: 1,
              endSuraNumber: 2,
              isCompleted: true,
            ),
          ],
          currentWirdIndex: 0,
          notificationType: 'daily',
          startDate: startDate,
          days: 30,
        );

        await cubit.archiveCompletedKhatma(khatma);

        final completed = cubit.getCompletedKhatmas();
        expect(completed.length, 1);
        expect(completed.first.id, 'test_khatma_arch_1');
        expect(completed.first.name, 'ختمة التجربة');
        expect(cubit.totalCompletedCount, 1);

        // Add manual count to verify combination
        await cubit.setManualCompletedCount(3);
        expect(cubit.totalCompletedCount, 4);

        // Delete completed item
        await cubit.deleteCompletedKhatma('test_khatma_arch_1');
        expect(cubit.getCompletedKhatmas(), isEmpty);
        expect(cubit.totalCompletedCount, 3);
      },
    );

    test('startNewKhatma with past startDate and initialCompletedWirds', () async {
      final today = DateTime.parse(IslamicDay.todayKeySync());
      final pastDate = today.subtract(const Duration(days: 5));

      await cubit.startNewKhatma(
        id: 'test_khatma_past_start',
        name: 'ختمة متأخرة',
        totalDays: 30,
        notificationType: 'daily',
        unit: WirdUnit.page,
        startDate: pastDate,
        initialCompletedWirds: 2,
      );

      final k = cubit.getKhatmaById('test_khatma_past_start');
      expect(k, isNotNull);
      expect(k!.startDate.year, pastDate.year);
      expect(k.startDate.month, pastDate.month);
      expect(k.startDate.day, pastDate.day);
      expect(k.currentWirdIndex, 2);
      expect(k.wirds[0].isCompleted, isTrue);
      expect(k.wirds[1].isCompleted, isTrue);
      expect(k.wirds[2].isCompleted, isFalse);

      // 5 days elapsed, 2 completed -> 3 wirds late
      final daysLate = cubit.getDaysLate('test_khatma_past_start');
      expect(daysLate, 3);

      // Now update startDate to 2 days ago
      final newStartDate = today.subtract(const Duration(days: 2));
      await cubit.updateKhatmaStartDate('test_khatma_past_start', newStartDate);

      final updatedK = cubit.getKhatmaById('test_khatma_past_start');
      expect(updatedK!.startDate.day, newStartDate.day);
      // 2 days elapsed, 2 completed -> 0 days late (on track)
      final newDaysLate = cubit.getDaysLate('test_khatma_past_start');
      expect(newDaysLate, 0);
    });
  });
}
