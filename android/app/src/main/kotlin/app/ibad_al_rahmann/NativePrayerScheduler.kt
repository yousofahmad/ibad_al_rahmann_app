package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Date

/**
 * Native Prayer Scheduler — the single source of truth for scheduling
 * all 5 daily Adhans, Pre-Adhans, and Iqamas via AlarmManager.setAlarmClock().
 *
 * Runs 100% natively — fires even if the Flutter engine is completely dead.
 * Called on: device boot, midnight refresh (alarm 9999), and app open via
 * the startNativePrayerEngine MethodChannel.
 *
 * Audio / volume logic is not touched here.
 */
object NativePrayerScheduler {

    // Today's alarm IDs — must match Flutter's existing ID scheme exactly
    private val PRAYER_IDS  = intArrayOf(100, 102, 103, 104, 105) // Fajr, Dhuhr, Asr, Maghrib, Isha
    private val PRE_IDS     = intArrayOf(3000, 3001, 3002, 3003, 3004)
    private val IQAMA_IDS   = intArrayOf(5000, 5001, 5002, 5003, 5004)
    // Tomorrow's Fajr uses ID 110 (matches Flutter: 100 + 0 + 10)

    private val PRAYER_NAMES_AR = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
    private val PRAYER_NAMES_EN = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

    /**
     * Main entry point. Reads user settings from FlutterSharedPreferences,
     * calculates today's prayer times via NativePrayerManager, and schedules
     * all alarms using setAlarmClock(). Safe to call repeatedly —
     * FLAG_UPDATE_CURRENT replaces existing alarms without creating duplicates.
     */
    fun scheduleToday(context: Context) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now          = System.currentTimeMillis()

        var todayEpochs: LongArray? = null
        var tomorrowFajrEpoch: Long? = null

        NativeLogger.log(context, "--- Starting scheduleToday ---")

        // Try to calculate natively first (highest priority and freshest)
        try {
            val todayTimes = NativePrayerManager.calculatePrayerTimes(context, Date())
            if (todayTimes != null) {
                NativeLogger.log(context, "Native calculation SUCCESS for today.")
                todayEpochs = longArrayOf(
                    todayTimes.fajr.time,
                    todayTimes.dhuhr.time,
                    todayTimes.asr.time,
                    todayTimes.maghrib.time,
                    todayTimes.isha.time
                )
                val tomorrowTimes = NativePrayerManager.calculatePrayerTimes(context, Date(now + 86_400_000L))
                if (tomorrowTimes != null) {
                    tomorrowFajrEpoch = tomorrowTimes.fajr.time
                }
            } else {
                NativeLogger.log(context, "Native calculation FAILED (returned null).")
            }
        } catch (e: Exception) {
            NativeLogger.log(context, "Native calculation EXCEPTION: ${e.message}")
            e.printStackTrace()
        }

        // Fallback to Flutter's 30-day cache
        if (todayEpochs == null) {
            NativeLogger.log(context, "Attempting Fallback to 30-day cache...")
            todayEpochs = getEpochsFromCache(context, Date())
            if (todayEpochs != null) {
                NativeLogger.log(context, "Fallback SUCCESS for today.")
            } else {
                NativeLogger.log(context, "Fallback FAILED. No cache found.")
            }
        }
        if (tomorrowFajrEpoch == null) {
            val tomEpochs = getEpochsFromCache(context, Date(now + 86_400_000L))
            if (tomEpochs != null) tomorrowFajrEpoch = tomEpochs[0]
        }

        if (todayEpochs == null) {
            NativeLogger.log(context, "CRITICAL ERROR: Both Native and Cache failed. Aborting scheduling.")
            return // Complete failure, no data available
        }

        val globalDefault = flutterPrefs.getString("flutter.adhan_muezzin_id", "nafis") ?: "nafis"
        val adhanDirPath = context.getDir("flutter", Context.MODE_PRIVATE).absolutePath + "/adhan/"
        
        var scheduledCount = 0

        for (i in 0..4) {
            var engName = PRAYER_NAMES_EN[i]
            var arName  = PRAYER_NAMES_AR[i]
            var payload = "prayer"
            val epoch   = todayEpochs[i]

            // Jumuah Check: If it's Dhuhr and today is Friday
            val calendar = java.util.Calendar.getInstance()
            calendar.timeInMillis = epoch
            if (i == 1 && calendar.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY) {
                engName = "Jumuah"
                arName = "الجمعة"
                payload = "jumuah"
            }

            val adhanBody = when (engName) {
                "Fajr" -> "من صلى الفجر في جماعة فهو في ذمة الله"
                "Dhuhr" -> "لا تجعل عملك يلهيك عن أداء الصلاة"
                "Jumuah" -> "فيه ساعة لا يوافقها عبد مسلم يسأل الله شيئا إلا أعطاه إياه"
                "Asr" -> "حافظوا على الصلوات والصلاة الوسطى"
                "Maghrib" -> "لا يزال الناس بخير ما عجلوا الفطر"
                "Isha" -> "صلاة العشاء في جماعة كقيام نصف الليل"
                else -> "حان موعد صلاة $arName"
            }

            val iqamaBody = if (engName == "Fajr") "تقام الآن صلاة الفجر .. أفلح من صلى" else "تقام الآن صلاة $arName .. استووا واعتدلوا"
            val preBody = "الدعاء لا يرد بين الأذان والإقامة .. استعد للصلاة"

            // ── ADHAN ─────────────────────────────────────────────────────────
            val adhanMode = flutterPrefs.getString("flutter.adhan_mode_$engName", null)
                ?: if (flutterPrefs.getBoolean("flutter.notif_prayer_${engName.lowercase()}", true)) "sound" else "none"
            if (adhanMode != "none") {
                val sound = flutterPrefs.getString("flutter.adhan_sound_$engName", null) ?: globalDefault
                scheduleSingleAlarm(
                    context, alarmManager,
                    id              = PRAYER_IDS[i],
                    epochMs         = epoch,
                    title           = "أذان $arName",
                    body            = adhanBody,
                    soundName       = if (adhanMode == "silent_notif") "silent_notif" else sound,
                    customSoundName = sound,
                    payload         = payload,
                    audioPath       = adhanDirPath + sound + ".mp3"
                )
                scheduledCount++
            }

            // ── PRE-PRAYER ─────────────────────────────────────────────────────
            val preMode = flutterPrefs.getString("flutter.pre_mode_$engName", null)
                ?: if (flutterPrefs.getBoolean("flutter.notif_pre_$engName", false)) "sound" else "none"
            if (preMode != "none") {
                val preMins  = getSafeInt(flutterPrefs, "flutter.time_pre_$engName", 15)
                val preEpoch = epoch - (preMins * 60_000L)
                if (preEpoch > now) {
                    val defaultPreSound = "pre_${engName.lowercase()}"
                    val preSound = flutterPrefs.getString("flutter.pre_sound_$engName", null)
                        ?.takeIf { it.isNotBlank() }
                        ?: defaultPreSound
                    scheduleSingleAlarm(
                        context, alarmManager,
                        id              = PRE_IDS[i],
                        epochMs         = preEpoch,
                        title           = "تنبيه $arName",
                        body            = preBody,
                        soundName       = if (preMode == "silent_notif") "silent_notif" else preSound,
                        customSoundName = preSound,
                        payload         = payload,
                        audioPath       = null
                    )
                    scheduledCount++
                }
            }

            // ── IQAMA ──────────────────────────────────────────────────────────
            val iqamaModeFallback = if (flutterPrefs.getBoolean("flutter.iqama_enabled_$engName", false)) "sound" else "none"
            val iqamaMode = flutterPrefs.getString("flutter.iqama_mode_$engName", null) ?: iqamaModeFallback
            
            if (iqamaMode != "none") {
                val iqamaMins  = getSafeInt(flutterPrefs, "flutter.iqama_minutes_$engName", 15)
                val iqamaEpoch = epoch + (iqamaMins * 60_000L)
                if (iqamaEpoch > now) {
                    val iqamaSound = flutterPrefs.getString("flutter.iqama_sound_$engName", "iqama") ?: "iqama"
                    scheduleSingleAlarm(
                        context, alarmManager,
                        id              = IQAMA_IDS[i],
                        epochMs         = iqamaEpoch,
                        title           = "إقامة $arName",
                        body            = iqamaBody,
                        soundName       = if (iqamaMode == "silent_notif") "silent_notif" else iqamaSound,
                        customSoundName = iqamaSound,
                        payload         = payload,
                        audioPath       = null
                    )
                    scheduledCount++
                }
            }
        }

        // ── TOMORROW'S FAJR — guarantees midnight continuity ──────────────────
        if (tomorrowFajrEpoch != null) {
            val tFajrMode = flutterPrefs.getString("flutter.adhan_mode_Fajr", null)
                ?: if (flutterPrefs.getBoolean("flutter.notif_prayer_fajr", true)) "sound" else "none"
            if (tFajrMode != "none") {
                val sound = flutterPrefs.getString("flutter.adhan_sound_Fajr", null) ?: globalDefault
                scheduleSingleAlarm(
                    context, alarmManager,
                    id              = 110,
                    epochMs         = tomorrowFajrEpoch,
                    title           = "أذان الفجر",
                    body            = "حان موعد صلاة الفجر",
                    soundName       = if (tFajrMode == "silent_notif") "silent_notif" else sound,
                    customSoundName = sound,
                    payload         = "prayer",
                    audioPath       = adhanDirPath + sound + ".mp3"
                )
                scheduledCount++
            }
        }

        NativeLogger.log(context, "Completed scheduleToday. Successfully scheduled $scheduledCount alarms.")
    }

        /**
     * Schedules a single alarm using setAlarmClock() — pierces Doze mode completely.
     * FLAG_UPDATE_CURRENT cancels the existing alarm for this ID before setting the new one.
     * Also persists metadata to AzkarNativePrefs so the boot-reschedule chain is maintained.
     */
    private fun scheduleSingleAlarm(
        context: Context,
        alarmManager: AlarmManager,
        id: Int,
        epochMs: Long,
        title: String,
        body: String,
        soundName: String,
        customSoundName: String?,
        payload: String,
        audioPath: String? = null
    ) {
        val now = System.currentTimeMillis()
        // Skip alarms that are in the past to prevent immediate firing
        if (epochMs <= now) return

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("alarm_id",          id)
            putExtra("title",             title)
            putExtra("body",              body)
            putExtra("sound_name",        soundName)
            putExtra("custom_sound_name", customSoundName)
            putExtra("payload",           payload)
            if (audioPath != null) putExtra("audio_path", audioPath)
        }

        val pi = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // setAlarmClock is the most reliable trigger on Android — shows clock icon in status bar
        // and is exempt from Doze mode restrictions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(epochMs, pi), pi)
        } else {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
        }

        // Persist so the boot-reschedule chain knows this alarm was active
        context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE).edit().apply {
            putBoolean("alarm_${id}_active",      true)
            putString("alarm_${id}_sound",        soundName)
            putString("alarm_${id}_title",        title)
            putString("alarm_${id}_body",         body)
            putString("alarm_${id}_payload",      payload)
            if (customSoundName != null) putString("alarm_${id}_custom_sound", customSoundName)
            apply()
        }
    }

    /**
     * Safely reads an Int stored by Flutter's shared_preferences package.
     * Flutter persists int values as Long on Android, so we must handle both types.
     */
    private fun getSafeInt(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        return when (val v = prefs.all[key]) {
            is Long   -> v.toInt()
            is Int    -> v
            is Float  -> v.toInt()
            is String -> v.toIntOrNull() ?: default
            else      -> default
        }
    }

    private fun getEpochsFromCache(context: Context, date: Date): LongArray? {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonStr = prefs.getString("prayer_times_30d", null) ?: return null
            val root = org.json.JSONObject(jsonStr)
            val dateKey = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(date)
            if (root.has(dateKey)) {
                val dayObj = root.getJSONObject(dateKey)
                return longArrayOf(
                    dayObj.getLong("f"),
                    dayObj.getLong("d"),
                    dayObj.getLong("a"),
                    dayObj.getLong("m"),
                    dayObj.getLong("i")
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
