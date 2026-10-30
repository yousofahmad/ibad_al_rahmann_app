import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

/// IMPORTANT: This function MUST be:
///   1. A TOP-LEVEL Dart function (not inside any class).
///   2. Annotated with @pragma('vm:entry-point') so the AOT compiler
///      does NOT strip it — removing this annotation causes the
///      "Could not resolve main entrypoint function" crash in the
///      background isolate spawned by Android.
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  // IMPORTANT: This handles background widget interactions (Entrypoint).
  if (uri?.host == 'update') {
    // Optional: add logic here if needed
  }
}

class HomeWidgetService {
  // اسم التطبيق أو الحزمة للـ Group
  static const String appGroupId = 'group.app.ibad_al_rahmann';
  static const String smallWidgetName = 'PrayerWidgetProvider';
  static const String largeWidgetName = 'PrayerWidgetLargeProvider';
  static const String wirdWidgetName = 'WirdWidgetProvider';
  static const String azkarWidgetName = 'AzkarWidgetProvider';

  static Future<void> initialize() async {
    // تهيئة الجروب ليتم التواصل مع الودجت
    await HomeWidget.setAppGroupId(appGroupId);

    // Register the background callback so Android can call into Dart
    // when the widget is interacted with while the app is not running.
    HomeWidget.registerInteractivityCallback(interactiveCallback);
  }

  /// وظيفة لتحديث الودجت الخاص بالصلاة ببيانات جديدة
  static Future<void> updatePrayerWidget({
    required String fajr,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    required String nextName,
    required String countdown,
    required String hijri,
    required int hijriOffset,
    required int prayerIndex,
    required String prayerTime,
    int? nextPrayerEpoch,
    bool? isCountUp,
    bool? persistentEnabled,
    String? sunriseTime,
    String? locationName,
    // Add Epochs for native smart logic
    int? fajrEpoch,
    int? dhuhrEpoch,
    int? asrEpoch,
    int? maghribEpoch,
    int? ishaEpoch,
    int? sunriseEpoch,
  }) async {
    // حفظ البيانات في SharedPreferences الخاصة بالودجت
    await HomeWidget.saveWidgetData<String>('fajr', fajr);
    await HomeWidget.saveWidgetData<String>('dhuhr', dhuhr);
    await HomeWidget.saveWidgetData<String>('asr', asr);
    await HomeWidget.saveWidgetData<String>('maghrib', maghrib);
    await HomeWidget.saveWidgetData<String>('isha', isha);
    await HomeWidget.saveWidgetData<String>('nextName', nextName);
    await HomeWidget.saveWidgetData<String>('prayer_time', prayerTime);

    // Save Epochs
    if (fajrEpoch != null) {
      await HomeWidget.saveWidgetData<int>('fajr_epoch', fajrEpoch);
    }
    if (dhuhrEpoch != null) {
      await HomeWidget.saveWidgetData<int>('dhuhr_epoch', dhuhrEpoch);
    }
    if (asrEpoch != null) {
      await HomeWidget.saveWidgetData<int>('asr_epoch', asrEpoch);
    }
    if (maghribEpoch != null) {
      await HomeWidget.saveWidgetData<int>('maghrib_epoch', maghribEpoch);
    }
    if (ishaEpoch != null) {
      await HomeWidget.saveWidgetData<int>('isha_epoch', ishaEpoch);
    }
    if (sunriseEpoch != null) {
      await HomeWidget.saveWidgetData<int>('sunrise_epoch', sunriseEpoch);
    }

    // We keep countdown for legacy fallback but also pass the true Epoch target
    await HomeWidget.saveWidgetData<String>('countdown', countdown);
    if (nextPrayerEpoch != null) {
      await HomeWidget.saveWidgetData<int>(
        'next_prayer_time_epoch',
        nextPrayerEpoch,
      );
    }
    if (isCountUp != null) {
      await HomeWidget.saveWidgetData<bool>('is_count_up', isCountUp);
    }
    if (persistentEnabled != null) {
      await HomeWidget.saveWidgetData<bool>(
        'persistent_notification_enabled',
        persistentEnabled,
      );
    }

    await HomeWidget.saveWidgetData<String>('hijri', hijri);
    await HomeWidget.saveWidgetData<int>('hijriOffset', hijriOffset);
    await HomeWidget.saveWidgetData<int>('prayerIndex', prayerIndex);
    if (sunriseTime != null) {
      await HomeWidget.saveWidgetData<String>('sunrise_time', sunriseTime);
    }
    if (locationName != null) {
      await HomeWidget.saveWidgetData<String>('locationName', locationName);
    }

    // Update the existing prayer widgets without changing their layouts.
    await HomeWidget.updateWidget(
      name: smallWidgetName,
      androidName: smallWidgetName,
    );
    await HomeWidget.updateWidget(
      name: largeWidgetName,
      androidName: largeWidgetName,
    );
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetWideProvider',
      androidName: 'PrayerWidgetWideProvider',
    );
    await updateAzkarWidget(trigger: 'prayer_times_updated');
  }

  static Future<void> updateWirdWidget({
    String trigger = 'wird_data_updated',
  }) => _requestWidgetRefresh(wirdWidgetName, trigger);

  static Future<void> updateAzkarWidget({
    String trigger = 'azkar_data_updated',
  }) => _requestWidgetRefresh(azkarWidgetName, trigger);

  static Future<void> _requestWidgetRefresh(
    String providerName,
    String trigger,
  ) async {
    if (!Platform.isAndroid) return;

    final stopwatch = Stopwatch()..start();
    AppLogger.logEvent('WidgetUpdate', 'refresh_requested', {
      'provider': providerName,
      'trigger': trigger,
    });
    try {
      await HomeWidget.updateWidget(
        name: providerName,
        androidName: providerName,
      );
      AppLogger.logEvent('WidgetUpdate', 'refresh_request_finished', {
        'provider': providerName,
        'trigger': trigger,
        'outcome': 'request_sent',
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      AppLogger.logEvent('WidgetUpdate', 'refresh_request_failed', {
        'provider': providerName,
        'trigger': trigger,
        'outcome': 'failed',
        'reason': error.runtimeType.toString(),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
    }
  }

  static Future<void> updateGoldWidgetData({
    required int targetEpoch,
    required bool isCountUp,
  }) async {
    await HomeWidget.saveWidgetData<int>('gold_target_epoch', targetEpoch);
    await HomeWidget.saveWidgetData<bool>('gold_is_count_up', isCountUp);
    await HomeWidget.updateWidget(
      name: largeWidgetName,
      androidName: largeWidgetName,
    );
  }

  static Future<void> updateThirtyDaysData(String jsonString) async {
    await HomeWidget.saveWidgetData<String>('prayer_times_30d', jsonString);
  }
}
