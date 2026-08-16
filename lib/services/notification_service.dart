// Unified Notification Service
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'prayer_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationContentService {
  static String getNotificationBody(String prayerName) {
    switch (prayerName) {
      case 'Fajr': return "حان الآن موعد صلاة الفجر";
      case 'Sunrise': return "حان الآن وقت الشروق";
      case 'Dhuhr': return "حان الآن موعد صلاة الظهر";
      case 'Asr': return "حان الآن موعد صلاة العصر";
      case 'Maghrib': return "حان الآن موعد صلاة المغرب";
      case 'Isha': return "حان الآن موعد صلاة العشاء";
      default: return "حان الآن موعد الصلاة";
    }
  }
}

class NotificationService {
  static const _platform = MethodChannel('app.ibad_al_rahmann/native_notifications');
  static final ValueNotifier<String?> onNotificationTap = ValueNotifier<String?>(null);

  static bool _isBatching = false;
  static final List<Map<String, dynamic>> _batchAlarms = [];
  static String? currentLogFilter;

  static Future<void> updateWidgetData(Map<String, dynamic> data) async {
    for (String key in data.keys) {
      await HomeWidget.saveWidgetData(key, data[key]);
    }
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider', // Android Class Name
      iOSName: 'PrayerWidgetProvider',
    );
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetLargeProvider',
    );
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetWideProvider',
    );
  }

  static Future<void> init() async {
    _platform.setMethodCallHandler(_handleMethodCall);
  }

  /// Writes a message to the native NativeLogger file for release-build debugging.
  static void nativeLog(String message) {
    _platform.invokeMethod('nativeLog', {'message': message}).catchError((_) {});
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPayloadReceived') {
      final String? payload = call.arguments;
      nativeLog('onPayloadReceived: $payload');
      if (payload != null) {
        onNotificationTap.value = null; // Force trigger even for identical consecutive payloads
        onNotificationTap.value = payload;
      }
    }
  }

  static Future<String?> checkLaunchPayload() async {
    try {
      final result = await _platform.invokeMethod<String?>('getLaunchPayload');
      nativeLog('checkLaunchPayload result: $result');
      return result;
    } catch (e) {
      nativeLog('checkLaunchPayload ERROR: $e');
      return null;
    }
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _platform.invokeMethod('isBatteryOptimizationIgnored') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> checkAndRequestBatteryPermission(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('has_seen_battery_dialog') == true) return;

      final isIgnored = await isBatteryOptimizationIgnored();
      if (isIgnored) {
        await prefs.setBool('has_seen_battery_dialog', true);
        return;
      }

      if (!context.mounted) return;

      // Show explanatory dialog before opening settings
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "تحسين البطارية",
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "لضمان وصول الأذان والأذكار في موعدها بدقة، يرجى اختيار 'غير مقيد' (Unrestricted) في إعدادات البطارية للتطبيق.\n\nسيتم فتح الإعدادات الآن، يرجى التأكد من اختيار الخيار المناسب.",
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: AppConsts.cairo),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("لا تسألني مرة أخرى", style: TextStyle(fontFamily: AppConsts.cairo, color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("فتح الإعدادات", style: TextStyle(fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (result == true) {
        await prefs.setBool('has_seen_battery_dialog', true);
        await _platform.invokeMethod('checkBatteryOptimization');
      } else if (result == false) {
        await prefs.setBool('has_seen_battery_dialog', true);
      }
    } catch (_) {}
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
    String? soundName = "nafis",
  }) async {
    try {
      final now = DateTime.now();
      await _platform.invokeMethod('scheduleAlarm', {
        'id': now.millisecondsSinceEpoch.remainder(100000), // Random ID
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'hour': now.hour,
        'minute': now.minute, // Triggers immediately if time is exact or slightly past
        'title': title,
        'body': body,
        'soundName': soundName,
        'payload': payload,
      });
    } catch (_) {}
  }

  static Future<void> vibrate({int duration = 500}) async {
    try {
      await _platform.invokeMethod('vibrate', {'duration': duration});
    } catch (_) {}
  }

  static Future<void> generateThirtyDayCache() async {
    try {
      await _platform.invokeMethod('generateThirtyDayCache');
    } catch (_) {}
  }

  static Future<void> scheduleAll(
    PrayerTimes times, {
    List<ExtendedPrayer>? extended,
    String? logFilter,
    bool isUserAction = false,
  }) async {
    generateThirtyDayCache(); // Background refresh on native side

    // Push Data to Home Screen Widgets (PUSH Strategy)
    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTimes = await PrayerService.getPrayerTimesForDateStatic(tomorrow);

      await updateWidgetData({
        'fajr_epoch': times.fajr.millisecondsSinceEpoch,
        'dhuhr_epoch': times.dhuhr.millisecondsSinceEpoch,
        'asr_epoch': times.asr.millisecondsSinceEpoch,
        'maghrib_epoch': times.maghrib.millisecondsSinceEpoch,
        'isha_epoch': times.isha.millisecondsSinceEpoch,
        'next_fajr_epoch': tomorrowTimes?.fajr.millisecondsSinceEpoch ?? (times.isha.millisecondsSinceEpoch + 8 * 3600000),
      });

      // Store today's Fajr epoch in SharedPreferences so PrayerFocusOverlay.kt can
      // determine whether the user is between midnight and Fajr (Islamic day boundary).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fajr_epoch_today', times.fajr.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Widget Push Error: $e");
    }

    currentLogFilter = logFilter;
    _isBatching = true;
    _batchAlarms.clear();

    try {
      // ── CRITICAL: Clear all old alarms ──────────────────────────────────────
      await cancelAll(includeWird: true, excludeIntervalAlarms: !isUserAction);

      await Future.delayed(const Duration(milliseconds: 300)); 

      debugPrint("Native: Preparing Batch Schedule... (isUserAction: $isUserAction)");
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      // --- Azkar ---
      final morningMode = prefs.getString('azkar_morning_mode') ?? 'sound';
      if (morningMode != 'none') {
        final t = (prefs.getString('time_azkar_morning') ?? "06:00").split(":");
        await _scheduleNative(1, "أذكار الصباح", "حان موعد أذكار الصباح", int.parse(t[0]), int.parse(t[1]), morningMode == 'silent_notif' ? 'silent_notif' : "sabah", payload: "sabah", customSoundName: "sabah");
      }

      final eveningMode = prefs.getString('azkar_evening_mode') ?? 'sound';
      if (eveningMode != 'none') {
        final t = (prefs.getString('time_azkar_evening') ?? "17:00").split(":");
        await _scheduleNative(3, "أذكار المساء", "حان موعد أذكار المساء", int.parse(t[0]), int.parse(t[1]), eveningMode == 'silent_notif' ? 'silent_notif' : "masaa", payload: "masaa", customSoundName: "masaa");
      }

      final ruqyahEnabled = prefs.getBool('azkar_ruqyah_enabled') ?? false;
      if (ruqyahEnabled) {
        // الرقية تُرسَل صامتةً في نفس وقت أذكار الصباح
        if (morningMode != 'none') {
          final t = (prefs.getString('time_azkar_morning') ?? "06:00").split(":");
          await _scheduleNative(4, "الرقية الشرعية", "لا تنس قراءة الرقية الشرعية صباحًا", int.parse(t[0]), int.parse(t[1]), 'silent_notif', payload: "ruqyah");
        }
        // الرقية تُرسَل صامتةً في نفس وقت أذكار المساء
        if (eveningMode != 'none') {
          final t = (prefs.getString('time_azkar_evening') ?? "17:00").split(":");
          await _scheduleNative(5, "الرقية الشرعية", "لا تنس قراءة الرقية الشرعية مساءً", int.parse(t[0]), int.parse(t[1]), 'silent_notif', payload: "ruqyah");
        }
      }

      await rescheduleWird();

      // --- Interval Alarms (ONLY on User Action) ---
      if (isUserAction) {
        if (prefs.getBool('notif_takbeerat') ?? false) await scheduleTakbeerat(times);
        if (prefs.getBool('eid_fitr_takbeer') ?? false) await scheduleEidFitrTakbeerat(times);
        if (prefs.getBool('salawat_reminder_enabled') ?? false) {
          final intervalMins = prefs.getInt('salawat_reminder_minutes') ?? 60;
          final daysList = prefs.getStringList('salawat_reminder_days') ?? [DateTime.friday.toString()];
          final selectedDays = daysList.map((e) => int.parse(e)).toList();
          if (intervalMins > 0 && selectedDays.isNotEmpty) {
            await scheduleSalawatReminders(intervalMins, selectedDays);
          } else {
            await scheduleSalawatReminders(0, []);
          }
        } else {
          // CRITICAL: Cancel natively to prevent old version ghost alarms from chaining
          await scheduleSalawatReminders(0, []);
        }
      }

      // --- Seasonal & Special (Check Current & Next Day) ---
      final hijriOffset = PrayerService().hijriOffset;
      
      for (int i = 0; i < 3; i++) {
        final targetDate = now.add(Duration(days: i));
        final targetHijri = PrayerService.getHijriWithOffset(hijriOffset, targetDate);
        final int hMonth = targetHijri.hMonth;
        final int hDay = targetHijri.hDay;
        
        final dayTimes = await PrayerService.getPrayerTimesForDateStatic(targetDate);
        if (dayTimes == null) continue;

        // Ramadan / Fasting Iftar/Suhoor
        final bool isIftarOn = prefs.getBool('iftar_alarm') ?? false;
        final bool isSuhoorOn = prefs.getBool('suhoor_alarm') ?? false;
        
        if (isIftarOn) {
          final mode = prefs.getString('iftar_mode') ?? 'ramadan';
          bool shouldShow = false;
          if (hMonth == 9) {
            shouldShow = true;
          } else if (mode == 'all_year') {
            final days = prefs.getInt('iftar_all_year_days') ?? 0x7F;
            if ((days & (1 << (targetDate.weekday - 1))) != 0) shouldShow = true;
          }
          if (shouldShow) {
            final mins = prefs.getInt('iftar_minutes_before') ?? 30;
            final time = dayTimes.maghrib.subtract(Duration(minutes: mins));
            if (time.isAfter(now)) await scheduleRamadanAlert(400 + i, 'اقتراب الإفطار', 'باقي $mins دقيقة على المغرب', time, customSoundName: 'pre_iftar');
          }
        }
        
        if (isSuhoorOn) {
          final mode = prefs.getString('suhoor_mode') ?? 'ramadan';
          bool shouldShow = false;
          if (hMonth == 9) {
            shouldShow = true;
          } else if (mode == 'all_year') {
            final days = prefs.getInt('suhoor_all_year_days') ?? 0x7F;
            if ((days & (1 << (targetDate.weekday - 1))) != 0) shouldShow = true;
          }
          if (shouldShow) {
            final mins = prefs.getInt('suhoor_minutes_before') ?? 60;
            final time = dayTimes.fajr.subtract(Duration(minutes: mins));
            if (time.isAfter(now)) await scheduleRamadanAlert(410 + i, 'وقت السحور', 'باقي $mins دقيقة على الفجر', time, customSoundName: 'time_suhoor');
          }
        }

        // Eid Alerts
        if (prefs.getBool('eid_fitr_alarm') ?? false) {
          if (hMonth == 9 && (hDay == 29 || hDay == 30)) {
            final alertTime = dayTimes.maghrib;
            if (alertTime.isAfter(now)) await scheduleEidAlert(2200 + i, 'تكبيرات ليلة العيد', 'الله أكبر الله أكبر...', alertTime, sound: 'eid_takbeerat');
          }
          if (hMonth == 10 && hDay == 1) {
            final eidHour = prefs.getInt('eid_fitr_hour');
            final eidMin = prefs.getInt('eid_fitr_minute');
            DateTime eidTime;
            if (eidHour != null && eidMin != null) {
              eidTime = DateTime(targetDate.year, targetDate.month, targetDate.day, eidHour, eidMin);
            } else {
              eidTime = dayTimes.sunrise.add(Duration(minutes: prefs.getInt('eid_prayer_minutes_after_sunrise') ?? 20));
            }
            if (eidTime.isAfter(now)) await scheduleEidAlert(2100 + i, 'عيد الفطر - صلاة العيد', 'كل عام وأنتم بخير', eidTime, sound: 'eid_takbeerat');
          }
        }
        if (prefs.getBool('notif_eid_dhulhijjah') ?? false) {
          if (hMonth == 12 && hDay == 10) {
            final eidHour = prefs.getInt('eid_adha_hour');
            final eidMin = prefs.getInt('eid_adha_minute');
            DateTime eidTime;
            if (eidHour != null && eidMin != null) {
              eidTime = DateTime(targetDate.year, targetDate.month, targetDate.day, eidHour, eidMin);
            } else {
              eidTime = dayTimes.sunrise.add(Duration(minutes: prefs.getInt('eid_adha_minutes_after_sunrise') ?? 20));
            }
            if (eidTime.isAfter(now)) await scheduleEidAlert(2150 + i, 'عيد الأضحى - صلاة العيد', 'كل عام وأنتم بخير', eidTime, sound: 'eid_takbeerat');
          }
        }
        if ((prefs.getBool('notif_arafah') ?? false) && hMonth == 12 && hDay == 9) {
          await scheduleArafahForDate(dayTimes, now, i);
        }

        // Jumua
        if (targetDate.weekday == DateTime.friday && (prefs.getBool('notif_jumua') ?? false)) {
          final minsBefore = prefs.getInt('jumua_minutes_before') ?? 60;
          final jumuaTime = dayTimes.dhuhr.subtract(Duration(minutes: minsBefore));
          if (jumuaTime.isAfter(now)) {
            await _scheduleNative(2300 + i, 'صلاة الجمعة', 'باقي $minsBefore دقيقة على صلاة الجمعة', jumuaTime.hour, jumuaTime.minute, 'ibad_al_rahmann_tone', payload: 'jumuah', year: jumuaTime.year, month: jumuaTime.month, day: jumuaTime.day, customSoundName: 'ibad_al_rahmann_tone');
          }
        }

        // Kahf & Friday Night Salawat (Merged)
        if (targetDate.weekday == DateTime.thursday && (prefs.getBool('notif_kahf_salawat') ?? true)) {
          final kahfTime = dayTimes.isha.add(const Duration(minutes: 60)); 
          if (kahfTime.isAfter(now)) {
            await _scheduleNative(2350 + i, 'ليلة الجمعة', 'لا تنس قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ', kahfTime.hour, kahfTime.minute, 'saly_3ala_mo7amad', payload: 'kahf', year: kahfTime.year, month: kahfTime.month, day: kahfTime.day, customSoundName: 'saly_3ala_mo7amad');
          }
        }

        // Qadaa Reminders
        if (prefs.getBool('qadaa_daily_prayer_reminder') ?? false) {
           final timeStr = prefs.getString('qadaa_daily_prayer_time') ?? '20:00';
           final parts = timeStr.split(':');
           final qadaaTime = DateTime(targetDate.year, targetDate.month, targetDate.day, int.parse(parts[0]), int.parse(parts[1]));
           if (qadaaTime.isAfter(now)) {
             await _scheduleNative(2700 + i, 'تذكير القضاء', 'لا تنس إضافة الصلوات التي قضيتها اليوم', qadaaTime.hour, qadaaTime.minute, 'default', year: qadaaTime.year, month: qadaaTime.month, day: qadaaTime.day, payload: 'qadaa');
           }
        }
        
        final qadaaFastingFreq = prefs.getString('qadaa_fasting_reminder_freq') ?? 'إيقاف';
        if (qadaaFastingFreq != 'إيقاف') {
           bool shouldRemind = false;
           if (qadaaFastingFreq == 'يومياً') {
             shouldRemind = true;
           } else if (qadaaFastingFreq == 'أسبوعياً') {
             final fastDay = prefs.getInt('qadaa_fasting_reminder_day') ?? 7;
             // Remind the night before (Sunday=7, Monday=1...)
             if (targetDate.weekday == (fastDay == 1 ? 7 : fastDay - 1)) shouldRemind = true;
           } else if (qadaaFastingFreq == 'شهرياً') {
             final fastDay = prefs.getInt('qadaa_fasting_reminder_day') ?? 1;
             // Remind the night before in Hijri
             if (hDay == (fastDay == 1 ? 29 : fastDay - 1)) shouldRemind = true; 
           }
           
           if (shouldRemind) {
             final fastingTime = dayTimes.isha.add(const Duration(minutes: 60)); // Remind 1 hour after Isha
             if (fastingTime.isAfter(now)) {
               await _scheduleNative(2750 + i, 'تنبيه صيام القضاء', 'تذكير بصيام القضاء غداً', fastingTime.hour, fastingTime.minute, 'default', year: fastingTime.year, month: fastingTime.month, day: fastingTime.day, payload: 'qadaa');
             }
           }
        }

        // Fasting Reminders (Scheduled the night before)
        // Use date-based IDs (day of week 1-7) to prevent duplicate scheduling
        // when scheduleAll is called multiple times rapidly.
        final dayId = targetDate.weekday; // 1=Mon..7=Sun, always unique per weekday
        // Monday Fasting (Reminder on Sunday night)
        if (targetDate.weekday == DateTime.sunday && (prefs.getBool('notif_fasting_monday') ?? true)) {
          final reminderTime = dayTimes.isha.add(const Duration(minutes: 60));
          if (reminderTime.isAfter(now)) {
            await _scheduleNative(2400 + dayId, 'غداً الإثنين,, صوم يقربك لله 🤲', 'اغتنم سنة الحبيب ﷺ.. فالصيام طريق للبركة والنور 🥰', reminderTime.hour, reminderTime.minute, 'default', payload: 'fasting', year: reminderTime.year, month: reminderTime.month, day: reminderTime.day);
          }
        }
        // Thursday Fasting (Reminder on Wednesday night)
        if (targetDate.weekday == DateTime.wednesday && (prefs.getBool('notif_fasting_thursday') ?? true)) {
          final reminderTime = dayTimes.isha.add(const Duration(minutes: 60));
          if (reminderTime.isAfter(now)) {
            await _scheduleNative(2450 + dayId, 'غداً الخميس,, صوم يقربك لله 🤲', 'اغتنم سنة الحبيب ﷺ.. فالصيام طريق للبركة والنور 🥰', reminderTime.hour, reminderTime.minute, 'default', payload: 'fasting', year: reminderTime.year, month: reminderTime.month, day: reminderTime.day);
          }
        }
        // White Days Fasting (13, 14, 15 of Hijri month - Remind on 12, 13, 14 night)
        if ((hDay == 12 || hDay == 13 || hDay == 14) && (prefs.getBool('notif_fasting_white_days') ?? true)) {
          final reminderTime = dayTimes.isha.add(const Duration(minutes: 60));
          if (reminderTime.isAfter(now)) {
            await _scheduleNative(2500 + dayId, 'غداً الأيام البيض,, صوم يقربك لله 🤲', 'اغتنم سنة الحبيب ﷺ.. فالصيام طريق للبركة والنور 🥰', reminderTime.hour, reminderTime.minute, 'default', payload: 'fasting', year: reminderTime.year, month: reminderTime.month, day: reminderTime.day);
          }
        }

        // Qiyam — Last Third of Night
        final qiyamMode = prefs.getString('adhan_mode_Last_third') ?? 'none';
        if (qiyamMode != 'none') {
          final nextDayTimes = await PrayerService.getPrayerTimesForDateStatic(targetDate.add(const Duration(days: 1)));
          if (nextDayTimes != null) {
            final nightDuration = nextDayTimes.fajr.difference(dayTimes.maghrib);
            final lastThird   = nextDayTimes.fajr.subtract(Duration(seconds: (nightDuration.inSeconds / 3).round()));
            final firstThird  = dayTimes.maghrib.add(Duration(seconds: (nightDuration.inSeconds / 3).round()));
            final midNight    = dayTimes.maghrib.add(Duration(seconds: (nightDuration.inSeconds / 2).round()));

            // Last third (Qiyam) — Use date-based ID to prevent duplicate from rapid calls
            if (lastThird.isAfter(now)) {
              await _scheduleNative(
                2550 + targetDate.weekday, 'قيام الليل', 'حان وقت ثلث الليل الأخير',
                lastThird.hour, lastThird.minute,
                qiyamMode == 'silent_notif' ? 'silent_notif' : 'night_last',
                customSoundName: 'night_last',
                year: lastThird.year, month: lastThird.month, day: lastThird.day,
              );
            }

            // First third
            final firstThirdMode = prefs.getString('adhan_mode_First_third') ?? 'none';
            if (firstThirdMode != 'none' && firstThird.isAfter(now)) {
              await _scheduleNative(
                2600 + i, 'ثلث الليل الأول', 'دخل ثلث الليل الأول',
                firstThird.hour, firstThird.minute,
                firstThirdMode == 'silent_notif' ? 'silent_notif' : 'night_first',
                customSoundName: 'night_first',
                year: firstThird.year, month: firstThird.month, day: firstThird.day,
              );
            }

            // Midnight
            final midnightMode = prefs.getString('adhan_mode_Midnight') ?? 'none';
            if (midnightMode != 'none' && midNight.isAfter(now)) {
              await _scheduleNative(
                2650 + i, 'منتصف الليل', 'حان منتصف الليل',
                midNight.hour, midNight.minute,
                midnightMode == 'silent_notif' ? 'silent_notif' : 'night_mid',
                customSoundName: 'night_mid',
                year: midNight.year, month: midNight.month, day: midNight.day,
              );
            }
          }
        }
        
        // --- Core Prayers, Sunrise, and Duha are delegated entirely to Native Prayer Engine ---
      }

      // --- Core Prayers: delegated entirely to Native Prayer Engine ---
      // NativePrayerScheduler owns IDs 100-114 (Adhan), 3000-3014 (Pre-Adhan), 5000-5014 (Iqama).
      // Flutter only acts as a configuration bridge — settings are already in FlutterSharedPreferences.
      try {
        await _platform.invokeMethod('startNativePrayerEngine');
      } catch (_) {}

      if (_batchAlarms.isNotEmpty) {
        await _platform.invokeMethod('scheduleAlarms', {'alarms': _batchAlarms});
        _batchAlarms.clear();
      }

      // Start/Sync the native foreground service to ensure persistent notification & widgets are updated
      await _platform.invokeMethod('updatePrayerNotification', {});
      } catch (e) {
      debugPrint("Error in scheduleAll: $e");
    } finally {
      _isBatching = false;
    }
  }

  static Future<void> cancelAll({bool includeWird = false, bool excludeIntervalAlarms = false}) async {
    // NOTE: Prayer IDs (100-114, 3000-3014, 5000-5014) are intentionally excluded;
    //       NativePrayerScheduler owns and manages them exclusively.
    List<int> ids = [1, 2, 3, 4, 5] +
        List.generate(40, (i) => 200 + i) + // 200-239 (Next Prayer Alerts)
        List.generate(40, (i) => 1000 + i) + // 1000-1039
        List.generate(100, (i) => 4000 + i) +
        List.generate(200, (i) => 400 + i) +
        List.generate(20, (i) => 500 + i) + // Eid/Ramadan
        List.generate(100, (i) => 700 + i) + // 700-799 (Jumua 705, Kahf 710, Fasting 720-724, Qiyam 730, FirstThird 734, Duha 732, Sunrise 736, Midnight 738)
        List.generate(100, (i) => 800 + i) + // 800-899 (Qadaa)
        // ── Legacy / Ghost IDs from old versions (must cancel on every reschedule) ──
        // Old qiyam system used IDs 2000-2009 (now replaced by 2550+i)
        List.generate(20, (i) => 2000 + i) +
        // New multi-day scheduling ranges (2100-2800)
        List.generate(700, (i) => 2100 + i);

    if (!excludeIntervalAlarms) {
      ids += List.generate(500, (i) => 8000 + i);
      ids += List.generate(200, (i) => 9000 + i);
    }
    ids += List.generate(100, (i) => 9600 + i);

    if (includeWird) {
      ids += List.generate(100, (i) => 600 + i);
      ids += List.generate(1000, (i) => 6000 + i);
    }

    try {
      await _platform.invokeMethod('cancelAlarms', {'ids': ids});
    } catch (_) {}
  }

  static Future<void> rescheduleAllKhatmaNotifications() async {
    await rescheduleWird();
  }

  static Future<void> cancelKhatmaNotifications(String id) async {
    int idBase = 100000 + (id.hashCode.abs() % 40000) * 10;
    List<int> ids = List.generate(10, (i) => idBase + i);
    try {
      await _platform.invokeMethod('cancelAlarms', {'ids': ids});
    } catch (_) {}
  }

  static Future<void> rescheduleWird() async {
    final prefs = await SharedPreferences.getInstance();
    Box? box;
    try {
      box = Hive.box('appDataBox');
    } catch (_) {
      // Hive not open yet — fall back to SharedPreferences (legacy)
    }

    final List<KhatmaModel> khatmas = [];

    // Primary: read from Hive (new storage after migration)
    if (box != null) {
      for (var key in box.keys) {
        if (key.toString().startsWith('khatma_')) {
          final data = box.get(key);
          if (data != null && data is String) {
            try {
              final k = KhatmaModel.fromJson(jsonDecode(data));
              khatmas.add(k);
              // Mirror to SharedPreferences so native Kotlin can read it on reboot
              await prefs.setString('khatma_${k.id}', data);
            } catch (_) {}
          }
        }
      }
    }

    // Fallback: read from SharedPreferences (pre-migration or edge cases)
    if (khatmas.isEmpty) {
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('khatma_')) {
          final data = prefs.getString(key);
          if (data != null) {
            try {
              khatmas.add(KhatmaModel.fromJson(jsonDecode(data)));
            } catch (_) {}
          }
        }
      }
    }

    for (final khatma in khatmas) {
      if (khatma.enableNotifications) {
        await _scheduleKhatmaNotifications(khatma, prefs);
      }
    }
  }

  static Future<void> _scheduleKhatmaNotifications(KhatmaModel khatma, SharedPreferences prefs) async {
    int idBase = 100000 + (khatma.id.hashCode.abs() % 40000) * 10;
    final now = DateTime.now();

    // Cancel existing khatma alarms first to avoid duplicates when rescheduleWird is called multiple times
    final cancelIds = List.generate(80, (i) => idBase + i);
    try { await _platform.invokeMethod('cancelAlarms', {'ids': cancelIds}); } catch (_) {}

    // حساب ما إذا كان المستخدم متأخراً عن الورد
    final startDay = DateTime(khatma.startDate.year, khatma.startDate.month, khatma.startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceStart = today.difference(startDay).inDays;

    int passedPeriods;
    if (khatma.notificationType == 'prayer') {
      final cp = PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      int prayerOffset = 0;
      if (cp == Prayer.dhuhr) {
        prayerOffset = 1;
      } else if (cp == Prayer.asr) {
        prayerOffset = 2;
      } else if (cp == Prayer.maghrib) {
        prayerOffset = 3;
      } else if (cp == Prayer.isha) {
        prayerOffset = 4;
      }
      passedPeriods = (daysSinceStart * 5 + prayerOffset - khatma.startPrayerOffset);
    } else {
      passedPeriods = daysSinceStart;
    }
    if (passedPeriods < 0) passedPeriods = 0;
    int delayedWirds = passedPeriods - khatma.currentWirdIndex;
    String bodyPrefix = delayedWirds > 0 ? "⚠️ أنت متأخر بمقدار $delayedWirds ورد .. " : (delayedWirds < 0 ? "🌟 أنت متقدم بمقدار ${-delayedWirds} ورد .. " : "");

    // Encode current wird page range into the payload for precise deep-link navigation
    final wirdIdx = khatma.currentWirdIndex.clamp(0, khatma.wirds.length - 1);
    final currentWird = khatma.wirds.isNotEmpty ? khatma.wirds[wirdIdx] : null;
    final startPage = currentWird?.startPage ?? 1;
    final endPage = currentWird?.endPage ?? 604;
    final payload = "khatma_${khatma.id}_${wirdIdx}_${startPage}_$endPage";
    final pageInfo = currentWird != null ? " (ص$startPage–$endPage)" : "";

    if (khatma.notificationType == 'daily') {
      int hour = 22; // Default 10 PM
      int minute = 0;
      
      if (khatma.dailyTime != null && khatma.dailyTime!.contains(":")) {
        final parts = khatma.dailyTime!.split(":");
        hour = int.tryParse(parts[0]) ?? 22;
        minute = int.tryParse(parts[1]) ?? 0;
      }

      for (int i = 0; i < 3; i++) { // Schedule for next 3 days
         final t = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: i));
          if (t.isAfter(now)) {
           final scheduledId = idBase + t.weekday;
           // await _scheduleNative(scheduledId, "ورد ${khatma.name}", "$bodyPrefixحان وقت وردك اليومي$pageInfo", t.hour, t.minute, "ibad_al_rahmann_tone", year: t.year, month: t.month, day: t.day, payload: payload, customSoundName: "ibad_al_rahmann_tone");
          }
      }
    } else if (khatma.notificationType == 'prayer') {
      for (int i = 0; i < 3; i++) {
        final targetDate = now.add(Duration(days: i));
        final dayTimes = await PrayerService.getPrayerTimesForDateStatic(targetDate);
        if (dayTimes == null) continue;

        final prayers = {
          'الفجر': dayTimes.fajr,
          'الظهر': dayTimes.dhuhr,
          'العصر': dayTimes.asr,
          'المغرب': dayTimes.maghrib,
          'العشاء': dayTimes.isha
        };

        int prayerIdx = 0;
        for (final entry in prayers.entries) {
          final name = entry.key;
          final time = entry.value;
          final t = time.add(Duration(minutes: khatma.notificationOffsetMinutes));
          if (t.isAfter(now)) {
            final scheduledId = idBase + (targetDate.weekday * 10) + prayerIdx;
            // await _scheduleNative(scheduledId, "ورد ${khatma.name}", "$bodyPrefixحان وقت وردك بعد صلاة $name$pageInfo", t.hour, t.minute, "ibad_al_rahmann_tone", year: t.year, month: t.month, day: t.day, payload: payload, customSoundName: "ibad_al_rahmann_tone");
          }
          prayerIdx++;
        }
      }
    }
  }

  static Future<void> scheduleTakbeerat(PrayerTimes times) async {
    final prefs = await SharedPreferences.getInstance();
    int intervalMins = prefs.getInt('takbeerat_interval_hours') ?? 60;
    if (intervalMins < 2) intervalMins = 2; // enforce minimum to prevent audio overlap
    final offsetMins = prefs.getInt('takbeerat_offset') ?? 0;
    final off = PrayerService().hijriOffset;
    final hijriNow = PrayerService.getHijriWithOffset(off);

    if (hijriNow.hMonth == 12 && hijriNow.hDay >= 1 && hijriNow.hDay <= 10) {
      final DateTime now = DateTime.now();
      DateTime slotTime = now.add(const Duration(seconds: 2));
      if (offsetMins > 0) slotTime = slotTime.add(Duration(minutes: offsetMins));

      await _scheduleNative(9000, "تكبيرات عشر ذي الحجّة", "الله أكبر الله أكبر الله أكبر، لا إله إلا الله، الله أكبر الله أكبر ولله الحمد", slotTime.hour, slotTime.minute, "eid_takbeerat", payload: "home", year: slotTime.year, month: slotTime.month, day: slotTime.day, intervalMinutes: intervalMins);
    }
  }

  static Future<void> scheduleEidFitrTakbeerat(PrayerTimes times) async {
    final prefs = await SharedPreferences.getInstance();
    int intervalMins = prefs.getInt('eid_fitr_takbeer_interval') ?? 15;
    if (intervalMins < 2) intervalMins = 2; // enforce minimum to prevent audio overlap
    final off = PrayerService().hijriOffset;
    final hijriNow = PrayerService.getHijriWithOffset(off);

    if ((hijriNow.hMonth == 9 && (hijriNow.hDay == 29 || hijriNow.hDay == 30)) || (hijriNow.hMonth == 10 && hijriNow.hDay == 1)) {
      final DateTime now = DateTime.now();
      DateTime slotTime = now.add(const Duration(seconds: 2));
      await _scheduleNative(9100, "تكبيرات العيد", "الله أكبر الله أكبر الله أكبر، لا إله إلا الله، الله أكبر الله أكبر ولله الحمد", slotTime.hour, slotTime.minute, "eid_takbeerat", payload: "home", year: slotTime.year, month: slotTime.month, day: slotTime.day, intervalMinutes: intervalMins);
    }
  }

  static Future<void> scheduleSalawatReminders(int intervalMinutes, List<int> days) async {
    final List<int> cancelIds = [950, ...List.generate(500, (i) => 8000 + i)];
    await _platform.invokeMethod('cancelAlarms', {'ids': cancelIds});
    if (intervalMinutes <= 0 || days.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime targetDate = now.add(const Duration(seconds: 5));

    bool isAllowedToday = days.contains(now.weekday);
    if (!isAllowedToday) {
      int daysUntilNext = 1;
      while (!days.contains(((now.weekday + daysUntilNext - 1) % 7) + 1)) {
        daysUntilNext++;
      }
      targetDate = DateTime(now.year, now.month, now.day, 6, 0).add(Duration(days: daysUntilNext));
    }

    final prefs = await SharedPreferences.getInstance();
    final soundName = prefs.getString('flutter.salawat_periodic_sound') ?? 'saly_3ala_mo7amad';

    await _scheduleNative(
      950,
      'الصلاة على النبي ﷺ',
      'اللهم صلِّ وسلم على نبينا محمد',
      targetDate.hour,
      targetDate.minute,
      soundName,
      payload: 'salawat',
      year: targetDate.year,
      month: targetDate.month,
      day: targetDate.day,
      intervalMinutes: intervalMinutes,
      allowedDays: days.join(','),
      customSoundName: soundName,
    );
  }

  static Future<void> scheduleEidAlert(int id, String title, String body, DateTime time, {String sound = 'default'}) async {
    await _scheduleNative(id, title, body, time.hour, time.minute, sound, year: time.year, month: time.month, day: time.day);
  }

  static Future<void> scheduleRamadanAlert(int id, String title, String body, DateTime time, {String sound = 'default', String? customSoundName}) async {
    await _scheduleNative(id, title, body, time.hour, time.minute, sound, payload: 'fasting', year: time.year, month: time.month, day: time.day, customSoundName: customSoundName);
  }

  static Future<void> scheduleArafahForDate(PrayerTimes times, DateTime now, int indexOffset) async {
    final prefs = await SharedPreferences.getInstance();
    final suhoorMins = prefs.getInt('suhoor_minutes_before') ?? 60;
    final iftarMins = prefs.getInt('iftar_minutes_before') ?? 30;

    final suhoorTime = times.fajr.subtract(Duration(minutes: suhoorMins));
    final iftarTime = times.maghrib.subtract(Duration(minutes: iftarMins));
    // Use IDs 410+i and 400+i to override regular suhoor/iftar
    if (suhoorTime.isAfter(now)) await scheduleRamadanAlert(410 + indexOffset, "سحور يوم عرفة", "باقي $suhoorMins دقيقة على الفجر — تذكير بالسحور", suhoorTime, customSoundName: "time_suhoor");
    if (iftarTime.isAfter(now)) await scheduleRamadanAlert(400 + indexOffset, "إفطار يوم عرفة", "باقي $iftarMins دقيقة على المغرب — تقبل الله صيامكم", iftarTime, customSoundName: "pre_iftar");
  }

  static Future<void> scheduleArafah(PrayerTimes times) async {
    await scheduleArafahForDate(times, DateTime.now(), 0);
  }

  static Future<void> _scheduleNative(int id, String title, String body, int hour, int minute, String soundName, {String? payload, int year = -1, int month = -1, int day = -1, int intervalMinutes = 0, String? customSoundName, String? allowedDays}) async {
    try {
      String? audioPath;
      if (soundName != 'silent_notif') {
        final dir = await getApplicationSupportDirectory();
        final file = File("${dir.path}/adhans/$soundName.mp3");
        if (await file.exists()) audioPath = file.path;
      }
      final Map<String, dynamic> alarmData = {
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'sound': soundName,
        'audioPath': audioPath,
        'payload': payload,
        'year': year,
        'month': month,
        'day': day,
        'intervalMinutes': intervalMinutes,
        if (customSoundName != null) 'custom_sound_name': customSoundName,
        if (allowedDays != null) 'allowed_days': allowedDays,
      };
      if (_isBatching) {
        _batchAlarms.add(alarmData);
      } else {
        await _platform.invokeMethod('scheduleAlarm', alarmData);
      }
    } catch (_) {}
  }

  static Future<void> schedulePrayerNotifications(PrayerTimes times, {bool isUserAction = false}) async => scheduleAll(times, isUserAction: isUserAction);
}
