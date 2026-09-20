import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adhan/adhan.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

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
    } else if (isWirdMode && khatmaId != null && wirdIndex != null) {
      // ignore: use_build_context_synchronously
      final cubit = context.read<KhatmaCubit>();
      final khatma = cubit.getKhatmaById(khatmaId);
      
      await cubit.markWirdAsCompleted(khatmaId, wirdIndex);
      
      if (khatma != null && khatma.accountabilityLabel.isNotEmpty) {
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
