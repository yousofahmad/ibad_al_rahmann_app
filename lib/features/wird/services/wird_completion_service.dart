import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

class WirdCompletionService {
  static Future<bool> complete({
    required BuildContext context,
    bool isKahfMode = false,
    bool isWirdMode = false,
    String? khatmaId,
    int? wirdIndex,
  }) async {
    AppLogger.log(
      "WirdCompletion",
      "complete() -> isKahf: $isKahfMode, isWird: $isWirdMode, khatmaId: $khatmaId, wirdIndex: $wirdIndex",
    );
    if (isKahfMode) {
      await DailyTrackerService.markKahfDone();
      return false;
    } else if (isWirdMode) {
      // ignore: use_build_context_synchronously
      final cubit = context.read<KhatmaCubit>();

      String? actualKhatmaId = khatmaId;
      if (actualKhatmaId == null && cubit.state is KhatmaLoaded) {
        final khatmas = (cubit.state as KhatmaLoaded).khatmas;
        if (khatmas.isNotEmpty) {
          actualKhatmaId = khatmas.first.id;
        }
      }

      if (actualKhatmaId == null) return false;

      final khatma = cubit.getKhatmaById(actualKhatmaId);
      if (khatma == null) return false;

      final indexToMark = wirdIndex ?? khatma.currentWirdIndex;
      final isKhatmaFinished = await cubit.markWirdAsCompleted(
        actualKhatmaId,
        indexToMark,
      );

      // Update wirdIndex reference for accountability below
      wirdIndex = indexToMark;

      final accountabilityKey = accountabilityKeyForWird(
        label: khatma.accountabilityLabel,
        notificationType: khatma.notificationType,
        wirdIndex: wirdIndex,
        startPrayerOffset: khatma.startPrayerOffset,
      );
      await DailyTrackerService.markWirdDone(accountabilityKey);

      return isKhatmaFinished;
    }
    return false;
  }

  static String prayerNameForWird({
    required int wirdIndex,
    int startPrayerOffset = 0,
  }) {
    const prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final prayerIndex = (wirdIndex + startPrayerOffset) % prayers.length;
    return prayers[prayerIndex];
  }

  static String accountabilityKeyForWird({
    required String label,
    required String notificationType,
    required int wirdIndex,
    int startPrayerOffset = 0,
  }) {
    final effectiveLabel = label.isNotEmpty ? label : 'ورد التلاوة';
    if (notificationType != 'prayer') return effectiveLabel;

    final prayerName = prayerNameForWird(
      wirdIndex: wirdIndex,
      startPrayerOffset: startPrayerOffset,
    );
    return '$effectiveLabel - $prayerName';
  }
}
