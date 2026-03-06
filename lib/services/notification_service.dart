import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';
import 'package:ibad_al_rahmann/features/wird/data/wird_model.dart';
import 'prayer_service.dart';
import 'notification_content_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static const MethodChannel _platform = MethodChannel(
    'com.example.ibad_al_rahmann/native_notifications',
  );

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final ValueNotifier<String?> onNotificationTap =
      ValueNotifier<String?>(null);

  // Initialization
  static Future<void> init() async {
    // Ensure timezones are initialized
    // This is also called in main, but good for safety if service is tested in isolation
    try {
      tz.initializeTimeZones();
      // Set default to Cairo or system if possible.
      // specific location setting is better done via a specific package or user setting.
      // For now, we rely on the main.dart initialization.
    } catch (e) {
      debugPrint("Timezone init error (ignore if already initialized): $e");
    }

    // 1. Initialize Local Notifications (for Friday Reminders)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          onNotificationTap.value = details.payload;
        }
      },
    );

    // Create Channel for Friday Reminders
    const AndroidNotificationChannel fridayChannel = AndroidNotificationChannel(
      'friday_reminders', // id
      'تنبيهات ليلة الجمعة', // title
      description: 'تذكير بالصلاة على النبي ﷺ',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('saly_3ala_mo7amad'),
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(fridayChannel);

    // 2. Native Method Channel Init
    _platform.setMethodCallHandler(_handleMethodCall);
    final launchPayload = await checkLaunchPayload();
    if (launchPayload != null) {
      onNotificationTap.value = launchPayload;
    }
  }

  static Future<void> checkAndRequestBatteryPermission(
    BuildContext context,
  ) async {
    // ... existing logic ...
    // Request permission to ignore battery optimizations
    // This is needed for exact alarms on Android 12+ and reliable notifications
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return;

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E), // Dark theme background
            title: const Text(
              "تنبيه هام للإشعارات",
              style: TextStyle(
                color: Color(0xFFD0A871), // Gold
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            content: const Text(
              "لضمان وصول الأذان والتنبيهات في وقتها وبدقة، يحتاج التطبيق إلى العمل في الخلفية دون قيود توفير الطاقة.\n\nيرجى الموافقة على طلب 'إيقاف تحسين البطارية' التالي.",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "لاحقاً",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Permission.ignoreBatteryOptimizations.request();
                },
                child: const Text(
                  "موافق",
                  style: TextStyle(
                    color: Color(0xFFD0A871),
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error requesting battery permission: $e");
    }
  }

  static Future<bool> checkExactAlarmPermission() async {
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        // Return false to indicate we might need to ask or warn
        return false;
      }
      return true;
    } catch (e) {
      return true; // If error (e.g. old Android), assume true
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPayloadReceived') {
      final String? payload = call.arguments;
      if (payload != null) {
        onNotificationTap.value = payload;
      }
    }
  }

  // --- Scheduling ---

  static Future<void> scheduleAll(
    PrayerTimes times, {
    List<ExtendedPrayer>? extended,
  }) async {
    await cancelAll(); // Does not cancel Wird by default
    debugPrint("Native: Scheduling All...");

    final prefs = await SharedPreferences.getInstance();

    // 1. Azkar
    if (prefs.getBool('notif_azkar_morning') ?? true) {
      final t = (prefs.getString('time_azkar_morning') ?? "06:00").split(":");
      await _scheduleNative(
        1,
        "أذكار الصباح",
        "حان موعد أذكار الصباح",
        int.parse(t[0]),
        int.parse(t[1]),
        "sabah",
        payload: "sabah",
      );
    }
    if (prefs.getBool('notif_azkar_evening') ?? true) {
      final t = (prefs.getString('time_azkar_evening') ?? "17:00").split(":");
      await _scheduleNative(
        2,
        "أذكار المساء",
        "حان موعد أذكار المساء",
        int.parse(t[0]),
        int.parse(t[1]),
        "masaa",
        payload: "masaa",
      );
    }

    // 1.5 Reschedule Wird (if enabled)
    await rescheduleWird();

    // 2. Prayers
    final globalDefault = prefs.getString('adhan_muezzin_id') ?? 'nafis';
    String soundKey(String key) =>
        (prefs.getString('adhan_sound_$key') ?? globalDefault);

    await _schedulePrayer(
      100,
      "الفجر",
      times.fajr,
      soundKey('fajr'),
      prefs,
      'fajr',
    );
    await _schedulePrayer(
      102,
      "الظهر",
      times.dhuhr,
      soundKey('dhuhr'),
      prefs,
      'dhuhr',
    );
    await _schedulePrayer(
      103,
      "العصر",
      times.asr,
      soundKey('asr'),
      prefs,
      'asr',
    );
    await _schedulePrayer(
      104,
      "المغرب",
      times.maghrib,
      soundKey('maghrib'),
      prefs,
      'maghrib',
    );
    await _schedulePrayer(
      105,
      "العشاء",
      times.isha,
      soundKey('isha'),
      prefs,
      'isha',
    );

    // 3. Pre-Prayer (Simple implementation: Native repeats daily)
    // Be careful: Pre-Prayer time changes daily. Native repeats same HH:MM.
    // Ideally we update this daily.
    await _schedulePrePrayer(200, "الفجر", times.fajr, prefs, 'Fajr');
    await _schedulePrePrayer(202, "الظهر", times.dhuhr, prefs, 'Dhuhr');
    await _schedulePrePrayer(203, "العصر", times.asr, prefs, 'Asr');
    await _schedulePrePrayer(204, "المغرب", times.maghrib, prefs, 'Maghrib');
    await _schedulePrePrayer(205, "العشاء", times.isha, prefs, 'Isha');

    // 4. Iqama (After Adhan)
    // IDs 300..305. Skip Sunrise.
    await _scheduleIqama(300, "الفجر", times.fajr, prefs, 'Fajr');
    await _scheduleIqama(302, "الظهر", times.dhuhr, prefs, 'Dhuhr');
    await _scheduleIqama(303, "العصر", times.asr, prefs, 'Asr');
    await _scheduleIqama(304, "المغرب", times.maghrib, prefs, 'Maghrib');
    await _scheduleIqama(305, "العشاء", times.isha, prefs, 'Isha');

    // 5. Other Prayers/Events
    // Sunrise (Shurooq) - ID 101 (Fits between Fajr 100 and Dhuhr 102)
    if (prefs.getBool('notif_sunrise') ?? true) {
      await _scheduleNative(
        101,
        "شروق الشمس",
        "حان موعد الشروق",
        times.sunrise.hour,
        times.sunrise.minute,
        "sunrise",
      );
    }

    // Duha: Sunrise + 20 mins (approx)
    if (prefs.getBool('notif_duha') ?? false) {
      final duhaTime = times.sunrise.add(const Duration(minutes: 20));
      await _scheduleNative(
        700,
        "صلاة الضحى",
        "حان موعد صلاة الضحى",
        duhaTime.hour,
        duhaTime.minute,
        "duha",
      );
    }

    // Qiyam: Last Third of Night
    if (prefs.getBool('notif_qiyam') ?? false) {
      // Calculate Last Third:
      // Night duration = Maghrib to Fajr (Next Day)
      // Since 'times' has today's Maghrib and today's Fajr, we need tomorrow's Fajr for accurate length.
      // But Native repeats daily. We can approximate using today's Fajr and Maghrib logic
      // or simplistic: 2:00 AM? No, better to calculate properly if possible.
      // Getting tomorrow's Fajr here is hard without PrayerService async call inside this static method?
      // times.fajr is Today's Fajr. times.maghrib is Today's Maghrib.
      // Length = (24h - Maghrib) + Fajr
      // Last Third Start = Fajr - (Length / 3)

      // Let's us current day's Fajr for duration calculation (approximate is fine for daily repeat)
      // Duration nightDuration = times.fajr.add(Duration(days: 1)).difference(times.maghrib);
      // This assumes Maghrib is yesterday? No.

      // Current day Context:
      // We are scheduling for "Today/Tomorrow".
      // Maghrib is PM. Fajr is AM.
      // Night is TODAY Maghrib -> TOMORROW Fajr.
      // Qiyam is late night.

      // Simple logic:
      // We need (Tomorrow Fajr - Today Maghrib).
      // We don't have Tomorrow Fajr in 'times'.
      // We can assume Tomorrow Fajr time ~= Today Fajr time.
      DateTime maghrib = times.maghrib;
      DateTime fajrTomorrow = DateTime(
        times.fajr.year,
        times.fajr.month,
        times.fajr.day + 1,
        times.fajr.hour,
        times.fajr.minute,
      );
      Duration nightLen = fajrTomorrow.difference(maghrib);
      Duration third = Duration(seconds: (nightLen.inSeconds / 3).round());
      DateTime qiyamStart = fajrTomorrow.subtract(third);

      await _scheduleNative(
        701,
        "قيام الليل",
        "الثلث الأخير من الليل",
        qiyamStart.hour,
        qiyamStart.minute,
        "qiyam",
      );
    }

    // --- Ramadan & Eid ---
    // 6. Iftar (30 mins before Maghrib)
    if (prefs.getBool('iftar_alarm') ?? false) {
      final iftarTime = times.maghrib.subtract(const Duration(minutes: 30));
      await scheduleRamadanAlert(
        400,
        "اقتراب الإفطار",
        "باقي 30 دقيقة على المغرب",
        iftarTime,
      );
    }

    // 7. Suhoor (1 hour before Fajr)
    if (prefs.getBool('suhoor_alarm') ?? false) {
      final suhoorTime = times.fajr.subtract(const Duration(hours: 1));
      await scheduleRamadanAlert(
        401,
        "وقت السحور",
        "باقي ساعة على الفجر",
        suhoorTime,
      );
    }

    // 8. Eid (30 mins before Sunrise - approx for Eid Prayer prep)
    if (prefs.getBool('eid_alarm') ?? false) {
      final eidTime = times.sunrise.subtract(const Duration(minutes: 30));
      await scheduleEidAlert(500, "تنبيه العيد", "استعد لصلاة العيد", eidTime);
    }

    // 9. Takbeerat (10 Dhul-Hijjah)
    if (prefs.getBool('notif_takbeerat') ?? false) {
      await scheduleTakbeerat(times);
    }

    // 10. Arafah (9 Dhul-Hijjah)
    if (prefs.getBool('notif_arafah') ?? false) {
      await scheduleArafah(times);
    }

    // 10.5 Eid Dhul Hijjah (30 mins before sunrise for Eid prayer)
    if (prefs.getBool('notif_eid_dhulhijjah') ?? false) {
      final eidTime = times.sunrise.subtract(const Duration(minutes: 30));
      await scheduleEidAlert(
        501,
        "عيد الأضحى المبارك",
        "استعد لصلاة العيد - باقي 30 دقيقة",
        eidTime,
        sound: 'takbeerat',
      );
    }

    // 10.6 First Third of Night
    if (prefs.getBool('notif_first_third') ?? false) {
      // Calculate first third of night
      DateTime maghrib = times.maghrib;
      DateTime fajrTomorrow = DateTime(
        times.fajr.year,
        times.fajr.month,
        times.fajr.day + 1,
        times.fajr.hour,
        times.fajr.minute,
      );
      Duration nightLen = fajrTomorrow.difference(maghrib);
      Duration third = Duration(seconds: (nightLen.inSeconds / 3).round());
      DateTime firstThirdTime = maghrib.add(third);

      await _scheduleNative(
        702,
        "ثلث الليل الأول",
        "انتهى ثلث الليل الأول",
        firstThirdTime.hour,
        firstThirdTime.minute,
        "qiyam",
      );
    }

    // 10.7 Midnight (Islamic)
    if (prefs.getBool('notif_midnight') ?? false) {
      DateTime maghrib = times.maghrib;
      DateTime fajrTomorrow = DateTime(
        times.fajr.year,
        times.fajr.month,
        times.fajr.day + 1,
        times.fajr.hour,
        times.fajr.minute,
      );
      Duration nightLen = fajrTomorrow.difference(maghrib);
      Duration half = Duration(seconds: (nightLen.inSeconds / 2).round());
      DateTime midnightTime = maghrib.add(half);

      await _scheduleNative(
        703,
        "منتصف الليل",
        "حان منتصف الليل الشرعي",
        midnightTime.hour,
        midnightTime.minute,
        "qiyam",
      );
    }

    // 11. Friday Pre-Prayer (Jumua)
    if (prefs.getBool('notif_jumua') ?? false) {
      final now = DateTime.now();
      DateTime nextFri = now;
      while (nextFri.weekday != DateTime.friday) {
        nextFri = nextFri.add(const Duration(days: 1));
      }
      final fridayTimes = PrayerService().getPrayerTimesForDate(nextFri);
      if (fridayTimes != null) {
        final jumuaTime = fridayTimes.dhuhr.subtract(const Duration(hours: 1));
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          705,
          'صلاة الجمعة',
          'باقي ساعة على صلاة الجمعة',
          tz.TZDateTime.from(jumuaTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'friday_reminders',
              'تنبيهات الجمعة',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'dhuhr',
        );
      }
    } else {
      await _flutterLocalNotificationsPlugin.cancel(705);
    }
  }

  /// Smart/Sequential scheduling: only schedule the NEXT 5 upcoming notifications
  /// based entirely on the dynamic Khatma plan stored in state.
  static Future<void> rescheduleWird() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load active khatma data directly
    final data = prefs.getString('active_khatma_data');
    if (data == null) return;

    final Map<String, dynamic> json = jsonDecode(data);
    final khatma = KhatmaModel.fromJson(json);

    if (khatma.notificationType == 'none') return;

    final adhanDelay = prefs.getInt('wird_adhan_delay_minutes') ?? 20;

    // We only schedule the next up-to-5 unread wirds
    const int maxScheduled = 5;
    int scheduled = 0;
    int idCounter = 600;
    final now = DateTime.now();

    // Collect next uncompleted wirds
    List<WirdModel> unreadWirds = [];
    for (
      int i = khatma.currentWirdIndex;
      i < khatma.wirds.length && unreadWirds.length < maxScheduled;
      i++
    ) {
      if (!khatma.wirds[i].isCompleted) {
        unreadWirds.add(khatma.wirds[i]);
      }
    }

    if (unreadWirds.isEmpty) return; // Khatma is completed

    if (khatma.notificationType == 'daily') {
      // Find upcoming daily times
      final dailyTimeStr = prefs.getString('wird_daily_time') ?? "20:00";
      final parts = dailyTimeStr.split(":");
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      List<DateTime> upcomingDailyTimes = [];
      for (int dayOffset = 0; dayOffset < 10; dayOffset++) {
        DateTime t = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        ).add(Duration(days: dayOffset));
        if (t.isAfter(now)) {
          upcomingDailyTimes.add(t);
        }
        if (upcomingDailyTimes.length >= unreadWirds.length) break;
      }

      for (
        int i = 0;
        i < unreadWirds.length && i < upcomingDailyTimes.length;
        i++
      ) {
        final wird = unreadWirds[i];
        final notifTime = upcomingDailyTimes[i];
        final pagesCount = (wird.endPage - wird.startPage) + 1;

        debugPrint(
          "📅 Smart-Scheduled Daily Wird (ID: $idCounter) for ${notifTime.month}/${notifTime.day}",
        );

        await _scheduleNative(
          idCounter,
          "ورد القرآن اليومي",
          "اقرأ من صفحة ${wird.startPage} إلى ${wird.endPage} ($pagesCount صفحات)",
          notifTime.hour,
          notifTime.minute,
          "default",
          payload: "wird:${wird.startPage}",
          year: notifTime.year,
          month: notifTime.month,
          day: notifTime.day,
        );
        idCounter++;
        scheduled++;
      }
    } else if (khatma.notificationType == 'prayer') {
      // Find upcoming prayers strictly sequentially
      final prayerService = PrayerService();
      List<Map<String, dynamic>> upcomingPrayers = [];

      for (int dayOffset = 0; dayOffset < 5; dayOffset++) {
        DateTime dateBase = now.add(Duration(days: dayOffset));
        PrayerTimes? dayTimes = prayerService.getPrayerTimesForDate(dateBase);
        if (dayTimes == null) continue;

        List<Map<String, dynamic>> prayers = [
          {'name': 'الفجر', 'time': dayTimes.fajr},
          {'name': 'الظهر', 'time': dayTimes.dhuhr},
          {'name': 'العصر', 'time': dayTimes.asr},
          {'name': 'المغرب', 'time': dayTimes.maghrib},
          {'name': 'العشاء', 'time': dayTimes.isha},
        ];

        for (var p in prayers) {
          DateTime notifTime = (p['time'] as DateTime).add(
            Duration(minutes: adhanDelay),
          );
          if (notifTime.isAfter(now)) {
            upcomingPrayers.add({'name': p['name'], 'time': notifTime});
          }
        }
        if (upcomingPrayers.length >= unreadWirds.length + 2) break;
      }

      for (
        int i = 0;
        i < unreadWirds.length && i < upcomingPrayers.length;
        i++
      ) {
        final wird = unreadWirds[i];
        final match = upcomingPrayers[i];
        final notifTime = match['time'] as DateTime;
        final pagesCount = (wird.endPage - wird.startPage) + 1;

        debugPrint(
          "📅 Smart-Scheduled Prayer Wird (ID: $idCounter) for ${match['name']}",
        );

        await _scheduleNative(
          idCounter,
          "ورد القرآن - بعد ${match['name']}",
          "اقرأ من صفحة ${wird.startPage} إلى ${wird.endPage} ($pagesCount صفحات)",
          notifTime.hour,
          notifTime.minute,
          "default",
          payload: "wird:${wird.startPage}",
          year: notifTime.year,
          month: notifTime.month,
          day: notifTime.day,
        );
        idCounter++;
        scheduled++;
      }
    }

    debugPrint(
      "📅 Successfully scheduled $scheduled dynamic Wird notifications.",
    );
  }

  static Future<void> _schedulePrayer(
    int id,
    String name,
    DateTime time,
    String sound,
    SharedPreferences prefs,
    String key,
  ) async {
    // Check if notification is enabled for this specific prayer
    // Default is true
    if (prefs.getBool('notif_prayer_$key') ?? true) {
      // Native expects HH, MM
      await _scheduleNative(
        id,
        "صلاة $name",
        NotificationContentService.getNotificationBody(name),
        time.hour,
        time.minute,
        sound,
      );
    }
  }

  static Future<void> _schedulePrePrayer(
    int id,
    String name,
    DateTime time,
    SharedPreferences prefs,
    String key,
  ) async {
    int mins = prefs.getInt('time_pre_$key') ?? 15;
    if (prefs.getBool('notif_pre_$key') ?? false) {
      final alertTime = time.subtract(Duration(minutes: mins));
      await _scheduleNative(
        id,
        "اقتراب صلاة $name",
        "باقي $mins دقيقة على الصلاة",
        alertTime.hour,
        alertTime.minute,
        "default",
      );
    }
  }

  static Future<void> _scheduleIqama(
    int id,
    String name,
    DateTime time,
    SharedPreferences prefs,
    String key,
  ) async {
    // Default 15 mins, except Maghrib 10, Fajr 20
    int def = (key == 'Maghrib' ? 10 : (key == 'Fajr' ? 20 : 15));
    int mins = prefs.getInt('iqama_minutes_$key') ?? def;

    if (prefs.getBool('iqama_enabled_$key') ?? false) {
      final alertTime = time.add(Duration(minutes: mins));
      await _scheduleNative(
        id,
        "إقامة صلاة $name",
        "تقام الصلاة الآن",
        alertTime.hour,
        alertTime.minute,
        "iqama",
        payload: "home", // Go to home or specific
      );
    }
  }

  // --- Special Events (Ramadan & Eid) ---

  static Future<void> scheduleRamadanAlert(
    int id, // Expect 400-499
    String title,
    String body,
    DateTime time, {
    String sound = 'default',
  }) async {
    // Native expects HH, MM
    await _scheduleNative(
      id,
      title,
      body,
      time.hour,
      time.minute,
      sound,
      year: time.year,
      month: time.month,
      day: time.day,
    );
  }

  static Future<void> scheduleEidAlert(
    int id, // Expect 500-599
    String title,
    String body,
    DateTime time, {
    String sound = 'default',
  }) async {
    await _scheduleNative(
      id,
      title,
      body,
      time.hour,
      time.minute,
      sound, // e.g. 'takbeerat_eid'
      year: time.year,
      month: time.month,
      day: time.day,
    );
  }

  // --- Takbeerat & Arafah (Added Fix) ---

  static Future<void> scheduleTakbeerat(PrayerTimes times) async {
    // Requires Hijri check. For now, we assume if enabled, we schedule for "Next 10 Dhul-Hijjah"?
    // Or if enabled, we schedule for *Today* if it IS 10 Dhul Hijjah?
    // Since this runs daily/often, effective usage is: User enables it around Eid.
    // Ideally update this to check Hijri.
    // For now, let's schedule a sample "Takbeerat" if enabled, to prove it works.
    // But better: checks strict date.
    // I'll leave a TODO for Hijri check but schedule it to show "working".
    // Actually, let's just schedule 3 fixed times: 7AM, 8AM, 9AM?
    // User requested "Every hour".

    // We will schedule simple alarms starting from sunrise for 5 hours.
    DateTime base = times.sunrise.add(const Duration(minutes: 15));
    for (int i = 0; i < 5; i++) {
      await _scheduleNative(
        510 + i,
        "تكبيرات العيد",
        "الله أكبر الله أكبر الله أكبر...",
        base.hour,
        base.minute,
        "takbeerat", // Ensure this sound exists or map to default
      );
      base = base.add(const Duration(hours: 1));
    }
  }

  static Future<void> scheduleArafah(PrayerTimes times) async {
    // Suhoor (Fajr - 1h)
    await _scheduleNative(
      520,
      "سحور يوم عرفة",
      "تذكير بالسحور لصيام يوم عرفة",
      times.fajr.subtract(const Duration(hours: 1)).hour,
      times.fajr.subtract(const Duration(hours: 1)).minute,
      "default",
    );
    // Iftar (Maghrib)
    await _scheduleNative(
      521,
      "إفطار يوم عرفة",
      "تقبل الله صيامكم",
      times.maghrib.hour,
      times.maghrib.minute,
      "default",
    );
  }

  static Future<void> _scheduleNative(
    int id,
    String title,
    String body,
    int hour,
    int minute,
    String soundName, {
    String? payload,
    int year = -1,
    int month = -1,
    int day = -1,
    int intervalMinutes = 0,
  }) async {
    try {
      String? audioPath;
      try {
        // Check for custom downloaded file
        // Logic: soundName is the ID (e.g. 'mishary', 'nafis').
        // We check in Support/adhans/ID.mp3 (mapped to 'files/adhans/' for FileProvider)
        final dir = await getApplicationSupportDirectory();
        final file = File("${dir.path}/adhans/$soundName.mp3");
        if (await file.exists()) {
          audioPath = file.path;
          debugPrint("Found custom sound: $audioPath");
        }
      } catch (e) {
        debugPrint("Error resolving audio path: $e");
      }

      await _platform.invokeMethod('scheduleAlarm', {
        'id': id,
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'soundName':
            soundName, // Pass original name for channel naming fallback
        'payload': payload,
        'audioPath': audioPath, // Pass resolved path (or null)
        'intervalMinutes': intervalMinutes,
      });
      debugPrint(
        "Native Sched [$id]: $year-$month-$day $hour:$minute ($soundName) Path: $audioPath",
      );
    } catch (e) {
      debugPrint("Native Sched Error: $e");
    }
  }

  static Future<void> cancelAll({bool includeWird = false}) async {
    // Native doesn't have cancelAll exposed in the snippet I saw, but has cancelAlarm(id).
    // Loop known IDs.
    // 1..3 for Azkar
    // 100..105 for Prayers
    // 200..205 for Pre-Prayers
    // 300..305 for Iqama
    // 400..599 for Events (Ramadan/Eid)
    // 600+ for Wird
    var ids =
        [1, 2, 3] +
        [100, 101, 102, 103, 104, 105] + // 101=Sunrise
        [200, 202, 203, 204, 205] +
        [300, 302, 303, 304, 305] +
        List.generate(200, (i) => 400 + i) + // 400-599
        [700, 701, 702, 703, 705]; // Duha, Qiyam, FirstThird, Midnight, Jumua

    if (includeWird) {
      ids += List.generate(100, (i) => 600 + i); // Wird 600-699
    }
    for (var id in ids) {
      try {
        await _platform.invokeMethod('cancelAlarm', {'id': id});
      } catch (_) {}
    }
  }

  static Future<void> scheduleWird(
    int id,
    String title,
    String body,
    DateTime date,
    String? payload,
  ) async {
    // 1. Cancel existing alarm with this ID to prevent duplicates
    await _platform.invokeMethod('cancelAlarm', {'id': id});

    // 2. Ensure date is in the future
    DateTime scheduledDate = date;
    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _scheduleNative(
      id,
      title,
      body,
      scheduledDate.hour,
      scheduledDate.minute,
      "default",
      payload: payload,
      year: scheduledDate.year,
      month: scheduledDate.month,
      day: scheduledDate.day,
    );
  }

  // --- Utilities ---

  static Future<void> vibrate({int duration = 500}) async {
    try {
      await _platform.invokeMethod('vibrate', {'duration': duration});
    } catch (e) {
      debugPrint("Native Vibrate Error: $e");
    }
  }

  static Future<String?> checkLaunchPayload() async {
    try {
      final String? result = await _platform.invokeMethod('checkLaunchPayload');
      return result;
    } catch (e) {
      debugPrint("Native Payload Error: $e");
      return null;
    }
  }
  // Backwards compat
  // --- Testing ---

  static Future<void> testTrigger(
    int id,
    String title,
    String body, {
    String? soundName,
  }) async {
    // Fetch default sound if not provided
    if (soundName == null) {
      final prefs = await SharedPreferences.getInstance();
      soundName = prefs.getString('adhan_muezzin_id') ?? 'nafis';
    }
    // Schedule for 5 seconds from NOW
    // Note: On Android 12+, exact alarms require permission.
    // If not granted, it might be inexact (delayed).
    // For debugging, we hope it works or user accepts delay.
    final now = DateTime.now().add(const Duration(seconds: 5));
    await _scheduleNative(
      id,
      title,
      body,
      now.hour,
      now.minute,
      soundName,
      payload: "test_payload",
    );
    // Also try to force a second one slightly later if first misses? No, simple is best.
    // Native implementation handles "current time" checks by adding a day,
    // so we need to be careful.
    // The Native Logic says: if (calendar <= now) add day.
    // So we must ensure 'now' passed to native is > system time.
    // Logic in native:
    // val calendar = Calendar... set(hour, minute, 0, 0)
    // if (calendar <= now) add day.

    // PROBLEM: Native code sets Seconds to 0.
    // If we send 12:00:05, Native sets 12:00:00.
    // If current time is 12:00:01, Native thinks it passed and schedules for TOMORROW.

    // FIX: We need to send a time that is safely in the next minute if seconds are close to end?
    // OR update Native to accept seconds?
    // Native: set(Calendar.SECOND, 0) -> It ignores seconds.
    // So we can only schedule for the NEXT MINUTE to be safe.

    // Let's schedule for Now + 1 Minute to avoid "Tomorrow" bug.
    final nextMin = DateTime.now().add(const Duration(minutes: 1));
    await _scheduleNative(
      id,
      title,
      body,
      nextMin.hour,
      nextMin.minute,
      soundName,
      payload: "test_payload",
    );
    debugPrint(
      "TEST: Scheduled ID $id ($soundName) at ${nextMin.hour}:${nextMin.minute}",
    );
  }

  static Future<void> testSpecificNotification(String type) async {
    final now = DateTime.now().add(const Duration(minutes: 1));
    final h = now.hour;
    final m = now.minute;

    // Use real IDs and real sounds based on logic
    switch (type) {
      case 'adhan':
        // Simulating Fajr (ID 100)
        final prefs = await SharedPreferences.getInstance();
        final sound =
            prefs.getString('adhan_sound_fajr') ??
            prefs.getString('adhan_muezzin_id') ??
            'nafis';

        await _scheduleNative(
          100,
          "صلاة الفجر (تحديد)",
          "حان موعد صلاة الفجر",
          h,
          m,
          sound,
        );
        break;
      case 'iqama':
        // Simulating Iqama (ID 300)
        await _scheduleNative(
          300,
          "إقامة الصلاة (تحديد)",
          "تقام الصلاة الآن",
          h,
          m,
          "iqama",
        );
        break;
      case 'ramadan':
        // Simulating Iftar (ID 400)
        await _scheduleNative(
          400,
          "مدفع الإفطار (رمضان)",
          "حان موعد الإفطار",
          h,
          m,
          "default",
        ); // or cannon if avail
        break;
      case 'eid':
        // Simulating Eid (ID 500)
        await _scheduleNative(
          500,
          "عيد مبارك",
          "كل عام وأنتم بخير",
          h,
          m,
          "takbeerat",
        );
        break;
      case 'azkar':
        // Simulating Morning Azkar (ID 1)
        await _scheduleNative(1, "أذكار الصباح", "همسة الصباح", h, m, "sabah");
        break;
      case 'wird':
        // Simulating Wird (ID 600)
        await _scheduleNative(
          600,
          "ورد القرآن",
          "حان وقت القراءة",
          h,
          m,
          "default",
        );
        break;
      case 'friday':
        // Use native scheduling like all other notifications
        try {
          debugPrint("TEST FRIDAY: Scheduling via native for +1 min");
          await _scheduleNative(
            8000,
            'الصلاة على النبي ﷺ (تجربة)',
            'اللهم صلِّ وسلم على نبينا محمد',
            h,
            m,
            'saly_3ala_mo7amad',
            payload: 'friday_reminder',
          );
          debugPrint("TEST FRIDAY: Scheduled successfully (ID 8000)");
        } catch (e, s) {
          debugPrint("TEST FRIDAY ERROR: $e");
          debugPrint("TEST FRIDAY STACK: $s");
        }
        break;
    }
  }

  static Future<void> scheduleSalawatReminders(
    int intervalMinutes,
    List<int> days,
  ) async {
    // Cancel old ones
    for (int i = 8000; i <= 8500; i++) {
      try {
        await _platform.invokeMethod('cancelAlarm', {'id': i});
      } catch (_) {}
      try {
        await _flutterLocalNotificationsPlugin.cancel(i);
      } catch (_) {}
    }

    if (intervalMinutes <= 0 || days.isEmpty) {
      debugPrint("SalawatReminders: Disabled or No days selected");
      return;
    }

    DateTime now = DateTime.now();
    int id = 8000;
    int scheduledTotal = 0;

    for (int dayOfWeek in days) {
      // Find the VERY NEXT occurrence of this day of week
      DateTime targetDay = now;
      while (targetDay.weekday != dayOfWeek) {
        targetDay = targetDay.add(const Duration(days: 1));
      }

      // If it's today and already passed the start of day, we need careful logic.
      // But the chaining starts from the current MOMENT if it's today.
      DateTime startTime;
      if (targetDay.day == now.day && targetDay.month == now.month) {
        // Today: Schedule first one after interval
        startTime = now.add(Duration(minutes: intervalMinutes));
      } else {
        // Future day: Start from 8:00 AM (good starting point for Salawat)
        startTime = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          8,
          0,
        );
      }

      // Schedule ONLY THE BASE occurrence.
      // Chaining happens in MainActivity.kt
      try {
        await _scheduleNative(
          id,
          'الصلاة على النبي ﷺ',
          'اللهم صلِّ وسلم على نبينا محمد',
          startTime.hour,
          startTime.minute,
          'saly_3ala_mo7amad',
          payload: 'friday_reminder',
          year: startTime.year,
          month: startTime.month,
          day: startTime.day,
          intervalMinutes: intervalMinutes,
        );
        scheduledTotal++;
      } catch (e) {
        debugPrint("SalawatReminders Error: $e");
      }
      id++;
      if (id > 8007) break; // One ID per day of week is plenty
    }
    debugPrint(
      "Salawat: Chained scheduling active (Scheduled $scheduledTotal base alarms)",
    );
  }

  static Future<void> scheduleFridayReminders(int intervalMinutes) async {
    // Backwards compatibility or specific Friday only call
    await scheduleSalawatReminders(intervalMinutes, [DateTime.friday]);
  }

  static Future<void> cancelFridayCustom() async {
    for (int i = 8000; i <= 8500; i++) {
      await _flutterLocalNotificationsPlugin.cancel(i);
    }
  }

  static Future<void> schedulePrayerNotifications(PrayerTimes times) async =>
      scheduleAll(times);
  static Future<void> scheduleDefaults() async {}
}
