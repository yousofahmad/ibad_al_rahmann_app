### 1. git status and git diff --stat
``text
On branch fix/master-plan-phase-1
Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   .gitignore
	deleted:    AI_RULES.md
	modified:   android/app/src/main/AndroidManifest.xml
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/AudioVolumeManager.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/MainActivity.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/MainApplication.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/PrayerFocusOverlay.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/PrayerNotificationService.kt
	modified:   android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockService.kt
	modified:   lib/core/helpers/islamic_day.dart
	modified:   lib/main.dart
	modified:   lib/quran_app.dart
	modified:   lib/screens/home_screen.dart
	modified:   lib/services/daily_tracker_service.dart
	modified:   lib/services/prayer_service.dart
	modified:   pubspec.lock
	modified:   pubspec.yaml
	modified:   test/widget_test.dart

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.ai_plans/
	FULL_AUDIO_ENGINEERING_SPEC.md
	android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockReceiver.kt
	ayah-recitation-abdur-rahman-as-sudais-recitation.json.zip
	gather_info.ps1
	lib/screens/hijri_confirmation_screen.dart
	lib/services/hijri_source_service.dart
	test_ibn_kathir.zip
	test_ibn_kathir/
	test_tabari.zip
	test_tabari/

no changes added to commit (use "git add" and/or "git commit -a")


 .gitignore                                         | Bin 1027 -> 1146 bytes
 AI_RULES.md                                        |  88 ---------
 android/app/src/main/AndroidManifest.xml           |  15 +-
 .../kotlin/app/ibad_al_rahmann/AlarmReceiver.kt    |  54 ++++-
 .../app/ibad_al_rahmann/AudioVolumeManager.kt      |   4 +-
 .../BackgroundMethodChannelPlugin.kt               |  18 +-
 .../kotlin/app/ibad_al_rahmann/MainActivity.kt     |  17 --
 .../kotlin/app/ibad_al_rahmann/MainApplication.kt  |  21 ++
 .../app/ibad_al_rahmann/NativeAzkarScheduler.kt    |  91 ++++++++-
 .../app/ibad_al_rahmann/PrayerFocusOverlay.kt      | 104 ++++++++--
 .../ibad_al_rahmann/PrayerNotificationService.kt   |  28 ++-
 .../app/ibad_al_rahmann/ScreenUnlockService.kt     | 219 +--------------------
 lib/core/helpers/islamic_day.dart                  |  19 +-
 lib/main.dart                                      |   8 +
 lib/quran_app.dart                                 |   4 +
 lib/screens/home_screen.dart                       |  60 ++++++
 lib/services/daily_tracker_service.dart            |   1 -
 lib/services/prayer_service.dart                   |   7 +-
 pubspec.lock                                       |   2 +-
 pubspec.yaml                                       |   3 +-
 test/widget_test.dart                              |   5 +-
 21 files changed, 402 insertions(+), 366 deletions(-)

``

### 2. File Contents

#### lib/features/wird/ui/khatma_details_screen.dart
`
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../bloc/khatma_cubit.dart';
import 'khatma_details_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class KhatmaDetailsScreen extends StatelessWidget {
  final String khatmaId;

  const KhatmaDetailsScreen({super.key, required this.khatmaId});

  void _showDeleteWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "تنبيه",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontFamily: AppConsts.cairo,
          ),
        ),
        content: const Text(
          "هل أنت متأكد؟ سيتم حذف هذه الختمة ولن تتمكن من استرجاعها.",
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KhatmaCubit>().deleteKhatma(khatmaId);
              Navigator.pop(context);
            },
            child: const Text(
              "نعم، متأكد",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimePickerDialog(BuildContext context, KhatmaCubit cubit, String? currentTime) async {
    final parts = (currentTime ?? '20:00').split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'وقت التنبيه اليومي',
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) {
      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await cubit.updateDailyTime(khatmaId, newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          "تفاصيل الختمة",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        actions: [
          BlocBuilder<KhatmaCubit, KhatmaState>(
            builder: (context, state) {
              if (state is KhatmaLoaded) {
                try {
                  final khatma = state.khatmas.firstWhere((k) => k.id == khatmaId);
                  if (khatma.notificationType == 'daily' && khatma.enableNotifications) {
                    return IconButton(
                      tooltip: 'تعديل وقت التنبيه',
                      onPressed: () => _showTimePickerDialog(
                        context,
                        context.read<KhatmaCubit>(),
                        khatma.dailyTime,
                      ),
                      icon: const Icon(Icons.access_time_rounded, color: Color(0xFFD0A871), size: 22),
                    );
                  }
                } catch (_) {}
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: () => _showDeleteWarningDialog(context),
            icon: const Icon(
              FontAwesomeIcons.trashCan,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
      body: BlocBuilder<KhatmaCubit, KhatmaState>(
        builder: (context, state) {
          if (state is KhatmaLoaded) {
            try {
              final khatma = state.khatmas.firstWhere((k) => k.id == khatmaId);
              return KhatmaDetailsView(khatma: khatma);
            } catch (_) {
              return const Center(
                child: Text(
                  "هذه الختمة لم تعد موجودة",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

`

#### lib/features/wird/ui/khatma_details_view.dart
`
          children: [
            Icon(icon, color: const Color(0xFFD0A871), size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text Share helpers injected into separate section ─────────────────────

extension _WirdTextShare on _KhatmaDetailsViewState {
  String _toArabicDigits(int n) {
    const map = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? map[d] : c;
    }).join();
  }

  String _wirdTimeLabel(KhatmaModel khatma, int wirdIndex) {
    final type = khatma.notificationType;
    if (type == 'prayer') {
      const prayers = ['الفجر', 'الضحى', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      return prayers[wirdIndex % prayers.length];
    }
    if (type == 'daily' && khatma.dailyTime != null) return khatma.dailyTime!;
    return 'اليومي';
  }

  String _hijriMonthName(int month) {
    const names = [
      '',
      'مُحَرَّم',
      'صَفَر',
      'رَبِيع الأَوَّل',
      'رَبِيع الثَّانِي',
      'جُمَادَى الأُولَى',
      'جُمَادَى الآخِرَة',
      'رَجَب',
      'شَعْبَان',
      'رَمَضَان',
      'شَوَّال',
      'ذُو القَعْدَة',
      'ذُو الحِجَّة',
    ];
    return month >= 1 && month <= 12 ? names[month] : '';
  }

  // Returns 2 share text variants (Simple, Detailed).
  (String, String) _buildWirdShareTexts(KhatmaModel khatma, int wirdIndex) {
    final wurde = khatma.wirds[wirdIndex];
    HijriCalendar.setLocal('ar');
    // Use the offset-adjusted Hijri date so the shared text matches the app UI.
    final hijri = PrayerService().getAdjustedHijri();
    final today = _toArabicDigits(hijri.hDay);
    final yearH = _toArabicDigits(hijri.hYear);
    final monthName = _hijriMonthName(hijri.hMonth);
    final wirdTime = _wirdTimeLabel(khatma, wirdIndex);
    final startPage = _toArabicDigits(wurde.startPage);
    final endPage = _toArabicDigits(wurde.endPage);
    final pageCount = _toArabicDigits(wurde.endPage - wurde.startPage + 1);

    // Build the full list of Surah names covered by this wird.
    final List<String> surahNames = [];
    final int sStart = wurde.startSuraNumber.clamp(1, 114);
    final int sEnd = wurde.endSuraNumber.clamp(1, 114);
    for (int n = sStart; n <= sEnd; n++) {
      surahNames.add(quran.getSurahNameArabic(n));
    }
    // Compact first→last for formatted.
    final surahShort = surahNames.length == 1
        ? surahNames.first
        : '${surahNames.first} ← ${surahNames.last}';

    // Page range e.g. "٣٩٩ و ٤٠٠" or "٣٩٩ - ٤٠١"
    final pageRange = wurde.startPage == wurde.endPage
        ? startPage
        : (wurde.endPage - wurde.startPage == 1)
        ? '$startPage و $endPage'
        : '$startPage - $endPage';

    // ── Format 1: simple compact ────────────────────────────────────────
    final simple =
        '*وِرد اليوم $today $monthName $yearHهـ*\n'
        '*صفحة $pageRange*';

    // ── Format 2: full formatted (no app name) ──────────────────────
    final formatted =
        '*• الـوِرد الـيَـومِـي لِشَهْرِ $monthName لِعام $yearH هـ :*\n\n'
        '*📅 — الـيوم : " $today "*\n'
        '*📖 — إسـم السورة : ( $surahShort )*\n'
`

#### lib/services/notification_service.dart
`
static Future<void> scheduleAll(
    PrayerTimes times, {
    List<ExtendedPrayer>? extended,
    String? logFilter,
    bool isUserAction = false,
  }

static Future<void> _scheduleKhatmaNotifications(KhatmaModel khatma, SharedPreferences prefs) async {
    final cleanId = khatma.id.startsWith('khatma_') ? khatma.id.replaceFirst('khatma_', '') : khatma.id;
    int idBase = 100000 + (_javaStringHashCode(cleanId) % 40000) * 10;
    final now = DateTime.now();

    // Cancel existing khatma alarms first to avoid duplicates when rescheduleWird is called multiple times
    final cancelIds = <int>[];
    cancelIds.addAll(List.generate(80, (i) => idBase + i));
    cancelIds.addAll(List.generate(80, (i) => (100000 + (khatma.id.hashCode.abs() % 40000) * 10) + i));
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
           await _scheduleNative(scheduledId, "ورد ${khatma.name}", "$bodyPrefixحان وقت وردك اليومي$pageInfo", t.hour, t.minute, "ibad_al_rahmann_tone", year: t.year, month: t.month, day: t.day, payload: payload, customSoundName: "ibad_al_rahmann_tone");
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
            await _scheduleNative(scheduledId, "ورد ${khatma.name}", "$bodyPrefixحان وقت وردك بعد صلاة $name$pageInfo", t.hour, t.minute, "ibad_al_rahmann_tone", year: t.year, month: t.month, day: t.day, payload: payload, customSoundName: "ibad_al_rahmann_tone");
          }
          prayerIdx++;
        }
      }
    }
  }

`

#### android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt
`
package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val alarmIdForLog = intent.getIntExtra("notification_id", -1)
        android.util.Log.d("PrayerApp", "AlarmReceiver triggered with action: $action, alarmId: $alarmIdForLog")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            rescheduleAllAlarms(context)
            refreshFromStoredEpochs(context)
            WidgetUpdateHelper.onPrayerAlarmFired(context, -1)
            WidgetUpdateHelper.scheduleMidnightRefresh(context) // تشغيل محرك منتصف الليل
            return
        }

        // ── DST / date / time change ──────────────────────────────────────────────
        if (action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == "android.intent.action.TIME_SET") {
            refreshFromStoredEpochs(context)
            return
        }

        val payload = intent.getStringExtra("payload") ?: "home"
        if (payload == "sync_only") {
            android.util.Log.d("PrayerApp", "AlarmReceiver: sync_only payload received. Refreshing alarms.")
            refreshFromStoredEpochs(context)
            return
        }

        val alarmId = intent.getIntExtra("alarm_id", 0)

        // ── محرك منتصف الليل (تحديث الويدجت والأذان لليوم الجديد ذاتياً) ──
        if (alarmId == 9999) {
            // CRITICAL: Regenerate 30-day cache FIRST so new month's prayer times are fresh.
            // This prevents the "Fajr fires at 12am / 28-hour countdown" bug during month transitions.
            try {
                NativePrayerManager.generateThirtyDayCache(context)
                NativeLogger.log(context, "Midnight: regenerated 30-day cache successfully.")
            } catch (e: Exception) {
                NativeLogger.log(context, "Midnight: generateThirtyDayCache failed: ${e.message}")
            }
            refreshFromStoredEpochs(context)
            NativeHijriHelper.updateNativeHijriDate(context)
            
            val fp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currentHijriDay = fp.getInt("flutter.current_hijri_day", 0)
            if (currentHijriDay == 29) {
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                val confirmedDate = fp.getString("flutter.local_hijri_confirmed_date", "")
                if (confirmedDate != todayStr) {
                    showHijri29Notification(context)
                }
            }

            WidgetUpdateHelper.scheduleMidnightRefresh(context)
            WidgetUpdateHelper.onPrayerAlarmFired(context, -1)
            return
        }
        
        // ── Prayer Focus Snooze Overlay (Doze-proof wakeup) ──
        if (intent.getBooleanExtra("is_snooze_overlay", false) || payload == "snooze_focus_overlay") {
            val prayerName = intent.getStringExtra("snooze_prayer_name") ?: "الصلاة"
            val snoozeAlarmId = intent.getIntExtra("snooze_alarm_id", 100)
            NativeLogger.log(context, "AlarmReceiver: Snooze fired for $prayerName (alarmId: $snoozeAlarmId)")
            try {
                PrayerFocusOverlay.show(context, prayerName, snoozeAlarmId)
            } catch (e: Exception) {
                NativeLogger.log(context, "PrayerFocusOverlay Snooze ERROR: $e")
            }
            return
        }

        // Ignore rogue broadcasts with no valid alarm_id.
        // This solves the bug where a rogue "تنبيه / حان الوقت" notification
        // appears alongside normal alarms (like Adhan).
        if (alarmId == 0) return
        
        // If tomorrow's Fajr fires (110), reschedule all of the new day's prayers
        if (alarmId == 110) {
            NativeLogger.log(context, "AlarmReceiver: Tomorrow Fajr (110) fired — rescheduling today's prayers")
            refreshFromStoredEpochs(context)
        }

        // If it's a prayer alarm (100-104), update widget and notification autonomously
        if (alarmId in 100..104 || alarmId == 110) {
            WidgetUpdateHelper.onPrayerAlarmFired(context, alarmId)

            // ── Prayer Focus Overlay (شاشة التركيز) ──────────────────────────
            // PRAYER_IDS fixed: 100=Fajr, 101=Dhuhr, 102=Asr, 103=Maghrib, 104=Isha
            val focusPrayerName = when (alarmId) {
                100 -> "الفجر"
                101 -> if (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY) "الجمعة" else "الظهر"
                102 -> "العصر"
                103 -> "المغرب"
                104 -> "العشاء"
                else -> null
            }
            if (focusPrayerName != null) {
                try { PrayerFocusOverlay.show(context, focusPrayerName, alarmId) }
                catch (e: Exception) { NativeLogger.log(context, "PrayerFocusOverlay ERROR: ${e}") }
            }

            // Force-push widget update to beat Doze-mode throttling
            val widgetManager = android.appwidget.AppWidgetManager.getInstance(context)
            val providers = listOf(
                PrayerWidgetProvider::class.java,
                PrayerWidgetLargeProvider::class.java,
                PrayerWidgetWideProvider::class.java,
            )
            for (provider in providers) {
                val ids = widgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, provider)
                )
                if (ids.isNotEmpty()) {
                    val updateIntent = Intent(context, provider).apply {
                        setAction(android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                        putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(updateIntent)
                }
            }
        }

        // ── تذكير ما قبل الأذان (IDs 6000-6004) ──────────────────────────────────
        if (alarmId in 6000..6004) {
            val fp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (fp.getBoolean("flutter.prayer_focus_enabled", false)) {
                val mins = getSafeInt(fp, "flutter.pre_adhan_reminder_minutes", 0)
                val name = when (alarmId) {
                    6000 -> "الفجر"; 6001 -> "الظهر"; 6002 -> "العصر"
                    6003 -> "المغرب"; else -> "العشاء"
                }
                if (mins > 0) PrayerFocusOverlay.showPreAdhan(context, name, alarmId, mins)
            }
            return // Overlay-only, no regular notification
        }

        // --- Original Alarm Logic (Sound/Notification) ---
        val soundName = intent.getStringExtra("sound_name") ?: "default"
        val cleanSoundNameEarly = soundName.replace(".mp3", "").lowercase().trim()
        
        // Abort early only if truly disabled. Silent notifications should proceed.
        if (cleanSoundNameEarly == "none" || cleanSoundNameEarly == "null") return
        
        val isFriday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
        val prayerNameFallback = when {
            alarmId == 100 || alarmId == 110 || alarmId == 1000 || alarmId == 3000 || alarmId == 4000 || alarmId == 5000 -> "الفجر"
            alarmId == 101 || alarmId == 111 || alarmId == 1001 || alarmId == 3001 || alarmId == 4001 || alarmId == 5001 -> if (isFriday) "الجمعة" else "الظهر"
            alarmId == 102 || alarmId == 112 || alarmId == 1002 || alarmId == 3002 || alarmId == 4002 || alarmId == 5002 -> "العصر"
            alarmId == 103 || alarmId == 113 || alarmId == 1003 || alarmId == 3003 || alarmId == 4003 || alarmId == 5003 -> "المغرب"
            alarmId == 104 || alarmId == 114 || alarmId == 1004 || alarmId == 3004 || alarmId == 4004 || alarmId == 5004 -> "العشاء"
            else -> null
        }

        val fallbackTitle = if (prayerNameFallback != null) {
            when {
                alarmId >= 5000 -> "إقامة صلاة $prayerNameFallback"
                alarmId >= 4000 -> "أذان صلاة $prayerNameFallback"
                alarmId >= 3000 -> "تنبيه موعد $prayerNameFallback"
                else -> "صلاة $prayerNameFallback"
            }
        } else when (alarmId) {
            1 -> "لا تنس أذكار الصباح، مفتاح البركة والنشاط"
            2 -> "الرقية الشرعية"
            3 -> "اجعل لسانك رطباً بذكر الله في المساء 💙"
            4 -> "الرقية الشرعية"
            2000 -> "اغتنم وقت السحر بالدعاء 💙"
            2001 -> "اغتنم وقت السحر بالدعاء 💙"
            2002 -> "اغتنم وقت السحر بالدعاء 💙"
            732 -> "صلاة الضحى"
            736 -> "وقت الشروق"
            else -> ""
        }

        val fallbackBody = if (prayerNameFallback != null) {
            when {
                // 1. Iqama Messages
                alarmId >= 5000 -> when (prayerNameFallback) {
                    "الفجر" -> "تقام الآن صلاة الفجر .. أفلح من صلى"
                    else -> "تقام الآن صلاة $prayerNameFallback .. استووا واعتدلوا"
                }
                // 2. Adhan/Prayer Messages (Wisdoms)
                alarmId >= 4000 || alarmId < 3000 -> when (prayerNameFallback) {
                    "الفجر" -> "من صلى الفجر في جماعة فهو في ذمة الله"
                    "الشروق" -> "حان الآن وقت شروق الشمس"
                    "الظهر" -> "لا تجعل عملك يلهيك عن أداء الصلاة"
                    "العصر" -> "حافظوا على الصلوات والصلاة الوسطى"
                    "المغرب" -> "لا يزال الناس بخير ما عجلوا الفطر"
                    "العشاء" -> "صلاة العشاء في جماعة كقيام نصف الليل"
                    else -> "حان الآن موعد صلاة $prayerNameFallback"
                }
                // 3. Pre-prayer Messages
                alarmId >= 3000 -> "الدعاء لا يرد بين الأذان والإقامة .. استعد للصلاة"
                else -> "حان الآن موعد صلاة $prayerNameFallback"
            }
        } else when (alarmId) {
            1 -> "أذكار الصباح تفتح لك أبواب الرزق والطمأنينة."
            2 -> "حصن نفسك الآن بالرقية الشرعية"
            3 -> "اللهم اجعل في هذا المساء نوراً في قلوبنا، وصفاءً في أرواحنا، وبركةً في أرزاقنا."
            4 -> "حصن نفسك الآن بالرقية الشرعية"
            2000 -> "هذا الليل أوسع من حزنك، توضأ، واغسل شحوبك، زمل قلبك الباكي قرآناً."
            2001 -> "هذا الليل أوسع من حزنك، توضأ، واغسل شحوبك، زمل قلبك الباكي قرآناً."
            2002 -> "هذا الليل أوسع من حزنك، توضأ، واغسل شحوبك، زمل قلبك الباكي قرآناً."
            732 -> "صلاة الأوابين .. حان الآن موعد صلاة الضحى"
            736 -> "حان الآن وقت الشروق"
            else -> ""
        }

        var title = (intent.getStringExtra("title") ?: fallbackTitle).trim().take(250)
        var body = (intent.getStringExtra("body") ?: fallbackBody).trim().take(500)
        // payload variable already extracted above
        val rawAudioPath = intent.getStringExtra("audio_path")
        val audioPath = if (rawAudioPath != null && (rawAudioPath.contains("..") || rawAudioPath.contains("\u0000"))) {
            null
        } else {
            rawAudioPath
        }
        val customSoundName = intent.getStringExtra("custom_sound_name")?.replace("..", "")?.take(100)
        
        if (payload.startsWith("khatma_")) {
            val parts = payload.split("_")
            if (parts.size >= 2) {
                val khatmaId = parts[1]
                if (!KhatmaHelper.isKhatmaValid(context, khatmaId)) {
                    NativeLogger.log(context, "AlarmReceiver: Dropping khatma notification since khatma_khatmaId was deleted.")
                    // Make sure we still chain if this was a repeating alarm, but for khatmas we usually don't chain here.
                    // Actually, if it's deleted, we don't want to chain. We want to kill the sequence!
                    return
                }
                val delayText = KhatmaHelper.getDelayText(context, khatmaId)
                body = delayText + body
            }
        }

        if (title.isNotEmpty() && body.isNotEmpty()) {
            val year = intent.getIntExtra("year", -1)
            val month = intent.getIntExtra("month", -1)
            val day = intent.getIntExtra("day", -1)

            if (year != -1 && month != -1 && day != -1) {
                val intendedCal = Calendar.getInstance().apply {
                    set(Calendar.YEAR, year)
                    set(Calendar.MONTH, month - 1)
                    set(Calendar.DAY_OF_MONTH, day)
                    set(Calendar.HOUR_OF_DAY, intent.getIntExtra("hour", 0))
                    set(Calendar.MINUTE, intent.getIntExtra("minute", 0))
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                
                // If the alarm fired more than 1 hour late (e.g. phone was off or Doze mode), drop it
                // to prevent stale notifications (like Friday's notification arriving on Saturday).
                // For repeating interval alarms, they will be rescheduled correctly by the chaining logic.
                if (System.currentTimeMillis() - intendedCal.timeInMillis > 3600000L) {
                    NativeLogger.log(context, "AlarmReceiver: Dropping stale notification $title. Was scheduled for ${intendedCal.time}")
                    // We don't return here completely! We must still run the chaining logic below 
                    // so the NEXT occurrence gets scheduled!
                    val chainSoundName = soundName
                    val chainPayload = payload
                    val chainCustomSoundName = customSoundName
                    handleAlarmChaining(context, intent, alarmId, chainSoundName, title, body, chainPayload, audioPath)
                    return
                }
            }

            // ── Quiet Hours Gate for Salawat and Takbeerat ──
            var skipNotif = isNotificationExplicitlyDisabled(context, alarmId, soundName)
            if (!skipNotif) {
                if (alarmId in 8000..8999) {
                    // Salawat range (8000+) uses general quiet_hours
                    if (isInQuietHours(context, "quiet_hours")) {
                        skipNotif = true
                    }
                } else if (alarmId in 9000..9199) {
                    // Takbeerat range uses takbeerat_quiet_hours
                    if (isInQuietHours(context, "takbeerat_quiet_hours")) {
                        skipNotif = true
                    }
                }
            }

            // --- Backward Compatibility for Ghost Salawat Alarms ---
            var finalSoundName = soundName
            var finalPayload = payload
            var finalCustomSoundName = customSoundName
            if (alarmId == 950 || alarmId in 8000..9500) {
                finalSoundName = "saly_3ala_mo7amad"
                finalCustomSoundName = "saly_3ala_mo7amad"
                finalPayload = "salawat"
            }

            if (!skipNotif) {
                NativeLogger.log(context, "Notification Fired! Title: $title | Body: $body | AlarmId: $alarmId | Payload: $finalPayload")
                showNotification(context, alarmId, title, body, finalSoundName, finalPayload, audioPath, finalCustomSoundName)
            } else {
                NativeLogger.log(context, "Notification Skipped (disabled or in quiet hours). AlarmId: $alarmId")
            }
        }

        // Use the fixed soundName and payload for chaining
        var chainSoundName = soundName
        var chainPayload = payload
        var chainCustomSoundName = customSoundName
        if (alarmId == 950 || alarmId in 8000..9500) {
            chainSoundName = "saly_3ala_mo7amad"
            chainCustomSoundName = "saly_3ala_mo7amad"
            chainPayload = "salawat"
        }

        handleAlarmChaining(context, intent, alarmId, chainSoundName, title, body, chainPayload, audioPath)
    }

    private fun isNotificationExplicitlyDisabled(context: Context, alarmId: Int, soundName: String): Boolean {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()
        if (cleanSoundName == "none" || cleanSoundName == "null" || cleanSoundName.isEmpty()) return true

        val fp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        when (alarmId) {
            100, 110 -> if (fp.contains("flutter.notif_prayer_fajr") && !fp.getBoolean("flutter.notif_prayer_fajr", true)) return true
            101, 111 -> {
                val isFriday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
                if (isFriday) {
                    if (fp.contains("flutter.notif_jumua") && !fp.getBoolean("flutter.notif_jumua", true)) return true
                } else {
                    if (fp.contains("flutter.notif_prayer_dhuhr") && !fp.getBoolean("flutter.notif_prayer_dhuhr", true)) return true
                }
            }
            102, 112 -> if (fp.contains("flutter.notif_prayer_asr") && !fp.getBoolean("flutter.notif_prayer_asr", true)) return true
            103, 113 -> if (fp.contains("flutter.notif_prayer_maghrib") && !fp.getBoolean("flutter.notif_prayer_maghrib", true)) return true
            104, 114 -> if (fp.contains("flutter.notif_prayer_isha") && !fp.getBoolean("flutter.notif_prayer_isha", true)) return true

            1 -> if (fp.contains("flutter.notif_azkar_morning") && !fp.getBoolean("flutter.notif_azkar_morning", true)) return true
            3 -> if (fp.contains("flutter.notif_azkar_evening") && !fp.getBoolean("flutter.notif_azkar_evening", true)) return true

            2000, 2001, 2002 -> if (fp.contains("flutter.notif_qiyam") && !fp.getBoolean("flutter.notif_qiyam", false)) return true
            732 -> if (fp.contains("flutter.notif_duha") && !fp.getBoolean("flutter.notif_duha", false)) return true
            736 -> if (fp.contains("flutter.notif_sunrise") && !fp.getBoolean("flutter.notif_sunrise", true)) return true

            3000 -> if (fp.contains("flutter.notif_pre_Fajr") && !fp.getBoolean("flutter.notif_pre_Fajr", false)) return true
            3001 -> if (fp.contains("flutter.notif_pre_Dhuhr") && !fp.getBoolean("flutter.notif_pre_Dhuhr", false)) return true
            3002 -> if (fp.contains("flutter.notif_pre_Asr") && !fp.getBoolean("flutter.notif_pre_Asr", false)) return true
            3003 -> if (fp.contains("flutter.notif_pre_Maghrib") && !fp.getBoolean("flutter.notif_pre_Maghrib", false)) return true
            3004 -> if (fp.contains("flutter.notif_pre_Isha") && !fp.getBoolean("flutter.notif_pre_Isha", false)) return true
        }
        return false
    }

    private fun isInQuietHours(context: Context, prefix: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Flutter's shared_preferences stores ints as Longs on Android.
        // Reading as getInt() will crash if the value was saved by Flutter.
        // We use allKeys to check the actual type or use a helper.
        fun getSafeInt(key: String, def: Int): Int {
            return try {
                if (prefs.contains(key)) {
                    val v = prefs.all[key]
                    if (v is Long) v.toInt()
                    else if (v is Int) v
                    else def
                } else def
            } catch (e: Exception) {
                def
            }
        }

        val startHour = getSafeInt("flutter.${prefix}_start_hour", 23)
        val startMin = getSafeInt("flutter.${prefix}_start_minute", 0)
        val endHour = getSafeInt("flutter.${prefix}_end_hour", 7)
        val endMin = getSafeInt("flutter.${prefix}_end_minute", 0)

        val cal = Calendar.getInstance()
        val nowTime = cal.get(Calendar.HOUR_OF_DAY) + cal.get(Calendar.MINUTE) / 60.0
        val startTime = startHour + startMin / 60.0
        val endTime = endHour + endMin / 60.0

        return if (startTime <= endTime) {
            nowTime >= startTime && nowTime < endTime
        } else {
            nowTime >= startTime || nowTime < endTime
        }
    }

    private fun rescheduleAllAlarms(context: Context) {
        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val allEntries = prefs.all
        
        for ((key, value) in allEntries) {
            // We look for keys like "alarm_123_active" where value is true
            if (key.startsWith("alarm_") && key.endsWith("_active") && value == true) {
                try {
                    val idStr = key.substring(6, key.length - 7)
                    val id = idStr.toIntOrNull() ?: continue
                    
                    val hour = getSafeInt(prefs, "alarm_${id}_hour", 6)
                    val minute = getSafeInt(prefs, "alarm_${id}_minute", 0)
                    val savedSound = prefs.getString("alarm_${id}_sound", null)
                    val soundName = savedSound ?: if (id in 100..105) "nafis" else "default"
                    val customSound = prefs.getString("alarm_${id}_custom_sound", null)
                    
                    val fallbackTitle = when (id) {
                        100 -> "صلاة الفجر"
                        101 -> "وقت الشروق"
                        102 -> "صلاة الظهر"
                        103 -> "صلاة العصر"
                        104 -> "صلاة المغرب"
                        105 -> "صلاة العشاء"
                        else -> ""
                    }
                    val fallbackBody = when (id) {
                        100 -> "حان الآن موعد صلاة الفجر"
                        101 -> "حان الآن وقت الشروق"
                        102 -> "حان الآن موعد صلاة الظهر"
                        103 -> "حان الآن موعد صلاة العصر"
                        104 -> "حان الآن موعد صلاة المغرب"
                        105 -> "حان الآن موعد صلاة العشاء"
                        else -> ""
                    }
                    
                    val title = prefs.getString("alarm_${id}_title", fallbackTitle)
                    val body = prefs.getString("alarm_${id}_body", fallbackBody)
                    val payload = prefs.getString("alarm_${id}_payload", null)
                    val audioPath = prefs.getString("alarm_${id}_audioPath", null)
                    val interval = getSafeInt(prefs, "alarm_${id}_interval", 0)

                    val year = getSafeInt(prefs, "alarm_${id}_year", -1)
                    val month = getSafeInt(prefs, "alarm_${id}_month", -1)
                    val day = getSafeInt(prefs, "alarm_${id}_day", -1)

                    MainActivity.scheduleAlarm(context, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, interval, customSound)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun handleAlarmChaining(context: Context, intent: Intent, alarmId: Int, soundName: String, title: String, body: String, payload: String, audioPath: String?) {
        if (alarmId == 1 || alarmId == 3) {
            // Morning Azkar (1) -> Ruqyah (2), Evening Azkar (3) -> Ruqyah (4)
            showNotification(context, alarmId + 1, "🛡️ الرقية الشرعية", "حصن نفسك الآن بالرقية الشرعية", "ruqyah", "ruqyah", null)
        }

        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        // ... (rest of the method unchanged)

        if (alarmId in 5..8) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return
            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 7) }
            MainActivity.scheduleAlarm(
                context, alarmId,
                cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                hour, minute, soundName, title, body, payload, false, audioPath, 0
            )
            return
        } else if (alarmId < 1000 && alarmId !in 100..105 && alarmId !in 9..11 && alarmId != 732 && alarmId != 736) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return

            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            val interval = intent.getIntExtra("interval_minutes", 0)
            MainActivity.scheduleAlarm(context, alarmId, -1, -1, -1, hour, minute, soundName, title, body, payload, true, audioPath, interval)
        } else if (alarmId in 8000..8999 || alarmId in 9000..9199) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return

            val interval = intent.getIntExtra("interval_minutes", 0)
            if (interval > 0) {
                val cal = Calendar.getInstance()
                
                // Use the intended trigger time as base to prevent drift
                val triggerYear = intent.getIntExtra("year", cal.get(Calendar.YEAR))
                val triggerMonth = intent.getIntExtra("month", cal.get(Calendar.MONTH) + 1)
                val triggerDay = intent.getIntExtra("day", cal.get(Calendar.DAY_OF_MONTH))
                val triggerHour = intent.getIntExtra("hour", cal.get(Calendar.HOUR_OF_DAY))
                val triggerMinute = intent.getIntExtra("minute", cal.get(Calendar.MINUTE))
                
                cal.set(triggerYear, triggerMonth - 1, triggerDay, triggerHour, triggerMinute, 0)
                cal.set(Calendar.MILLISECOND, 0)
                
                // Add interval
                cal.add(Calendar.MINUTE, interval)
                
                // If the calculated next time is already in the past, keep adding interval 
                // until we find the next future occurrence (prevents 'notification storm' on wake)
                val now = Calendar.getInstance()
                while (cal.before(now)) {
                    cal.add(Calendar.MINUTE, interval)
                }

                MainActivity.scheduleAlarm(
                    context, alarmId,
                    cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                    cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE),
                    soundName, title, body, payload, false, audioPath, interval
                )
            }
        }
    }

    private fun getSafeInt(prefs: android.content.SharedPreferences, key: String, defValue: Int): Int {
        return try {
            val bits = prefs.getLong(key, -1L)
            if (bits != -1L) bits.toInt() else prefs.getInt(key, defValue)
        } catch (e: Exception) {
            try { prefs.getInt(key, defValue) } catch (e2: Exception) { defValue }
        }
    }

    private fun refreshFromStoredEpochs(context: Context) {
        // Clear ghost broadcast alarms from the old broken logic
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in 100..115) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            alarmManager.cancel(pi)
            pi.cancel()
        }

        NativePrayerScheduler.scheduleToday(context)
        NativeAzkarScheduler.scheduleAzkar(context)

        // START FIX: Start persistent notification service when alarm fires
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isPersistentEnabled = flutterPrefs.getBoolean("flutter.persistent_notification_enabled", true)
            if (isPersistentEnabled) {
                val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
                    action = "SYNC"
                }
                // Use startForegroundService on Android 8+ (it works reliably from alarm receivers)
                // On Android 12+ it may throw, which we catch below
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(svcIntent)
                } else {
                    context.startService(svcIntent)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        // END FIX

        WidgetUpdateHelper.onPrayerAlarmFired(context, -1)
        WidgetUpdateHelper.scheduleMidnightRefresh(context)
    }

    private fun showNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()

        // Absolute return for none/null — ensures no ghost notifications
        if (cleanSoundName == "none" || cleanSoundName == "null") return

        val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "PLAY_SOUND"
            putExtra("notification_id", notifId)
            putExtra("title", title)
            putExtra("body", content)
            putExtra("target_page", targetPage)
            putExtra("sound_name", soundName)
            if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
            if (audioPath != null) putExtra("audio_path", audioPath)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svcIntent)
        } else {
            context.startService(svcIntent)
        }
    }

    companion object {
        fun showHijri29Notification(context: Context) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "hijri_check_channel"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "تأكيد التاريخ الهجري",
                    NotificationManager.IMPORTANCE_HIGH
                )
                notificationManager.createNotificationChannel(channel)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("payload", "hijri_confirmation")
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(context, 99999, intent, pendingIntentFlags)

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(context.resources.getIdentifier("ic_notification", "drawable", context.packageName))
                .setContentTitle("تأكيد الشهر الهجري")
                .setContentText("مش قادرين نتأكد إن الشهر الهجري خلص ولا لسه — افتح التطبيق عشان تتأكد")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            notificationManager.notify(99999, builder.build())
        }

        fun buildAndShowNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
            val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()

            // Absolute return for none/null — ensures no ghost notifications
            if (cleanSoundName == "none" || cleanSoundName == "null") return

            val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
                action = "PLAY_SOUND"
                putExtra("notification_id", notifId)
                putExtra("title", title)
                putExtra("body", content)
                putExtra("target_page", targetPage)
                putExtra("sound_name", soundName)
                if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
                if (audioPath != null) putExtra("audio_path", audioPath)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svcIntent)
            } else {
                context.startService(svcIntent)
            }
        }

        fun forceUpdateAllWidgets(context: Context) {
            val providers = arrayOf(PrayerWidgetProvider::class.java, PrayerWidgetLargeProvider::class.java, PrayerWidgetWideProvider::class.java)
            for (provider in providers) {
                val intent = Intent(context, provider).apply { action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE }
                val ids = android.appwidget.AppWidgetManager.getInstance(context).getAppWidgetIds(android.content.ComponentName(context, provider))
                if (ids.isNotEmpty()) {
                    intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    context.sendBroadcast(intent)
                }
            }
        }
    }


}

`

#### android/app/src/main/kotlin/app/ibad_al_rahmann/KhatmaHelper.kt
`
package app.ibad_al_rahmann

import android.content.Context
import org.json.JSONObject

object KhatmaHelper {

    fun isKhatmaValid(context: Context, khatmaId: String): Boolean {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val legacyKey = "flutter.khatma_" + khatmaId
            if (flutterPrefs.contains(legacyKey)) return true
            
            val modelKey = "flutter.khatma_" + khatmaId + "_model"
            if (flutterPrefs.contains(modelKey)) return true
            
            // Also check all keys just in case
            for (key in flutterPrefs.all.keys) {
                if (key.startsWith("flutter.khatma_")) {
                    val jsonStr = flutterPrefs.getString(key, null) ?: continue
                    try {
                        val json = JSONObject(jsonStr)
                        if (json.optString("id") == khatmaId) return true
                    } catch (e: Exception) { }
                }
            }
        } catch (e: Exception) {}
        return false
    }

    fun getDelayText(context: Context, khatmaId: String): String {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val khatmaKeys = flutterPrefs.all.keys.filter { it.startsWith("flutter.khatma_") && it.endsWith("_model") }
            
            var targetJsonStr: String? = null
            for (key in khatmaKeys) {
                val jsonStr = flutterPrefs.getString(key, null) ?: continue
                val json = JSONObject(jsonStr)
                if (json.optString("id") == khatmaId || key == "flutter.khatma_${khatmaId}_model") {
                    targetJsonStr = jsonStr
                    break
                }
            }
            
            if (targetJsonStr == null) return ""
            
            val json = JSONObject(targetJsonStr)
            val startDateStr = json.optString("startDate")
            if (startDateStr.isNullOrEmpty()) return ""
            
            // Format: 2026-08-10T22:45:05.000
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            val startDate = sdf.parse(startDateStr) ?: return ""
            
            val startCal = java.util.Calendar.getInstance().apply { time = startDate }
            startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            startCal.set(java.util.Calendar.MINUTE, 0)
            startCal.set(java.util.Calendar.SECOND, 0)
            startCal.set(java.util.Calendar.MILLISECOND, 0)
            
            val todayCal = java.util.Calendar.getInstance()
            todayCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            todayCal.set(java.util.Calendar.MINUTE, 0)
            todayCal.set(java.util.Calendar.SECOND, 0)
            todayCal.set(java.util.Calendar.MILLISECOND, 0)
            
            val diffMs = todayCal.timeInMillis - startCal.timeInMillis
            var daysSinceStart = (diffMs / (1000 * 60 * 60 * 24)).toInt()
            if (daysSinceStart < 0) daysSinceStart = 0
            
            val currentWirdIndex = json.optInt("currentWirdIndex", 0)
            val notificationType = json.optString("notificationType", "daily")
            
            var passedPeriods = daysSinceStart
            if (notificationType == "prayer") {
                // approximate prayer periods
                val startPrayerOffset = json.optInt("startPrayerOffset", 0)
                val calNow = java.util.Calendar.getInstance()
                val hour = calNow.get(java.util.Calendar.HOUR_OF_DAY)
                var currentPrayerIdx = 0
                if (hour >= 20) currentPrayerIdx = 4
                else if (hour >= 18) currentPrayerIdx = 3
                else if (hour >= 15) currentPrayerIdx = 2
                else if (hour >= 12) currentPrayerIdx = 1
                else currentPrayerIdx = 0
                
                passedPeriods = (daysSinceStart * 5) + currentPrayerIdx - startPrayerOffset
            }
            
            if (passedPeriods < 0) passedPeriods = 0
            val delayedWirds = passedPeriods - currentWirdIndex
            
            if (delayedWirds > 0) return "⚠️ أنت متأخر بمقدار $delayedWirds ورد .. "
            if (delayedWirds < 0) return "🌟 أنت متقدم بمقدار ${-delayedWirds} ورد .. "
            return ""
            
        } catch (e: Exception) {
            e.printStackTrace()
            return ""
        }
    }
}

`

#### android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt
`
        NativeLogger.log(context, "scheduleWird: found ${khatmaEntries.size} khatma entries to process")

        if (khatmaEntries.isEmpty()) {
            NativeLogger.log(context, "scheduleWird: no khatma data found in SharedPreferences — Wird alarms NOT scheduled. Ensure Flutter has run rescheduleWird() at least once.")
        }

        var scheduledCount = 0
        for ((khatmaKey, value) in khatmaEntries) {
            try {
                val json = org.json.JSONObject(value)
                val khatmaId   = json.optString("id", khatmaKey)
                val cleanId    = if (khatmaId.startsWith("khatma_")) khatmaId.removePrefix("khatma_") else khatmaId
                val idBase     = 100000 + (cleanId.hashCode().let { if (it < 0) -it else it } % 40000) * 10

                // Cancel previous alarms for this khatma first to avoid duplicate notifications
                for (c in 0..30) {
                    cancelAlarm(context, editor, idBase + c)
                }

                if (!json.optBoolean("enableNotifications", true)) {
                    NativeLogger.log(context, "scheduleWird: $khatmaKey — notifications disabled, skipping")
                    continue
                }

                val khatmaName = json.optString("name", "الختمة")
                val notifType  = json.optString("notificationType", "daily")
                val offsetMins = json.optInt("notificationOffsetMinutes", 30)

                // Build a full deep-link payload that includes the current wird index + page range
                val wirdsArray   = json.optJSONArray("wirds")
                val wirdIdx      = json.optInt("currentWirdIndex", 0)
                val clampedIdx   = if (wirdsArray != null) wirdIdx.coerceIn(0, wirdsArray.length() - 1) else 0
                val currentWird  = wirdsArray?.optJSONObject(clampedIdx)
                val startPage    = currentWird?.optInt("startPage", 1) ?: 1
                val endPage      = currentWird?.optInt("endPage", 604) ?: 604
                val payload      = "khatma_${cleanId}_${clampedIdx}_${startPage}_${endPage}"
                val pageInfo     = if (currentWird != null) " (ص$startPage–$endPage)" else ""

                NativeLogger.log(context, "scheduleWird: processing '$khatmaName' (type=$notifType, id=$cleanId, idBase=$idBase, payload=$payload)")

                val startDateStr = json.optString("startDate", "")
                val daysSinceStart = getDaysSinceStart(startDateStr)
                val currentWirdIndex = json.optInt("currentWirdIndex", 0)
                val startPrayerOffset = json.optInt("startPrayerOffset", 0)

                if (notifType == "daily") {
                    val timeStr = json.optString("dailyTime", "22:00")
                    val (h, m) = parseTime(timeStr)
                    for (i in 0..2) {
                        val cal = java.util.Calendar.getInstance()
                        cal.set(java.util.Calendar.HOUR_OF_DAY, h)
                        cal.set(java.util.Calendar.MINUTE, m)
                        cal.set(java.util.Calendar.SECOND, 0)
                        cal.set(java.util.Calendar.MILLISECOND, 0)
                        cal.add(java.util.Calendar.DAY_OF_YEAR, i)
                        if (cal.timeInMillis <= now) continue

                        val targetDaysSinceStart = daysSinceStart + i
                        var passedPeriods = targetDaysSinceStart
                        if (passedPeriods < 0) passedPeriods = 0
                        val delayedWirds = passedPeriods - currentWirdIndex
                        val bodyPrefix = if (delayedWirds > 0) "⚠️ أنت متأخر بمقدار $delayedWirds ورد .. "
                                         else if (delayedWirds < 0) "🌟 أنت متقدم بمقدار ${-delayedWirds} ورد .. "
                                         else ""
                        val finalBody = bodyPrefix + "حان وقت وردك اليومي$pageInfo"

                        val scheduledId = idBase + i
                        MainActivity.scheduleAlarmInternal(
                            context, editor, scheduledId,
                            year = cal.get(java.util.Calendar.YEAR),
                            month = cal.get(java.util.Calendar.MONTH) + 1,
                            day = cal.get(java.util.Calendar.DAY_OF_MONTH),
                            hour = h, minute = m,
                            soundName = "ibad_al_rahmann_tone",
                            title = "ورد $khatmaName",
                            body = finalBody,
                            payload = payload,
                            isRepeating = false,
                            audioPath = null,
                            intervalMinutes = 0,
                            customSoundName = "ibad_al_rahmann_tone"
                        )
                        scheduledCount++
                        NativeLogger.log(context, "scheduleWird: scheduled daily wird for '$khatmaName' day+$i at $h:$m (id=$scheduledId)")
                    }
                } else if (notifType == "prayer") {
                    val prayerNames = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
                    for (i in 0..1) {
                        val targetDate = java.util.Date(now + i * 86_400_000L)
                        val times = NativePrayerManager.calculatePrayerTimes(context, targetDate)
                        if (times == null) {
                            NativeLogger.log(context, "scheduleWird: prayer times null for day+$i, skipping")
                            continue
                        }
                        val prayerTimes = arrayOf(
                            times.fajr.time, times.dhuhr.time, times.asr.time,
                            times.maghrib.time, times.isha.time
                        )
                        val dayCal = java.util.Calendar.getInstance()
                        dayCal.time = targetDate
                        for (pIdx in 0..4) {
`

#### android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt
`
package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class BackgroundMethodChannelPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    companion object {
        private const val CHANNEL = "app.ibad_al_rahmann/native_notifications"
        var currentChannel: MethodChannel? = null
        
        // Keep a static reference for MainActivity to use if needed, 
        // though plugin registration is preferred.
        fun setupMethodChannel(context: Context, methodChannel: MethodChannel) {
            val instance = BackgroundMethodChannelPlugin()
            instance.context = context
            instance.channel = methodChannel
            instance.setup(methodChannel)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        currentChannel = channel
        setup(channel!!)
        // Flush any pending navigation payload that arrived before the channel was ready
        val pending = MainActivity.pendingNavigationPayload
        if (pending != null) {
            android.util.Log.d("PrayerApp", "BackgroundPlugin: flushing pending payload '$pending' to Flutter")
            channel!!.invokeMethod("onPayloadReceived", pending)
            MainActivity.pendingNavigationPayload = null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        if (currentChannel == channel) currentChannel = null
        channel = null
    }

    private fun setup(methodChannel: MethodChannel) {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "nativeLog" -> {
                    val message = call.argument<String>("message") ?: ""
                    NativeLogger.log(context, "[Flutter] $message")
                    result.success(null)
                }
                // ── Log helpers ─────────────────────────────────────────────
                "getNativeLog" -> {
                    val lines = call.argument<Int>("lines") ?: 300
                    result.success(NativeLogger.tail(context, lines))
                }
                "clearNativeLog" -> {
                    NativeLogger.clear(context)
                    result.success(null)
                }
                "getNativeLogPath" -> {
                    result.success(NativeLogger.getLogFile(context).absolutePath)
                }
                // ────────────────────────────────────────────────────────────
                "getLaunchPayload" -> {
                    result.success(MainActivity.getAndClearLaunchPayload())
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val intent = Intent(context, AlarmReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    alarmManager.cancel(pendingIntent)
                    context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        .edit().putBoolean("alarm_${id}_active", false).apply()
                    result.success("Canceled")
                }
                "cancelAlarms" -> {
                    val ids = call.argument<List<Int>>("ids")
                    if (ids != null) {
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (id in ids) {
                            val intent = Intent(context, AlarmReceiver::class.java)
                            val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            alarmManager.cancel(pendingIntent)
                            editor.putBoolean("alarm_${id}_active", false)
                            
                            // Cancel legacy flutter_local_notifications if they exist
                            try {
                                val legacyIntent = Intent().setClassName(context, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
                                val legacyPi = PendingIntent.getBroadcast(context, id, legacyIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                                alarmManager.cancel(legacyPi)
                            } catch (e: Exception) {}
                        }
                        editor.apply()
                    }
                    result.success("Batch Canceled")
                }
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val year = call.argument<Int>("year") ?: -1
                    val month = call.argument<Int>("month") ?: -1
                    val day = call.argument<Int>("day") ?: -1
                    val hour = call.argument<Int>("hour") ?: 6
                    val minute = call.argument<Int>("minute") ?: 0
                    val soundName = call.argument<String>("sound") ?: call.argument<String>("soundName") ?: "nafis"
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val payload = call.argument<String>("payload")
                    val audioPath = call.argument<String>("audioPath")
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    val allowedDays = call.argument<String>("allowed_days")
                    
                    val customSoundName = call.argument<String>("custom_sound_name")
                    val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    MainActivity.scheduleAlarmInternal(context, editor, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes, customSoundName, allowedDays)
                    editor.apply()
                    result.success("Scheduled")
                }
                "scheduleAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any>>>("alarms")
                    if (alarms != null) {
                        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (alarm in alarms) {
                            val id = alarm["id"] as? Int ?: continue
                            val year = alarm["year"] as? Int ?: -1
                            val month = alarm["month"] as? Int ?: -1
                            val day = alarm["day"] as? Int ?: -1
                            val hour = alarm["hour"] as? Int ?: 6
                            val minute = alarm["minute"] as? Int ?: 0
                            val soundName = alarm["sound"] as? String ?: alarm["soundName"] as? String ?: "nafis"
                            val title = alarm["title"] as? String
                            val body = alarm["body"] as? String
                            val payload = alarm["payload"] as? String
                            val audioPath = alarm["audioPath"] as? String
                            val intervalMinutes = alarm["intervalMinutes"] as? Int ?: 0
                            val customSoundName = alarm["custom_sound_name"] as? String
                            val allowedDays = alarm["allowed_days"] as? String
                            
                            MainActivity.scheduleAlarmInternal(context, editor, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes, customSoundName, allowedDays)
                        }
                        editor.apply()
                    }
                    result.success("Batch Scheduled")
                }
                "printAllAlarms" -> {
                    val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                    val allEntries = prefs.all
                    val activeAlarms = allEntries.keys.filter { it.endsWith("_active") && prefs.getBoolean(it, false) }
                        .map { it.replace("alarm_", "").replace("_active", "") }
                        
                    val sb = java.lang.StringBuilder()
                    sb.append("--- ALARM AUDIT LOG ---\n")
                    for (id in activeAlarms) {
                        val year = prefs.getInt("alarm_${id}_year", -1)
                        val month = prefs.getInt("alarm_${id}_month", -1)
                        val day = prefs.getInt("alarm_${id}_day", -1)
                        val hour = prefs.getInt("alarm_${id}_hour", -1)
                        val min = prefs.getInt("alarm_${id}_minute", -1)
                        val sound = prefs.getString("alarm_${id}_sound", "default")
                        val payload = prefs.getString("alarm_${id}_payload", "none")
                        val title = prefs.getString("alarm_${id}_title", "No Title")
                        
                        sb.append("ID: $id | Time: $hour:$min | Date: $year-$month-$day | Sound: $sound | Payload: $payload | Title: $title\n")
                    }
                    sb.append("-----------------------\n")
                    NativeLogger.log(context, sb.toString())
                    result.success(sb.toString())
                }
                "updatePrayerNotification" -> {
                    try {
                        val fajr = call.argument<String>("fajr")
                        
                        val intent = Intent(context, PrayerNotificationService::class.java)
                        
                        if (fajr == null) {
                            // Simple sync call
                            intent.action = "SYNC"
                        } else {
                            // Full update call
                            val dhuhr = call.argument<String>("dhuhr")
                            val asr = call.argument<String>("asr")
                            val maghrib = call.argument<String>("maghrib")
                            val isha = call.argument<String>("isha")
                            val nextName = call.argument<String>("nextName")
                            val countdown = call.argument<String>("countdown")
                            val hijri = call.argument<String>("hijri")
                            val prayerIndex = call.argument<Int>("prayerIndex") ?: -1
                            val nextPrayerEpoch = when (val epochArg = call.argument<Any>("nextPrayerEpoch")) {
                                is Long -> epochArg
                                is Int -> epochArg.toLong()
                                is String -> epochArg.toLongOrNull() ?: 0L
                                else -> 0L
                            }
                            val isCountUp = call.argument<Boolean>("isCountUp") ?: false

                            // Persist to SharedPreferences
                            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                            prefs.edit().apply {
                                putString("fajr", fajr)
                                putString("dhuhr", dhuhr)
                                putString("asr", asr)
                                putString("maghrib", maghrib)
                                putString("isha", isha)
                                putString("nextName", nextName)
                                putString("countdown", countdown)
                                putString("hijri", hijri)
                                putInt("prayerIndex", prayerIndex)
                                putLong("next_prayer_time_epoch", nextPrayerEpoch)
                                putBoolean("is_count_up", isCountUp)
                                apply()
                            }

                            intent.action = "UPDATE_PRAYER_NOTIFICATION"
                            intent.putExtra("fajr", fajr)
                            intent.putExtra("dhuhr", dhuhr)
                            intent.putExtra("asr", asr)
                            intent.putExtra("maghrib", maghrib)
                            intent.putExtra("isha", isha)
                            intent.putExtra("nextName", nextName)
                            intent.putExtra("countdown", countdown)
                            intent.putExtra("hijri", hijri)
                            intent.putExtra("prayerIndex", prayerIndex)
                            intent.putExtra("next_prayer_time_epoch", nextPrayerEpoch)
                            intent.putExtra("isCountUp", isCountUp)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try { context.startForegroundService(intent) } catch (e: Exception) { e.printStackTrace() }
                        } else {
                            try { androidx.core.content.ContextCompat.startForegroundService(context, intent) } catch (e: Exception) { e.printStackTrace() }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "stopPrayerNotification" -> {
                    val intent = Intent(context, PrayerNotificationService::class.java).apply {
                        action = "STOP_PRAYER_NOTIFICATION"
                    }
                    try { androidx.core.content.ContextCompat.startForegroundService(context, intent) } catch (e: Exception) { e.printStackTrace() }
                    result.success(null)
                }
                "getLaunchPayload" -> {
                    result.success(MainActivity.getAndClearLaunchPayload())
                }
                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(context.packageName))
                    } else {
                        result.success(true)
                    }
                }
                "checkBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                            val intent = Intent().apply {
                                action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                data = android.net.Uri.parse("package:${context.packageName}")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                        }
                    }
                    result.success(null)
                }
                "vibrate" -> {
                    val duration = call.argument<Int>("duration")?.toLong() ?: 100L
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(duration, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(duration)
                    }
                    result.success(null)
                }
                "simulateTestAdhan" -> {
                    val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val testIntent = Intent(context, AlarmReceiver::class.java).apply {
                        action = "SIMULATE_ADHAN"
                        putExtra("sound_name", "nafis")
                        putExtra("title", "أذان تجريبي")
                        putExtra("body", "هذا أذان تجريبي لاختبار النظام")
                        putExtra("payload", "home")
                    }
                    val pi = PendingIntent.getBroadcast(context, 99999, testIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    val triggerTime = System.currentTimeMillis() + 60000L // 60 seconds
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pi)
                    } else {
                        am.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pi)
                    }
                    result.success("تمت جدولة أذان تجريبي بعد 60 ثانية")
                }
                "generateThirtyDayCache" -> {
                    // Run in background to not block UI
                    Thread {
                        NativePrayerManager.generateThirtyDayCache(context)
                    }.start()
                    result.success("Cache generation started")
                }
                "startNativePrayerEngine" -> {
                    // Delegate prayer alarm scheduling entirely to native; safe to call on every app open
                    Thread {
                        try {
                            NativePrayerManager.generateThirtyDayCache(context)
                            NativePrayerScheduler.scheduleToday(context)
                        } catch (e: Exception) { e.printStackTrace() }
                    }.start()
                    result.success("Native prayer engine started")
                }
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        android.provider.Settings.canDrawOverlays(context)
                    } else { true }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(
                        android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:${context.packageName}")
                    ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
                    context.startActivity(intent)
                    result.success(null)
                }
                "setPrayerFocusEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        .edit().putBoolean("flutter.prayer_focus_enabled", enabled).apply()
                    result.success(null)
                }
                "showFocusOverlayPreview" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "العصر"
                    val alarmId = call.argument<Int>("alarmId") ?: 102
                    PrayerFocusOverlay.show(context, prayerName, alarmId, isPreview = true)
                    result.success(true)
                }
                "startScreenUnlockService" -> {
                    val mode   = call.argument<String>("mode")   ?: "saly_3ala_mo7amad"
                    val volume = call.argument<Double>("volume") ?: 1.0
                    val prefs  = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("flutter.salah_unlock_mode",   mode)
                        .putString("salah_unlock_mode",   mode)
                        .putFloat("flutter.salah_unlock_volume",  volume.toFloat())
                        .putFloat("salah_unlock_volume",  volume.toFloat())
                        .apply()

                    NativeLogger.log(context, "startScreenUnlockService called: mode=$mode, volume=$volume")
                    result.success(null)
                }
                "stopScreenUnlockService" -> {
                    val prefs  = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("flutter.salah_unlock_mode", "none")
                        .putString("salah_unlock_mode", "none")
                        .apply()
                    NativeLogger.log(context, "stopScreenUnlockService called")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

`

### 3. New Files Locally (Not in Repo)
`
.ai_plans/
lib/screens/hijri_confirmation_screen.dart
lib/services/hijri_source_service.dart
`
