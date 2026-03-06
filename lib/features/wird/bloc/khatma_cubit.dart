import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan/adhan.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import '../data/khatma_model.dart';
import '../data/wird_model.dart';
import '../utils/wird_calculator.dart';

part 'khatma_state.dart';

class KhatmaCubit extends Cubit<KhatmaState> {
  KhatmaCubit() : super(KhatmaInitial());

  static const String _khatmaKey = 'active_khatma_data';

  // 🔴 تم مسح المصفوفة المكررة من هنا عشان متبوظش الحسابات 🔴

  Future<void> loadKhatma() async {
    emit(KhatmaLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_khatmaKey);

      if (data != null) {
        final Map<String, dynamic> json = jsonDecode(data);
        final khatma = KhatmaModel.fromJson(json);
        emit(KhatmaLoaded(khatma));
      } else {
        emit(KhatmaEmpty());
      }
    } catch (e) {
      emit(KhatmaError("حدث خطأ أثناء تحميل الختمة: $e"));
    }
  }

  /// [quantityType]: 'juz', 'quarter', 'pages'
  /// [quantityValue]: number of juz (1-10), quarters (1-7), or pages (1-5)
  /// [notificationType]: 'none', 'daily', 'prayer'
  Future<void> startNewKhatma({
    required int totalDays,
    required String notificationType,
    required WirdUnit unit,
    int startJuz = 1,
    int? startFromPage,
  }) async {
    emit(KhatmaLoading());
    try {
      List<WirdModel> wirds = [];

      int totalSessions = notificationType == 'prayer'
          ? totalDays * 5
          : totalDays;

      // Use startFromPage if provided, otherwise derive from startJuz
      int effectiveStartPage = startFromPage ?? 1;
      if (startFromPage == null && startJuz >= 1 && startJuz <= 30) {
        effectiveStartPage = WirdCalculator.juzStartPages[startJuz - 1];
      }

      for (int i = 0; i < totalSessions; i++) {
        WirdSession session = WirdCalculator.getSession(
          sessionIndex: i,
          totalSessions: totalSessions,
          unit: unit,
          startFromPage: effectiveStartPage,
        );

        wirds.add(
          WirdModel(
            wirdIndex: i,
            startSurahName: quran.getSurahNameArabic(session.startSuraNumber),
            startAyah: session.startAyah,
            endSurahName: quran.getSurahNameArabic(session.endSuraNumber),
            endAyah: session.endAyah,
            startPage: session.startPage,
            endPage: session.endPage,
            isCompleted: false,
            isPartial: session.isPartial,
            startSuraNumber: session.startSuraNumber,
            endSuraNumber: session.endSuraNumber,
          ),
        );
      }

      final newKhatma = KhatmaModel(
        wirds: wirds,
        currentWirdIndex: 0,
        notificationType: notificationType,
        startDate: DateTime.now(),
        days: totalDays,
        pagesPerWird: unit == WirdUnit.page ? 604 ~/ totalSessions : 0,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_khatmaKey, jsonEncode(newKhatma.toJson()));

      await prefs.setString('wird_reminder_type', notificationType);
      await prefs.setInt('wird_days', newKhatma.days);
      await prefs.setString(
        'wird_start_date',
        DateTime.now().toIso8601String(),
      );
      await NotificationService.cancelAll(includeWird: true);
      await NotificationService.rescheduleWird();
      PrayerService().scheduleNotifications();

      emit(KhatmaLoaded(newKhatma));
    } catch (e) {
      emit(KhatmaError("حدث خطأ أثناء إنشاء الختمة الجديدة: $e"));
    }
  }

  Future<void> markWirdAsCompleted(int index) async {
    if (state is KhatmaLoaded) {
      final currentKhatma = (state as KhatmaLoaded).khatma;

      final updatedWirds = List<WirdModel>.from(currentKhatma.wirds);
      if (index >= 0 && index < updatedWirds.length) {
        updatedWirds[index] = updatedWirds[index].copyWith(isCompleted: true);
      }

      int nextIndex = currentKhatma.currentWirdIndex;
      if (index == nextIndex && nextIndex < updatedWirds.length - 1) {
        nextIndex++;
      }

      final updatedKhatma = currentKhatma.copyWith(
        wirds: updatedWirds,
        currentWirdIndex: nextIndex,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_khatmaKey, jsonEncode(updatedKhatma.toJson()));
      await NotificationService.rescheduleWird();

      emit(KhatmaLoaded(updatedKhatma));
    }
  }

  int getDaysLate() {
    if (state is! KhatmaLoaded) return 0;
    final khatma = (state as KhatmaLoaded).khatma;
    final now = DateTime.now();
    final start = khatma.startDate;
    final daysSinceStart = now.difference(start).inDays;

    int expectedIndex = 0;
    if (khatma.notificationType == 'prayer') {
      final cp =
          PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      int prayerOffset = _getPrayerOffset(cp);
      expectedIndex = daysSinceStart * 5 + prayerOffset;
    } else {
      expectedIndex = daysSinceStart;
    }

    final daysLate = expectedIndex - khatma.currentWirdIndex;
    return daysLate > 0 ? daysLate : 0;
  }

  int _getPrayerOffset(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 0;
      case Prayer.dhuhr:
        return 1;
      case Prayer.asr:
        return 2;
      case Prayer.maghrib:
        return 3;
      case Prayer.isha:
        return 4;
      default:
        return 0;
    }
  }

  WirdModel? getCurrentTargetWird() {
    if (state is! KhatmaLoaded) return null;
    final khatma = (state as KhatmaLoaded).khatma;
    final now = DateTime.now();
    final daysSinceStart = now.difference(khatma.startDate).inDays;

    int targetIndex = 0;
    if (khatma.notificationType == 'prayer') {
      final cp =
          PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      targetIndex = daysSinceStart * 5 + _getPrayerOffset(cp);
    } else {
      targetIndex = daysSinceStart;
    }

    if (targetIndex >= 0 && targetIndex < khatma.wirds.length) {
      return khatma.wirds[targetIndex];
    }
    return null;
  }

  WirdModel? getNextWird() {
    if (state is! KhatmaLoaded) return null;
    final khatma = (state as KhatmaLoaded).khatma;
    final nextIdx = khatma.currentWirdIndex + 1;
    if (nextIdx < khatma.wirds.length) return khatma.wirds[nextIdx];
    return null;
  }

  Future<void> deleteKhatma() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_khatmaKey);
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('wird_last_page_')) {
        await prefs.remove(key);
      }
    }
    emit(KhatmaEmpty());
  }
}
