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
    private val PRAYER_IDS  = intArrayOf(100, 101, 102, 103, 104) // Fajr, Dhuhr, Asr, Maghrib, Isha
    private val PRE_IDS     = intArrayOf(3000, 3001, 3002, 3003, 3004)
    private val IQAMA_IDS   = intArrayOf(5000, 5001, 5002, 5003, 5004)
    // Tomorrow's Fajr uses ID 110 (matches Flutter: 100 + 0 + 10)

    private val PRAYER_NAMES_AR = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
    private val PRAYER_NAMES_EN = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

    // Debounce: prevent storm of concurrent scheduleToday calls (e.g. on app open)
    @Volatile private var lastScheduleMs = 0L
    private const val DEBOUNCE_MS = 12_000L // 12 seconds minimum between calls
    private val scheduleLock = Any()

    /**
     * Main entry point. Reads user settings from FlutterSharedPreferences,
     * calculates today's prayer times via NativePrayerManager, and schedules
     * all alarms using setAlarmClock(). Safe to call repeatedly —
     * FLAG_UPDATE_CURRENT replaces existing alarms without creating duplicates.
     *
     * Debounced: rapid consecutive calls within 12s are ignored to prevent the
     * scheduling storm that causes app freezes and double notifications.
     */
    fun scheduleToday(context: Context) {
        val now = System.currentTimeMillis()
        synchronized(scheduleLock) {
            if (now - lastScheduleMs < DEBOUNCE_MS) {
                NativeLogger.log(context, "scheduleToday: debounced (${now - lastScheduleMs}ms since last call, min=${DEBOUNCE_MS}ms)")
                return
            }
            lastScheduleMs = now
        }
        _scheduleTodayInternal(context)
    }

    private fun _scheduleTodayInternal(context: Context) {
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
                    todayTimes.isha.time,
                    todayTimes.sunrise.time
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

        // Pre-calculate tomorrow's epochs — used as fallback when today's prayer already passed
        val tomorrowEpochsFallback: LongArray? = try {
            val tomDate = java.util.Date(now + 86_400_000L)
            val tomTimes = NativePrayerManager.calculatePrayerTimes(context, tomDate)
            if (tomTimes != null) longArrayOf(
                tomTimes.fajr.time, tomTimes.dhuhr.time, tomTimes.asr.time,
                tomTimes.maghrib.time, tomTimes.isha.time
            ) else getEpochsFromCache(context, tomDate)
        } catch (e: Exception) { null }

        for (i in 0..4) {
            val todayEpochRaw = (todayEpochs[i] / 60_000L) * 60_000L
            val tomEpochRaw = tomorrowEpochsFallback?.getOrNull(i)?.let { (it / 60_000L) * 60_000L }

            val candidates = listOfNotNull(todayEpochRaw, tomEpochRaw)
            
            var adhanScheduled = false
            var preScheduled = false
            var iqamaScheduled = false

            for (epoch in candidates) {
                var engName = PRAYER_NAMES_EN[i]
                var arName  = PRAYER_NAMES_AR[i]
                var payload = "prayer"

                // Jumuah Check: If it's Dhuhr and the epoch is Friday
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
                if (!adhanScheduled && epoch > now) {
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
                        
                        // ── التذكير المبكر قبل الأذان (overlay فقط) ─────────────────
                        val preAdhanReminderMins = getSafeInt(flutterPrefs, "flutter.pre_adhan_reminder_minutes", 0)
                        if (preAdhanReminderMins > 0) {
                            val preAdhanEpoch = epoch - (preAdhanReminderMins * 60_000L)
                            if (preAdhanEpoch > now) {
                                scheduleSingleAlarm(
                                    context, alarmManager,
                                    id              = 6000 + i,
                                    epochMs         = preAdhanEpoch,
                                    title           = "تذكير صلاة $arName",
                                    body            = "باقي $preAdhanReminderMins دقيقة على أذان $arName",
                                    soundName       = "silent_notif",
                                    customSoundName = null,
                                    payload         = "prayer",
                                    audioPath       = null
                                )
                                scheduledCount++
                            }
                        } else {
                            cancelSingleAlarm(context, alarmManager, 6000 + i)
                        }
                    } else {
                        cancelSingleAlarm(context, alarmManager, PRAYER_IDS[i])
                        cancelSingleAlarm(context, alarmManager, 6000 + i)
                    }
                    adhanScheduled = true
                }

                // ── PRE-PRAYER ─────────────────────────────────────────────────────
                val preMins  = getSafeInt(flutterPrefs, "flutter.time_pre_$engName", 15)
                val preEpoch = epoch - (preMins * 60_000L)
                if (!preScheduled && preEpoch > now) {
                    val preMode = flutterPrefs.getString("flutter.pre_mode_$engName", null)
                        ?: if (flutterPrefs.getBoolean("flutter.notif_pre_$engName", false)) "sound" else "none"
                    if (preMode != "none") {
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
                    } else {
                        cancelSingleAlarm(context, alarmManager, PRE_IDS[i])
                    }
                    preScheduled = true
                }

                // ── IQAMA ──────────────────────────────────────────────────────────
                val iqamaMins  = getSafeInt(flutterPrefs, "flutter.iqama_minutes_$engName", 15)
                val iqamaEpoch = epoch + (iqamaMins * 60_000L)
                if (!iqamaScheduled && iqamaEpoch > now) {
                    val iqamaModeFallback = if (flutterPrefs.getBoolean("flutter.iqama_enabled_$engName", false)) "sound" else "none"
                    val iqamaMode = flutterPrefs.getString("flutter.iqama_mode_$engName", null) ?: iqamaModeFallback
                    if (iqamaMode != "none") {
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
                    } else {
                        cancelSingleAlarm(context, alarmManager, IQAMA_IDS[i])
                    }
                    iqamaScheduled = true
                }
            }
        }

        // ── TOMORROW'S FAJR — guarantees midnight continuity ──────────────────
        if (tomorrowFajrEpoch != null) {
            val tFajrMode = flutterPrefs.getString("flutter.adhan_mode_Fajr", null)
                ?: if (flutterPrefs.getBoolean("flutter.notif_prayer_fajr", true)) "sound" else "none"
            if (tFajrMode != "none") {
                val sound = flutterPrefs.getString("flutter.adhan_sound_Fajr", null) ?: globalDefault
                val epoch = (tomorrowFajrEpoch / 60_000L) * 60_000L
                scheduleSingleAlarm(
                    context, alarmManager,
                    id              = 110,
                    epochMs         = epoch,
                    title           = "أذان الفجر",
                    body            = "حان موعد صلاة الفجر",
                    soundName       = if (tFajrMode == "silent_notif") "silent_notif" else sound,
                    customSoundName = sound,
                    payload         = "prayer",
                    audioPath       = adhanDirPath + sound + ".mp3"
                )
                scheduledCount++
            } else {
                cancelSingleAlarm(context, alarmManager, 110)
            }
        }

        // ── SUNRISE (الشروق) ───────────────────────────────────────────────
        val todaySunriseEpoch = if (todayEpochs.size >= 6) todayEpochs[5] else null
        if (todaySunriseEpoch != null) {
            val sunriseMode = flutterPrefs.getString("flutter.sunrise_mode", null)
                ?: if (flutterPrefs.getBoolean("flutter.notif_sunrise", true)) "sound" else "none"
            val sunriseEpochMs = (todaySunriseEpoch / 60_000L) * 60_000L
            if (sunriseMode != "none") {
                if (sunriseEpochMs > now) {
                    // Today's shurooq hasn't happened yet → schedule it
                    scheduleSingleAlarm(
                        context, alarmManager,
                        id              = 736,
                        epochMs         = sunriseEpochMs,
                        title           = "الشروق",
                        body            = "حان موعد الشروق",
                        soundName       = if (sunriseMode == "silent_notif") "silent_notif" else "time_shurooq",
                        customSoundName = "time_shurooq",
                        payload         = "home",
                        audioPath       = null
                    )
                    scheduledCount++
                } else {
                    // Today's shurooq already passed → schedule tomorrow's using cache
                    val tomorrowDate = Date(now + 86_400_000L)
                    val tomorrowEpochs = getEpochsFromCache(context, tomorrowDate)
                    val tomorrowSunriseMs = if (tomorrowEpochs != null && tomorrowEpochs.size >= 6)
                        (tomorrowEpochs[5] / 60_000L) * 60_000L else null
                    if (tomorrowSunriseMs != null && tomorrowSunriseMs > now) {
                        scheduleSingleAlarm(
                            context, alarmManager,
                            id              = 736,
                            epochMs         = tomorrowSunriseMs,
                            title           = "الشروق",
                            body            = "حان موعد الشروق",
                            soundName       = if (sunriseMode == "silent_notif") "silent_notif" else "time_shurooq",
                            customSoundName = "time_shurooq",
                            payload         = "home",
                            audioPath       = null
                        )
                        scheduledCount++
                    }
                }
            } else {
                cancelSingleAlarm(context, alarmManager, 736)
            }

            // ── DUHA (الضحى) ────────────────────────────────────────────────
            val duhaModeNotif = flutterPrefs.getString("flutter.duha_mode_notif", "none") ?: "none"
            if (duhaModeNotif != "none") {
                val mode = flutterPrefs.getString("flutter.duha_mode", "start") ?: "start"
                val duhaTimeMs = when (mode) {
                    "start" -> sunriseEpochMs + (15 * 60_000L)
                    "mid" -> sunriseEpochMs + ((todayEpochs[1] - sunriseEpochMs) / 2) // Halfway to Dhuhr (todayEpochs[1])
                    "after_mins" -> {
                        val mins = getSafeInt(flutterPrefs, "flutter.duha_custom_minutes", 15)
                        sunriseEpochMs + (mins * 60_000L)
                    }
                    "before_dhuhr_mins" -> {
                        val mins = getSafeInt(flutterPrefs, "flutter.duha_custom_minutes", 15)
                        todayEpochs[1] - (mins * 60_000L)
                    }
                    else -> sunriseEpochMs + (15 * 60_000L)
                }

                if (duhaTimeMs > now) {
                    scheduleSingleAlarm(
                        context, alarmManager,
                        id              = 732,
                        epochMs         = (duhaTimeMs / 60_000L) * 60_000L,
                        title           = "صلاة الضحى",
                        body            = "صلاة الأوابين",
                        soundName       = if (duhaModeNotif == "silent_notif") "silent_notif" else "time_duha",
                        customSoundName = "time_duha",
                        payload         = "home",
                        audioPath       = null
                    )
                    scheduledCount++
                } else {
                    // Today's Duha already passed → schedule tomorrow's Duha
                    val tomorrowDate = Date(now + 86_400_000L)
                    val tomorrowEpochs = getEpochsFromCache(context, tomorrowDate)
                    val tomorrowSunriseMs = if (tomorrowEpochs != null && tomorrowEpochs.size >= 6) (tomorrowEpochs[5] / 60_000L) * 60_000L else null
                    if (tomorrowSunriseMs != null) {
                        val tomorrowDhuhrMs = tomorrowEpochs!![1]
                        val tomorrowDuhaTimeMs = when (mode) {
                            "start" -> tomorrowSunriseMs + (15 * 60_000L)
                            "mid" -> tomorrowSunriseMs + ((tomorrowDhuhrMs - tomorrowSunriseMs) / 2)
                            "after_mins" -> {
                                val mins = getSafeInt(flutterPrefs, "flutter.duha_custom_minutes", 15)
                                tomorrowSunriseMs + (mins * 60_000L)
                            }
                            "before_dhuhr_mins" -> {
                                val mins = getSafeInt(flutterPrefs, "flutter.duha_custom_minutes", 15)
                                tomorrowDhuhrMs - (mins * 60_000L)
                            }
                            else -> tomorrowSunriseMs + (15 * 60_000L)
                        }
                        if (tomorrowDuhaTimeMs > now) {
                            scheduleSingleAlarm(
                                context, alarmManager,
                                id              = 732,
                                epochMs         = (tomorrowDuhaTimeMs / 60_000L) * 60_000L,
                                title           = "صلاة الضحى",
                                body            = "صلاة الأوابين",
                                soundName       = if (duhaModeNotif == "silent_notif") "silent_notif" else "time_duha",
                                customSoundName = "time_duha",
                                payload         = "home",
                                audioPath       = null
                            )
                            scheduledCount++
                        }
                    }
                }
            } else {
                cancelSingleAlarm(context, alarmManager, 732)
            }
        }

        if (todayEpochs.size >= 5 && tomorrowFajrEpoch != null) {
            try {
                NativeEventScheduler.scheduleEvents(context, todayEpochs, tomorrowFajrEpoch)
                NativeLogger.log(context, "Successfully scheduled NativeEventScheduler alarms.")
            } catch (e: Exception) {
                NativeLogger.log(context, "Exception scheduling NativeEventScheduler alarms: ${e.message}")
            }
        }

        NativeLogger.log(context, "Completed scheduleToday. Successfully scheduled $scheduledCount alarms.")
    }

        /**
     * Schedules a single alarm using setAlarmClock() — pierces Doze mode completely.
     * FLAG_UPDATE_CURRENT cancels the existing alarm for this ID before setting the new one.
     * Also persists metadata to AzkarNativePrefs so the boot-reschedule chain is maintained.
     */
    fun scheduleSingleAlarm(
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

        // Cancel any legacy flutter_local_notifications alarms with the same ID
        try {
            val legacyIntent = Intent().setClassName(context, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
            val legacyPi = PendingIntent.getBroadcast(context, id, legacyIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            alarmManager.cancel(legacyPi)
        } catch (e: Exception) {}

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

    private fun cancelSingleAlarm(context: Context, alarmManager: AlarmManager, id: Int) {
        try {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            alarmManager.cancel(pi)
            
            // Also cancel legacy
            val legacyIntent = Intent().setClassName(context, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
            val legacyPi = PendingIntent.getBroadcast(context, id, legacyIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            alarmManager.cancel(legacyPi)
            
            context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE).edit().apply {
                remove("alarm_${id}_active")
                apply()
            }
        } catch (e: Exception) {}
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
                    dayObj.getLong("i"),
                    dayObj.getLong("s")
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
