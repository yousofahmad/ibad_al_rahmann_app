import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

class WirdCompletionService {
  static Future<void> complete({
    required BuildContext context,
    bool isKahfMode = false,
    bool isWirdMode = false,
    String? khatmaId,
    int? wirdIndex,
  }) async {
    AppLogger.log("WirdCompletion", "complete() -> isKahf: $isKahfMode, isWird: $isWirdMode, khatmaId: $khatmaId, wirdIndex: $wirdIndex");
    if (isKahfMode) {
      await DailyTrackerService.markKahfDone();
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
      
      if (actualKhatmaId == null) return;
      
      final khatma = cubit.getKhatmaById(actualKhatmaId);
      if (khatma == null) return;
      
      final indexToMark = wirdIndex ?? khatma.currentWirdIndex;
      await cubit.markWirdAsCompleted(actualKhatmaId, indexToMark);
      
      // Update wirdIndex reference for accountability below
      wirdIndex = indexToMark;
      
      if (khatma.accountabilityLabel.isNotEmpty) {
        if (khatma.notificationType == 'prayer') {
          final pName = _prayerNameFromIndex(wirdIndex);
          if (pName.isNotEmpty) {
            await DailyTrackerService.markWirdDone('${khatma.accountabilityLabel} - $pName');
          }
        } else {
          await DailyTrackerService.markWirdDone(khatma.accountabilityLabel);
        }
      } else {
        // Fallback for old Khatmas or empty labels
        await DailyTrackerService.markWirdDone('ورد التلاوة');
      }
    }
  }

static String _prayerNameFromIndex(int index) {
    switch (index % 5) {
      case 0: return 'الفجر';
      case 1: return 'الظهر';
      case 2: return 'العصر';
      case 3: return 'المغرب';
      case 4: return 'العشاء';
      default: return '';
    }
  }
}
