package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/** Keeps one exact, app-managed alarm aligned to a selected daily prayer time. */
object PrayerRelativeAlarmScheduler {
    const val ALARM_ID = 12100
    const val EXTRA_MARKER = "prayer_relative_alarm"

    private const val PREFS = "FlutterSharedPreferences"
    private const val ENABLED_KEY = "flutter.prayer_relative_alarm_enabled"
    private const val PRAYER_KEY = "flutter.prayer_relative_alarm_prayer"
    private const val OFFSET_KEY = "flutter.prayer_relative_alarm_before_minutes"
    private const val ACTION = "app.ibad_al_rahmann.action.PRAYER_RELATIVE_ALARM"
    private const val MINUTE_MS = 60_000L

    @Synchronized
    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(ENABLED_KEY, false)
        val operation = PendingIntent.getBroadcast(
            context,
            ALARM_ID,
            alarmIntent(context),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        if (!enabled) {
            alarmManager.cancel(operation)
            operation.cancel()
            NativeLogger.log(context, "PrayerRelativeAlarm: disabled and cancelled")
            return
        }

        val prayerKey = prefs.getString(PRAYER_KEY, "Fajr") ?: "Fajr"
        val beforeMinutes = safeInt(prefs.all[OFFSET_KEY], 5).coerceIn(0, 180)
        val now = System.currentTimeMillis()
        val next = findNextPrayerAlarm(context, prayerKey, beforeMinutes, now)
        if (next == null) {
            alarmManager.cancel(operation)
            NativeLogger.log(context, "PrayerRelativeAlarm: no prayer time available; no alarm scheduled")
            return
        }

        val (triggerAt, prayerName) = next
        val intent = alarmIntent(context).apply {
            putExtra("title", "منبه صلاة $prayerName")
            putExtra(
                "body",
                if (beforeMinutes == 0) {
                    "حان وقت المنبه المرتبط بصلاة $prayerName"
                } else {
                    "حان وقت المنبه قبل أذان $prayerName بـ $beforeMinutes دقيقة"
                },
            )
            putExtra("sound_name", "default")
            putExtra("payload", "prayer")
            putExtra(EXTRA_MARKER, true)
        }
        val alarmOperation = PendingIntent.getBroadcast(
            context,
            ALARM_ID,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val showIntent = PendingIntent.getActivity(
            context,
            ALARM_ID + 1,
            Intent(context, MainActivity::class.java).apply {
                action = "app.ibad_al_rahmann.action.OPEN_PRAYER_RELATIVE_ALARM"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("payload", "prayer")
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, showIntent), alarmOperation)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, alarmOperation)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, alarmOperation)
            }
            NativeLogger.log(
                context,
                "PrayerRelativeAlarm: scheduled $prayerName at $triggerAt ($beforeMinutes minutes before)",
            )
        } catch (e: SecurityException) {
            scheduleFallback(context, alarmManager, triggerAt, alarmOperation, e)
        }
    }

    private fun findNextPrayerAlarm(
        context: Context,
        prayerKey: String,
        beforeMinutes: Int,
        now: Long,
    ): Pair<Long, String>? {
        val base = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val basePrayerName = when (prayerKey) {
            "Dhuhr" -> "الظهر"
            "Asr" -> "العصر"
            "Maghrib" -> "المغرب"
            "Isha" -> "العشاء"
            else -> "الفجر"
        }

        for (dayOffset in 0..3) {
            val date = (base.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, dayOffset) }
            val times = try {
                NativePrayerManager.calculatePrayerTimes(context, date.time)
            } catch (e: Exception) {
                NativeLogger.log(context, "PrayerRelativeAlarm: prayer-time calculation failed: ${e.message}")
                null
            } ?: continue
            val prayerName = if (
                prayerKey == "Dhuhr" && date.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
            ) "الجمعة" else basePrayerName
            val prayerTime = when (prayerKey) {
                "Dhuhr" -> times.dhuhr.time
                "Asr" -> times.asr.time
                "Maghrib" -> times.maghrib.time
                "Isha" -> times.isha.time
                else -> times.fajr.time
            }
            val triggerAt = prayerTime / MINUTE_MS * MINUTE_MS - beforeMinutes * MINUTE_MS
            if (triggerAt > now) return triggerAt to prayerName
        }
        return null
    }

    private fun scheduleFallback(
        context: Context,
        alarmManager: AlarmManager,
        triggerAt: Long,
        operation: PendingIntent,
        cause: SecurityException,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, operation)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, operation)
            }
            NativeLogger.log(context, "PrayerRelativeAlarm: exact system alarm unavailable; scheduled fallback")
        } catch (fallback: Exception) {
            NativeLogger.log(
                context,
                "PrayerRelativeAlarm: failed to schedule alarm: ${fallback.message}; original=${cause.message}",
            )
        }
    }

    private fun alarmIntent(context: Context): Intent =
        Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION
            putExtra("alarm_id", ALARM_ID)
        }

    private fun safeInt(value: Any?, default: Int): Int = when (value) {
        is Int -> value
        is Long -> value.toInt()
        is Float -> value.toInt()
        is String -> value.toIntOrNull() ?: default
        else -> default
    }
}
