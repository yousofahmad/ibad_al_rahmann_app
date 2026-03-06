import 'package:home_widget/home_widget.dart';

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
  static const String appGroupId = 'group.com.example.ibad_al_rahmann';
  static const String smallWidgetName = 'PrayerWidgetProvider';
  static const String wideWidgetName = 'PrayerWidgetWideProvider';
  static const String largeWidgetName = 'PrayerWidgetLargeProvider';

  static Future<void> initialize() async {
    // تهيئة الجروب ليتم التواصل مع الودجت
    await HomeWidget.setAppGroupId(appGroupId);

    // Register the background callback so Android can call into Dart
    // when the widget is interacted with while the app is not running.
    HomeWidget.registerBackgroundCallback(interactiveCallback);
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
    required int prayerIndex,
    required String prayerTime,
    int? nextPrayerEpoch,
    bool? isCountUp,
    String? sunriseTime,
    String? locationName,
  }) async {
    // حفظ البيانات في SharedPreferences الخاصة بالودجت
    await HomeWidget.saveWidgetData<String>('fajr_time', fajr);
    await HomeWidget.saveWidgetData<String>('dhuhr_time', dhuhr);
    await HomeWidget.saveWidgetData<String>('asr_time', asr);
    await HomeWidget.saveWidgetData<String>('maghrib_time', maghrib);
    await HomeWidget.saveWidgetData<String>('isha_time', isha);
    await HomeWidget.saveWidgetData<String>('prayer_name', nextName);
    await HomeWidget.saveWidgetData<String>('prayer_time', prayerTime);

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

    await HomeWidget.saveWidgetData<String>('hijri_date', hijri);
    await HomeWidget.saveWidgetData<int>('prayerIndex', prayerIndex);
    if (sunriseTime != null) {
      await HomeWidget.saveWidgetData<String>('sunrise_time', sunriseTime);
    }
    if (locationName != null) {
      await HomeWidget.saveWidgetData<String>('location_name', locationName);
    }

    // --- Dynamic Golden Widget Data (45-Minute Rule) ---
    if (nextPrayerEpoch != null) {
      // Caller manages if it's "Current + 45" or "Next".
    }

    // Send request to update standard & wide widgets
    await HomeWidget.updateWidget(
      name: smallWidgetName,
      androidName: smallWidgetName,
    );
    await HomeWidget.updateWidget(
      name: wideWidgetName,
      androidName: wideWidgetName,
    );
    await HomeWidget.updateWidget(
      name: largeWidgetName,
      androidName: largeWidgetName,
    );
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
}
