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
  static const String _activeIdKey = 'active_khatma_id';

  KhatmaModel? getActiveKhatma() {
    if (state is KhatmaLoaded) {
      final khatmas = (state as KhatmaLoaded).khatmas;
      if (khatmas.isNotEmpty) {
        return khatmas.first;
      }
    }
    return null;
  }

  KhatmaModel? getKhatmaById(String id) {
    if (state is KhatmaLoaded) {
      final khatmas = (state as KhatmaLoaded).khatmas;
      try {
        return khatmas.firstWhere((k) => k.id == id);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> loadKhatma({String? specificId}) async {
    emit(KhatmaLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      List<KhatmaModel> loadedKhatmas = [];

      final keys = prefs.getKeys();
      int count = 0;
      for (String key in keys) {
        if (key.startsWith('khatma_')) {
          final data = prefs.getString(key);
          if (data != null) {
            loadedKhatmas.add(KhatmaModel.fromJson(jsonDecode(data)));
          }
        }
        
        // Yield every 10 keys to keep UI thread responsive
        count++;
        if (count % 10 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // Legacy fallback
      if (loadedKhatmas.isEmpty) {
        final oldData = prefs.getString(_khatmaKey);
        if (oldData != null) {
          final k = KhatmaModel.fromJson(jsonDecode(oldData));
          loadedKhatmas.add(k);
          prefs.setString('khatma_${k.id}', oldData);
        }
      }

      if (loadedKhatmas.isNotEmpty) {
        // Sort so the newest or main logic applies
        emit(KhatmaLoaded(loadedKhatmas));
      } else {
        emit(KhatmaEmpty());
      }
    } catch (e) {
      emit(KhatmaError("حدث خطأ أثناء تحميل الختمة: $e"));
    }
  }

  Future<void> startNewKhatma({
    required String id,
    required String name,
    required int totalDays,
    required String notificationType,
    required WirdUnit unit,
    bool enableNotifications = true,
    int startJuz = 1,
    int? startFromPage,
    String? dailyTime,
    int notificationOffsetMinutes = 30,
  }) async {
    emit(KhatmaLoading());
    try {
      List<WirdModel> wirds = [];

      // Resolve the actual start page first — needed for quarter count.
      int effectiveStartPage = startFromPage ?? 1;
      if (startFromPage == null && startJuz >= 1 && startJuz <= 30) {
        effectiveStartPage = WirdCalculator.juzStartPages[startJuz - 1];
      }

      int totalSessions = notificationType == 'prayer'
          ? totalDays * 5
          : totalDays;

      if (unit == WirdUnit.juz) {
        totalSessions = 30; // always 30 juz
      } else if (unit == WirdUnit.quarter) {
        // Each Wird = exactly ONE Rub' — totalSessions = number of remaining quarters.
        totalSessions = WirdCalculator.getQuarterCount(effectiveStartPage);
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
        id: id,
        name: name,
        wirds: wirds,
        currentWirdIndex: 0,
        notificationType: notificationType,
        enableNotifications: enableNotifications,
        startDate: DateTime.now(),
        days: totalDays,
        pagesPerWird: unit == WirdUnit.page
            ? (604 - effectiveStartPage + 1) ~/ totalSessions
            : (30 * 20) ~/ totalSessions,
        dailyTime: dailyTime,
        notificationOffsetMinutes: notificationOffsetMinutes,
        // Record which prayer we started on so getDaysLate can offset correctly.
        startPrayerOffset: notificationType == 'prayer'
            ? _getPrayerOffset(
                PrayerService().getPrayerTimes()?.currentPrayer() ??
                    Prayer.none,
              )
            : 0,
      );

      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(newKhatma.toJson());
      await prefs.setString('khatma_$id', jsonData);
      await prefs.setString(_activeIdKey, id);
      await prefs.setString(_khatmaKey, jsonData); // Legacy support

      await prefs.setString('${id}_wird_reminder_type', notificationType);
      await prefs.setInt('${id}_wird_days', newKhatma.days);

      List<KhatmaModel> currentList = [];

      // We repull to be absolutely safe, or grab from state instead of clearing
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('khatma_')) {
          final data = prefs.getString(key);
          if (data != null) {
            currentList.add(KhatmaModel.fromJson(jsonDecode(data)));
          }
        }
      }

      await NotificationService.rescheduleWird();

      emit(KhatmaLoaded(currentList));
    } catch (e) {
      emit(KhatmaError("حدث خطأ أثناء إنشاء الختمة الجديدة: $e"));
    }
  }

  Future<void> markWirdAsCompleted(String khatmaId, int index) async {
    if (state is KhatmaLoaded) {
      final khatmas = List<KhatmaModel>.from((state as KhatmaLoaded).khatmas);
      final kIndex = khatmas.indexWhere((k) => k.id == khatmaId);
      if (kIndex == -1) return;

      final currentKhatma = khatmas[kIndex];
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

      khatmas[kIndex] = updatedKhatma;

      // Auto-delete if ALL wirds are now completed
      final bool isAllCompleted = updatedWirds.every((w) => w.isCompleted);
      if (isAllCompleted) {
        await deleteKhatma(khatmaId);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(updatedKhatma.toJson());
      await prefs.setString('khatma_${updatedKhatma.id}', jsonData);

      // Cancel only THIS khatma's notifications, then reschedule all
      await NotificationService.cancelKhatmaNotifications(khatmaId);
      await NotificationService.rescheduleAllKhatmaNotifications();

      emit(KhatmaLoaded(khatmas));
    }
  }

  /// Returns how many sessions the user is behind schedule.
  /// The 'missed' count NEVER resets at midnight — it persists until the user
  /// reads and marks each wird as completed.
  int getDaysLate(String khatmaId) {
    if (state is! KhatmaLoaded) return 0;
    final k = getKhatmaById(khatmaId);
    if (k == null) return 0;

    final khatma = k;
    final now = DateTime.now();
    // Use true calendar day difference to avoid 24h shifting issues.
    final startDay = DateTime(
      khatma.startDate.year,
      khatma.startDate.month,
      khatma.startDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceStart = today.difference(startDay).inDays;

    int passedPeriods;
    if (khatma.notificationType == 'prayer') {
      final cp =
          PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      int prayerOffset = _getPrayerOffset(cp);
      passedPeriods =
          (daysSinceStart * 5 + prayerOffset - khatma.startPrayerOffset);
    } else {
      passedPeriods = daysSinceStart;
    }

    if (passedPeriods < 0) passedPeriods = 0;

    int completed = khatma.currentWirdIndex;

    if (completed < passedPeriods) {
      // Late! User missed previous periods.
      return passedPeriods - completed;
    } else if (completed > passedPeriods + 1) {
      // Ahead! User read more than the current period.
      return -(completed - (passedPeriods + 1));
    } else {
      // On track (completed == passedPeriods OR completed == passedPeriods + 1)
      return 0;
    }
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

  /// Always returns the FIRST UNREAD wird from currentWirdIndex onwards.
  /// This is the "currently due" wird that the user must read —
  /// it does NOT skip ahead on day change.
  WirdModel? getCurrentTargetWird(String khatmaId) {
    if (state is! KhatmaLoaded) return null;
    final k = getKhatmaById(khatmaId);
    if (k == null) return null;

    final khatma = k;
    // Find the first unread wird starting from currentWirdIndex
    for (int i = khatma.currentWirdIndex; i < khatma.wirds.length; i++) {
      if (!khatma.wirds[i].isCompleted) {
        return khatma.wirds[i];
      }
    }
    return null; // all done
  }

  /// Returns the wird AFTER the current due wird (for preview purposes).
  WirdModel? getNextWird(String khatmaId) {
    if (state is! KhatmaLoaded) return null;
    final k = getKhatmaById(khatmaId);
    if (k == null) return null;

    final khatma = k;
    // Find current due, then return the one after it
    for (int i = khatma.currentWirdIndex; i < khatma.wirds.length; i++) {
      if (!khatma.wirds[i].isCompleted) {
        // found current, now look for next unread after it
        for (int j = i + 1; j < khatma.wirds.length; j++) {
          if (!khatma.wirds[j].isCompleted) return khatma.wirds[j];
        }
        return null;
      }
    }
    return null;
  }

  Future<void> deleteKhatma(String id) async {
    if (state is! KhatmaLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('khatma_$id');

    // Clear legacy active if deleting the legacy fallback
    if (prefs.getString(_activeIdKey) == id) {
      await prefs.remove(_activeIdKey);
      await prefs.remove(_khatmaKey);
    }

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('wird_last_page_') || key.startsWith('${id}_')) {
        await prefs.remove(key);
      }
    }

    // Cancel ONLY this khatma's notifications (don't touch others)
    await NotificationService.cancelKhatmaNotifications(id);

    List<KhatmaModel> khatmas = List<KhatmaModel>.from(
      (state as KhatmaLoaded).khatmas,
    );
    khatmas.removeWhere((k) => k.id == id);

    if (khatmas.isEmpty) {
      emit(KhatmaEmpty());
    } else {
      // Reschedule remaining khatmas' notifications
      await NotificationService.rescheduleAllKhatmaNotifications();
      emit(KhatmaLoaded(khatmas));
    }
  }
}
