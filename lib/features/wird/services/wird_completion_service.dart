import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adhan/adhan.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class WirdCompletionService {
  static Future<void> complete({
    required BuildContext context,
    bool isKahfMode = false,
    bool isWirdMode = false,
    String? khatmaId,
    int? wirdIndex,
  }) async {
    if (isKahfMode) {
      await DailyTrackerService.markKahfDone();
    } else if (isWirdMode && khatmaId != null && wirdIndex != null) {
      // ignore: use_build_context_synchronously
      final cubit = context.read<KhatmaCubit>();
      final khatma = cubit.getKhatmaById(khatmaId);
      
      await cubit.markWirdAsCompleted(khatmaId, wirdIndex);
      
      if (khatma != null && khatma.accountabilityLabel.isNotEmpty) {
        if (khatma.notificationType == 'prayer') {
          final pName = _currentPrayerArabicName();
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

  static String _currentPrayerArabicName() {
    // We cannot use read<PrayerService> here easily if we don't have context, but we can if we want.
    // PrayerService has getPrayerTimes() which is a sync getter if we have a global instance or similar.
    // Wait, PrayerService is provided at root. We can use PrayerService().getPrayerTimes() if it's a singleton, but it's a ChangeNotifier usually.
    // I'll just check if there's a static way or use the current time.
    final times = PrayerService().getPrayerTimes();
    if (times == null) return '';
    final prayer = times.currentPrayer();
    switch (prayer) {
      case Prayer.fajr: return 'الفجر';
      case Prayer.sunrise: return 'الفجر';
      case Prayer.dhuhr: return 'الظهر';
      case Prayer.asr: return 'العصر';
      case Prayer.maghrib: return 'المغرب';
      case Prayer.isha: return 'العشاء';
      default: return '';
    }
  }
}
