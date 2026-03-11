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
import 'package:hijri/hijri_calendar.dart';

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
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint("Timezone init error (ignore if already initialized): $e");
    }

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

    const AndroidNotificationChannel fridayChannel = AndroidNotificationChannel(
      'friday_reminders',
      'تنبيهات ليلة الجمعة',
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

    _platform.setMethodCallHandler(_handleMethodCall);
    final launchPayload = await checkLaunchPayload();
    if (launchPayload != null) {
      onNotificationTap.value = launchPayload;
    }
  }

  static Future<void> checkAndRequestBatteryPermission(
    BuildContext context,
  ) async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return;

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              "تنبيه هام للإشعارات",
              style: TextStyle(
                color: Color(0xFFD0A871),
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
        return false;
      }
      return true;
    } catch (e) {
      return true;
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

  static Future<void> scheduleAll(
    PrayerTimes times, {
    List<ExtendedPrayer>? extended,
  }) async {
    await cancelAll();
    debugPrint("Native: Scheduling All...");

    final prefs = await SharedPreferences.getInstance();

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

    await rescheduleWird();

    final globalDefault = prefs.getString('adhan_muezzin_id') ?? 'nafis';
    String soundKey(String key) =>
        (prefs.getString('adhan_sound_$key') ?? globalDefault);

    await _schedulePrayer(100, "الفجر", times.fajr, soundKey('fajr'), prefs, 'fajr');
    await _schedulePrayer(102, "الظهر", times.dhuhr, soundKey('dhuhr'), prefs, 'dhuhr');
    await _schedulePrayer(103, "العصر", times.asr, soundKey('asr'), prefs, 'asr');
    await _schedulePrayer(104, "المغرب", times.maghrib, soundKey('maghrib'), prefs, 'maghrib');
    await _schedulePrayer(105, "العشاء", times.isha, soundKey('isha'), prefs, 'isha');

    await _schedulePrePrayer(200, "الفجر", times.fajr, prefs, 'Fajr');
    await _schedulePrePrayer(202, "الظهر", times.dhuhr, prefs, 'Dhuhr');
    await _schedulePrePrayer(203, "العصر", times.asr, prefs, 'Asr');
    await _schedulePrePrayer(204, "المغرب", times.maghrib, prefs, 'Maghrib');
    await _schedulePrePrayer(205, "العشاء", times.isha, prefs, 'Isha');

    await _scheduleIqama(300, "الفجر", times.fajr, prefs, 'Fajr');
    await _scheduleIqama(302, "الظهر", times.dhuhr, prefs, 'Dhuhr');
    await _scheduleIqama(303, "العصر", times.asr, prefs, 'Asr');
    await _scheduleIqama(304, "المغرب", times.maghrib, prefs, 'Maghrib');
    await _scheduleIqama(305, "العشاء", times.isha, prefs, 'Isha');

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

    if (prefs.getBool('notif_duha') ?? false) {
      final duhaTime = times.sunrise.add(const Duration(minutes: 15));
      await _scheduleNative(
        700,
        "صلاة الضحى",
        "حان موعد صلاة الضحى",
        duhaTime.hour,
        duhaTime.minute,
        "duha",
      );
    }

    if (prefs.getBool('notif_qiyam') ?? false) {
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

    if (prefs.getBool('iftar_alarm') ?? false) {
      final iftarTime = times.maghrib.subtract(const Duration(minutes: 30));
      await scheduleRamadanAlert(
        400,
        "اقتراب الإفطار",
        "باقي 30 دقيقة على المغرب",
        iftarTime,
      );
    }

    if (prefs.getBool('suhoor_alarm') ?? false) {
      final suhoorTime = times.fajr.subtract(const Duration(hours: 1));
      await scheduleRamadanAlert(
        401,
        "وقت السحور",
        "باقي ساعة على الفجر",
        suhoorTime,
      );
    }

    final off = PrayerService().hijriOffset;
    final hijriNow = HijriCalendar.fromDate(DateTime.now().add(Duration(days: off)));
    final int hMonth = hijriNow.hMonth;
    final int hDay = hijriNow.hDay;

    if ((prefs.getBool('eid_alarm') ?? false) && hMonth == 10 && hDay == 1) {
      final eidTime = times.sunrise.subtract(const Duration(minutes: 30));
      await scheduleEidAlert(500, "تنبيه العيد", "استعد لصلاة العيد", eidTime);
    }

    if (prefs.getBool('notif_takbeerat') ?? false) {
      await scheduleTakbeerat(times);
    }

    if ((prefs.getBool('notif_arafah') ?? false) && hMonth == 12 && hDay == 9) {
      await scheduleArafah(times);
    }

    if ((prefs.getBool('notif_eid_dhulhijjah') ?? false) && hMonth == 12 && hDay == 10) {
      final eidTime = times.sunrise.subtract(const Duration(minutes: 30));
      await scheduleEidAlert(
        501,
        "عيد الأضحى المبارك",
        "استعد لصلاة العيد - باقي 30 دقيقة",
        eidTime,
        sound: 'takbeerat',
      );
    }

    if (prefs.getBool('notif_first_third') ?? false) {
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
    debugPrint("✅ Notifications Sync Complete.");
  }

  static Future<void> rescheduleWird() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_khatma_data');
    if (data == null) return;

    final Map<String, dynamic> json = jsonDecode(data);
    final khatma = KhatmaModel.fromJson(json);

    if (khatma.notificationType == 'none') return;

    final adhanDelay = prefs.getInt('wird_adhan_delay_minutes') ?? 20;
    const int maxScheduled = 5;
    int idCounter = 6000;
    final now = DateTime.now();

    List<WirdModel> unreadWirds = [];
    for (int i = khatma.currentWirdIndex; i < khatma.wirds.length && unreadWirds.length < maxScheduled; i++) {
      if (!khatma.wirds[i].isCompleted) {
        unreadWirds.add(khatma.wirds[i]);
      }
    }

    if (unreadWirds.isEmpty) return;

    if (khatma.notificationType == 'daily') {
      final dailyTimeStr = prefs.getString('wird_daily_time') ?? "20:00";
      final parts = dailyTimeStr.split(":");
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      List<DateTime> upcomingDailyTimes = [];
      for (int dayOffset = 0; dayOffset < 10; dayOffset++) {
        DateTime t = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: dayOffset));
        if (t.isAfter(now)) {
          upcomingDailyTimes.add(t);
        }
        if (upcomingDailyTimes.length >= unreadWirds.length) break;
      }

      for (int i = 0; i < unreadWirds.length && i < upcomingDailyTimes.length; i++) {
        final wird = unreadWirds[i];
        final notifTime = upcomingDailyTimes[i];
        await _scheduleNative(
          idCounter,
          "ورد القرآن اليومي",
          "اقرأ من صفحة ${wird.startPage} إلى ${wird.endPage}",
          notifTime.hour,
          notifTime.minute,
          "default",
          payload: "wird:${wird.startPage}",
          year: notifTime.year,
          month: notifTime.month,
          day: notifTime.day,
        );
        idCounter++;
      }
    } else if (khatma.notificationType == 'prayer') {
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
          DateTime notifTime = (p['time'] as DateTime).add(Duration(minutes: adhanDelay));
          if (notifTime.isAfter(now)) {
            upcomingPrayers.add({'name': p['name'], 'time': notifTime});
          }
        }
        if (upcomingPrayers.length >= unreadWirds.length + 2) break;
      }

      for (int i = 0; i < unreadWirds.length && i < upcomingPrayers.length; i++) {
        final wird = unreadWirds[i];
        final match = upcomingPrayers[i];
        final notifTime = match['time'] as DateTime;
        await _scheduleNative(
          idCounter,
          "ورد القرآن - بعد ${match['name']}",
          "اقرأ من صفحة ${wird.startPage} إلى ${wird.endPage}",
          notifTime.hour,
          notifTime.minute,
          "default",
          payload: "wird:${wird.startPage}",
          year: notifTime.year,
          month: notifTime.month,
          day: notifTime.day,
        );
        idCounter++;
      }
    }
  }

  static Future<void> _schedulePrayer(
    int id,
    String name,
    DateTime time,
    String sound,
    SharedPreferences prefs,
    String key,
  ) async {
    if (prefs.getBool('notif_prayer_$key') ?? true) {
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
    DateTime todayTime,
    SharedPreferences prefs,
    String key,
  ) async {
    final bool isEnabled = prefs.getBool('notif_pre_$key') ?? false;
    if (!isEnabled) {
      for (int i = 0; i < 7; i++) {
        await _platform.invokeMethod('cancelAlarm', {'id': id + (i * 1000)});
      }
      return;
    }

    final int preMins = prefs.getInt('time_pre_$key') ?? 15;
    final prayerService = PrayerService();

    for (int i = 0; i < 7; i++) {
      final DateTime targetDate = DateTime.now().add(Duration(days: i));
      final PrayerTimes? dayTimes = prayerService.getPrayerTimesForDate(targetDate);
      if (dayTimes == null) continue;

      DateTime prayerTime;
      switch (key.toLowerCase()) {
        case 'fajr': prayerTime = dayTimes.fajr; break;
        case 'dhuhr': prayerTime = dayTimes.dhuhr; break;
        case 'asr': prayerTime = dayTimes.asr; break;
        case 'maghrib': prayerTime = dayTimes.maghrib; break;
        case 'isha': prayerTime = dayTimes.isha; break;
        default: continue;
      }

      final alertTime = prayerTime.subtract(Duration(minutes: preMins));
      if (alertTime.isAfter(DateTime.now())) {
        await _scheduleNative(
          id + (i * 1000),
          "اقتراب صلاة $name",
          "باقي $preMins دقيقة على الصلاة",
          alertTime.hour,
          alertTime.minute,
          "default",
          year: alertTime.year,
          month: alertTime.month,
          day: alertTime.day,
        );
      }
    }
  }

  static Future<void> _scheduleIqama(
    int id,
    String name,
    DateTime time,
    SharedPreferences prefs,
    String key,
  ) async {
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
        payload: "home",
      );
    }
  }

  static Future<void> scheduleRamadanAlert(int id, String title, String body, DateTime time, {String sound = 'default'}) async {
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

  static Future<void> scheduleEidAlert(int id, String title, String body, DateTime time, {String sound = 'default'}) async {
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

  static Future<void> scheduleTakbeerat(PrayerTimes times) async {
    final off = PrayerService().hijriOffset;
    final hijriNow = HijriCalendar.fromDate(DateTime.now().add(Duration(days: off)));
    if (hijriNow.hMonth == 12 && hijriNow.hDay >= 1 && hijriNow.hDay <= 10) {
      final DateTime now = DateTime.now();
      final DateTime eidPrayerTime = times.sunrise.add(const Duration(minutes: 20));
      for (int hour = 0; hour <= 23; hour++) {
        final DateTime scheduledTime = DateTime(now.year, now.month, now.day, hour, 0);
        if (hijriNow.hDay == 10) {
          if (scheduledTime.isAfter(eidPrayerTime)) {
            await _platform.invokeMethod('cancelAlarm', {'id': 600 + hour});
            continue; 
          }
        }
        if (scheduledTime.isAfter(now)) {
          await _scheduleNative(
            600 + hour,
            "تكبيرات عشر ذي الحجّة",
            "الله أكبر الله أكبر الله أكبر، لا إله إلا الله، الله أكبر الله أكبر ولله الحمد",
            hour,
            0,
            "takbeerat",
            year: scheduledTime.year,
            month: scheduledTime.month,
            day: scheduledTime.day,
          );
        }
      }
    }
  }

  static Future<void> scheduleArafah(PrayerTimes times) async {
    await _scheduleNative(520, "سحور يوم عرفة", "تذكير بالسحور لصيام يوم عرفة", times.fajr.subtract(const Duration(hours: 1)).hour, times.fajr.subtract(const Duration(hours: 1)).minute, "default");
    await _scheduleNative(521, "إفطار يوم عرفة", "تقبل الله صيامكم", times.maghrib.hour, times.maghrib.minute, "default");
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
        final dir = await getApplicationSupportDirectory();
        final file = File("${dir.path}/adhans/$soundName.mp3");
        if (await file.exists()) {
          audioPath = file.path;
        }
      } catch (_) {}

      await _platform.invokeMethod('scheduleAlarm', {
        'id': id, 'year': year, 'month': month, 'day': day, 'hour': hour, 'minute': minute,
        'title': title, 'body': body, 'soundName': soundName, 'payload': payload,
        'audioPath': audioPath, 'intervalMinutes': intervalMinutes,
      });
    } catch (_) {}
  }

  static Future<void> cancelAll({bool includeWird = false}) async {
    var ids = [1, 2, 3] + [100, 101, 102, 103, 104, 105] + [200, 202, 203, 204, 205] + [300, 302, 303, 304, 305] + List.generate(200, (i) => 400 + i) + [700, 701, 702, 703, 705];
    if (includeWird) {
      ids += List.generate(100, (i) => 600 + i);
      ids += List.generate(1000, (i) => 6000 + i);
    }
    for (var id in ids) {
      try { await _platform.invokeMethod('cancelAlarm', {'id': id}); } catch (_) {}
    }
  }

  static Future<void> scheduleWird(int id, String title, String body, DateTime date, String? payload) async {
    await _platform.invokeMethod('cancelAlarm', {'id': id});
    DateTime scheduledDate = date;
    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    await _scheduleNative(id, title, body, scheduledDate.hour, scheduledDate.minute, "default", payload: payload, year: scheduledDate.year, month: scheduledDate.month, day: scheduledDate.day);
  }

  static Future<void> vibrate({int duration = 500}) async {
    try { await _platform.invokeMethod('vibrate', {'duration': duration}); } catch (_) {}
  }

  static Future<String?> checkLaunchPayload() async {
    try { return await _platform.invokeMethod('checkLaunchPayload'); } catch (_) { return null; }
  }

  static Future<void> scheduleSalawatReminders(int intervalMinutes, List<int> days) async {
    for (int i = 8000; i <= 8500; i++) {
      try { await _platform.invokeMethod('cancelAlarm', {'id': i}); } catch (_) {}
      try { await _flutterLocalNotificationsPlugin.cancel(i); } catch (_) {}
    }
    if (intervalMinutes <= 0 || days.isEmpty) return;
    DateTime now = DateTime.now();
    int id = 8000;
    for (int dayOfWeek in days) {
      DateTime targetDay = now;
      while (targetDay.weekday != dayOfWeek) { targetDay = targetDay.add(const Duration(days: 1)); }
      DateTime startTime;
      if (targetDay.day == now.day && targetDay.month == now.month) {
        startTime = now.add(Duration(minutes: intervalMinutes));
      } else {
        startTime = DateTime(targetDay.year, targetDay.month, targetDay.day, 8, 0);
      }
      try {
        await _scheduleNative(id, 'الصلاة على النبي ﷺ', 'اللهم صلِّ وسلم على نبينا محمد', startTime.hour, startTime.minute, 'saly_3ala_mo7amad', payload: 'friday_reminder', year: startTime.year, month: startTime.month, day: startTime.day, intervalMinutes: intervalMinutes);
      } catch (_) {}
      id++;
      if (id > 8007) break;
    }
  }

  static Future<void> scheduleFridayReminders(int intervalMinutes) async => scheduleSalawatReminders(intervalMinutes, [DateTime.friday]);
  static Future<void> cancelFridayCustom() async {
    for (int i = 8000; i <= 8500; i++) { await _flutterLocalNotificationsPlugin.cancel(i); }
  }
  static Future<void> schedulePrayerNotifications(PrayerTimes times) async => scheduleAll(times);
}
