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
