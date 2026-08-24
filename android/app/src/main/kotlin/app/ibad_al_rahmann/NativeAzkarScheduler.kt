package app.ibad_al_rahmann

import android.content.Context
import android.content.SharedPreferences

/**
 * Native Azkar Scheduler — reschedules morning/evening Azkar and Ruqyah after device reboot.
 *
 * Flutter schedules IDs 1-5 but they are lost on reboot.
 * This reads the user settings from FlutterSharedPreferences and recreates those alarms
 * natively so they fire even if the Flutter engine never runs after boot.
 *
 * IDs:
 *  1 → أذكار الصباح (sound: sabah)
 *  3 → أذكار المساء (sound: masaa)
 *  4 → الرقية (morning time, silent)
 *  5 → الرقية (evening time, silent)
 */
object NativeAzkarScheduler {

    fun scheduleAzkar(context: Context) {
        val fp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // ── أذكار الصباح (ID 1) ──────────────────────────────────────────────
        val morningMode = fp.getString("flutter.azkar_morning_mode", "sound") ?: "sound"
        if (morningMode != "none") {
            val timeStr = fp.getString("flutter.time_azkar_morning", "06:00") ?: "06:00"
            val (mH, mM) = parseTime(timeStr)
            val sound = if (morningMode == "silent_notif") "silent_notif" else "sabah"
            scheduleDaily(
                context, editor, id = 1,
                hour = mH, minute = mM,
                title = "أذكار الصباح", body = "حان موعد أذكار الصباح",
                sound = sound, customSound = "sabah", payload = "sabah"
            )

            // ── الرقية صباحاً (ID 4) — صامتة دائماً ────────────────────
            val ruqyahEnabled = safeBool(fp, "flutter.azkar_ruqyah_enabled", false)
            if (ruqyahEnabled) {
                scheduleDaily(
                    context, editor, id = 4,
                    hour = mH, minute = mM,
                    title = "الرقية الشرعية", body = "لا تنس قراءة الرقية الشرعية صباحًا",
                    sound = "silent_notif", customSound = null, payload = "ruqyah"
                )
            } else {
                cancelAlarm(context, editor, 4)
            }
        } else {
            cancelAlarm(context, editor, 1)
            cancelAlarm(context, editor, 4)
        }

        // ── أذكار المساء (ID 3) ──────────────────────────────────────────────
        val eveningMode = fp.getString("flutter.azkar_evening_mode", "sound") ?: "sound"
        if (eveningMode != "none") {
            val timeStr = fp.getString("flutter.time_azkar_evening", "17:00") ?: "17:00"
            val (eH, eM) = parseTime(timeStr)
            val sound = if (eveningMode == "silent_notif") "silent_notif" else "masaa"
            scheduleDaily(
                context, editor, id = 3,
                hour = eH, minute = eM,
                title = "أذكار المساء", body = "حان موعد أذكار المساء",
                sound = sound, customSound = "masaa", payload = "masaa"
            )

            // ── الرقية مساءً (ID 5) — صامتة دائماً ────────────────────
            val ruqyahEnabled = safeBool(fp, "flutter.azkar_ruqyah_enabled", false)
            if (ruqyahEnabled) {
                scheduleDaily(
                    context, editor, id = 5,
                    hour = eH, minute = eM,
                    title = "الرقية الشرعية", body = "لا تنس قراءة الرقية الشرعية مساءً",
                    sound = "silent_notif", customSound = null, payload = "ruqyah"
                )
            } else {
                cancelAlarm(context, editor, 5)
            }
        } else {
            cancelAlarm(context, editor, 3)
            cancelAlarm(context, editor, 5)
        }

        editor.apply()

        // ── ورد الختمة (Khatma Wird notifications) ──────────────────────────
        // These are scheduled from Dart but lost on reboot. We reschedule them natively here.
        scheduleWird(context)
    }

    /**
     * Reads all KhatmaModel entries and schedules their Wird notifications natively.
     * Looks in TWO places:
     *  1. Regular SharedPreferences: key = "khatma_<id>" (written as mirror by Flutter's rescheduleWird)
     *  2. FlutterSharedPreferences:  key = "flutter.khatma_<id>" (legacy / direct Flutter writes)
     * Called after every reboot / scheduleAzkar call.
     */
    fun scheduleWird(context: Context) {
        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        val now = System.currentTimeMillis()

        // Collect all khatma entries from both sources
        val khatmaEntries = mutableMapOf<String, String>() // cleanKey -> json

        // Source 1: FlutterSharedPreferences - handles both flutter.khatma_ and plain khatma_ keys
        val spFlutter = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        for ((key, value) in spFlutter.all) {
            val cleanKey = if (key.startsWith("flutter.")) key.removePrefix("flutter.") else key
            if (cleanKey.startsWith("khatma_") && value is String) {
                khatmaEntries[cleanKey] = value
            }
        }
        // Source 2: AzkarNativePrefs (written directly by native mirror logic)
        val spPlain = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        for ((key, value) in spPlain.all) {
            if (key.startsWith("khatma_") && value is String) {
                if (!khatmaEntries.containsKey(key)) khatmaEntries[key] = value
            }
        }

        NativeLogger.log(context, "scheduleWird: found ${khatmaEntries.size} khatma entries to process")

        if (khatmaEntries.isEmpty()) {
            NativeLogger.log(context, "scheduleWird: no khatma data found in SharedPreferences — Wird alarms NOT scheduled. Ensure Flutter has run rescheduleWird() at least once.")
        }

        var scheduledCount = 0
        for ((khatmaKey, value) in khatmaEntries) {
            try {
                val json = org.json.JSONObject(value)
                if (!json.optBoolean("enableNotifications", true)) {
                    NativeLogger.log(context, "scheduleWird: $khatmaKey — notifications disabled, skipping")
                    continue
                }

                val khatmaName = json.optString("name", "الختمة")
                val notifType  = json.optString("notificationType", "daily")
                val offsetMins = json.optInt("notificationOffsetMinutes", 30)
                val khatmaId   = json.optString("id", khatmaKey)
                val cleanId    = if (khatmaId.startsWith("khatma_")) khatmaId.removePrefix("khatma_") else khatmaId
                val idBase     = 100000 + (cleanId.hashCode().let { if (it < 0) -it else it } % 40000) * 10

                // Build a full deep-link payload that includes the current wird index + page range
                // so handleGlobalNavigation() opens IsolatedWirdScreen directly on the right pages
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

                        val scheduledId = idBase + cal.get(java.util.Calendar.DAY_OF_WEEK)
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
                            val pEpoch = prayerTimes[pIdx] + offsetMins * 60_000L
                            if (pEpoch <= now) continue

                            val targetDaysSinceStart = daysSinceStart + i
                            var passedPeriods = (targetDaysSinceStart * 5 + pIdx - startPrayerOffset)
                            if (passedPeriods < 0) passedPeriods = 0
                            val delayedWirds = passedPeriods - currentWirdIndex
                            val bodyPrefix = if (delayedWirds > 0) "⚠️ أنت متأخر بمقدار $delayedWirds ورد .. "
                                             else if (delayedWirds < 0) "🌟 أنت متقدم بمقدار ${-delayedWirds} ورد .. "
                                             else ""
                            val finalBody = bodyPrefix + "حان وقت وردك بعد صلاة ${prayerNames[pIdx]}"

                            val pCal = java.util.Calendar.getInstance()
                            pCal.timeInMillis = pEpoch
                            val scheduledId = idBase + (dayCal.get(java.util.Calendar.DAY_OF_WEEK) * 10) + pIdx
                            MainActivity.scheduleAlarmInternal(
                                context, editor, scheduledId,
                                year = pCal.get(java.util.Calendar.YEAR),
                                month = pCal.get(java.util.Calendar.MONTH) + 1,
                                day = pCal.get(java.util.Calendar.DAY_OF_MONTH),
                                hour = pCal.get(java.util.Calendar.HOUR_OF_DAY),
                                minute = pCal.get(java.util.Calendar.MINUTE),
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
                        }
                    }
                    NativeLogger.log(context, "scheduleWird: scheduled prayer-based wird for '$khatmaName'")
                }
            } catch (e: Exception) {
                NativeLogger.log(context, "scheduleWird: ERROR processing $khatmaKey — ${e.message}")
            }
        }
        editor.apply()
        NativeLogger.log(context, "scheduleWird: DONE. Scheduled $scheduledCount wird alarms total.")
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private fun scheduleDaily(
        context: Context,
        editor: SharedPreferences.Editor,
        id: Int,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        sound: String,
        customSound: String?,
        payload: String
    ) {
        // year=-1, month=-1, day=-1 tells scheduleAlarmInternal this is a daily alarm
        MainActivity.scheduleAlarmInternal(
            context, editor, id,
            year = -1, month = -1, day = -1,
            hour = hour, minute = minute,
            soundName = sound,
            title = title, body = body, payload = payload,
            isRepeating = false,
            audioPath = null,
            intervalMinutes = 0,
            customSoundName = customSound,
            allowedDays = null
        )
    }

    private fun cancelAlarm(context: Context, editor: SharedPreferences.Editor, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = android.content.Intent(context, AlarmReceiver::class.java)
        val pi = android.app.PendingIntent.getBroadcast(
            context, id, intent,
            android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_NO_CREATE
        )
        if (pi != null) {
            alarmManager.cancel(pi)
            pi.cancel()
        }
        editor.putBoolean("alarm_${id}_active", false)
    }

    private fun parseTime(timeStr: String): Pair<Int, Int> {
        return try {
            val parts = timeStr.split(":")
            Pair(parts[0].toInt(), parts[1].toInt())
        } catch (e: Exception) {
            Pair(6, 0)
        }
    }

    private fun getDaysSinceStart(startDateStr: String): Int {
        if (startDateStr.isEmpty()) return 0
        try {
            val parts = startDateStr.split("T")
            val dParts = parts[0].split("-")
            if (dParts.size >= 3) {
                val startCal = java.util.Calendar.getInstance()
                startCal.set(dParts[0].toInt(), dParts[1].toInt()-1, dParts[2].toInt(), 0,0,0)
                startCal.set(java.util.Calendar.MILLISECOND, 0)
                
                val todayCal = java.util.Calendar.getInstance()
                todayCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                todayCal.set(java.util.Calendar.MINUTE, 0)
                todayCal.set(java.util.Calendar.SECOND, 0)
                todayCal.set(java.util.Calendar.MILLISECOND, 0)
                
                val diff = todayCal.timeInMillis - startCal.timeInMillis
                val days = (diff / (1000 * 60 * 60 * 24)).toInt()
                return if (days < 0) 0 else days
            }
        } catch (_: Exception) {}
        return 0
    }

    /** 
     * Reads a boolean safely from FlutterSharedPreferences.
     * Flutter stores booleans as actual booleans, but be defensive just in case.
     */
    private fun safeBool(prefs: android.content.SharedPreferences, key: String, default: Boolean): Boolean {
        return when (val v = prefs.all[key]) {
            is Boolean -> v
            is String  -> v.lowercase() == "true" || v == "1"
            is Int     -> v != 0
            else       -> default
        }
    }
}
