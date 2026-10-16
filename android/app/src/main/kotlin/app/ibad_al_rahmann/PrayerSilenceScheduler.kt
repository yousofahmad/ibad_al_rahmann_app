package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import java.util.Calendar

/** Schedules temporary phone-ringer silent windows around the five fard prayers. */
object PrayerSilenceScheduler {
    const val BOUNDARY_PAYLOAD = "prayer_silence_boundary"

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val NATIVE_PREFS = "AzkarNativePrefs"
    private const val ENABLED_KEY = "flutter.prayer_silence_enabled"
    private const val BEFORE_KEY = "flutter.prayer_silence_before_minutes"
    private const val AFTER_KEY = "flutter.prayer_silence_after_minutes"
    private const val MANAGED_KEY = "prayer_silence_managed_ringer_mode"
    private const val ORIGINAL_RINGER_MODE_KEY = "prayer_silence_original_ringer_mode"

    // Used only to restore DND that an earlier app version enabled.
    private const val LEGACY_MANAGED_DND_KEY = "prayer_silence_managed_dnd"
    private const val LEGACY_ORIGINAL_FILTER_KEY = "prayer_silence_original_filter"

    // Reserved for this feature; distinct request codes let every boundary be replaced safely.
    private const val FIRST_ALARM_ID = 12000
    private const val MAX_BOUNDARY_ALARMS = 40
    private const val BOUNDARY_ACTION = "app.ibad_al_rahmann.action.PRAYER_SILENCE_BOUNDARY"
    private const val MINUTE_MS = 60_000L
    private const val TWO_DAYS_MS = 2 * 24 * 60 * 60 * 1000L

    private data class Window(val startMs: Long, var endMs: Long)

    /** Called from the prayer scheduler, settings bridge, and after a boundary fires. */
    @Synchronized
    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelBoundaries(context, alarmManager)
        restoreLegacyDnd(context)

        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val enabled = flutterPrefs.getBoolean(ENABLED_KEY, false)
        val beforeMinutes = safeInt(flutterPrefs.all[BEFORE_KEY], 5).coerceIn(0, 180)
        val afterMinutes = safeInt(flutterPrefs.all[AFTER_KEY], 30).coerceIn(0, 180)
        if (!enabled || (beforeMinutes == 0 && afterMinutes == 0)) {
            reconcileRingerMode(context, shouldMute = false)
            return
        }

        val now = System.currentTimeMillis()
        val windows = buildMergedWindows(context, now, beforeMinutes, afterMinutes)
        reconcileRingerMode(context, windows.any { now >= it.startMs && now < it.endMs })

        val horizon = now + TWO_DAYS_MS
        val boundaries = windows.flatMap { listOf(it.startMs, it.endMs) }
            .filter { it > now && it <= horizon }
            .distinct()
            .sorted()
            .take(MAX_BOUNDARY_ALARMS)

        boundaries.forEachIndexed { index, triggerAt ->
            scheduleBoundary(context, alarmManager, FIRST_ALARM_ID + index, triggerAt)
        }
        NativeLogger.log(context, "PrayerSilence: scheduled ${boundaries.size} future silent-mode boundaries")
    }

    fun onBoundary(context: Context) {
        schedule(context)
    }

    private fun buildMergedWindows(
        context: Context,
        now: Long,
        beforeMinutes: Int,
        afterMinutes: Int,
    ): List<Window> {
        val rawWindows = mutableListOf<Window>()
        val base = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // Include yesterday to recognize a window crossing midnight, and several future days
        // so all boundaries in the next 48 hours are covered, including late-night schedules.
        for (dayOffset in -1..3) {
            val dateCalendar = (base.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }
            val times = try {
                NativePrayerManager.calculatePrayerTimes(context, dateCalendar.time)
            } catch (e: Exception) {
                NativeLogger.log(context, "PrayerSilence: prayer-time calculation failed: ${e.message}")
                null
            } ?: continue

            val prayerEpochs = listOf(
                times.fajr.time,
                times.dhuhr.time,
                times.asr.time,
                times.maghrib.time,
                times.isha.time,
            )
            for (prayerEpoch in prayerEpochs) {
                val minuteAligned = prayerEpoch / MINUTE_MS * MINUTE_MS
                val start = minuteAligned - beforeMinutes * MINUTE_MS
                val end = minuteAligned + afterMinutes * MINUTE_MS
                if (end > start) rawWindows.add(Window(start, end))
            }
        }

        val sorted = rawWindows.sortedBy { it.startMs }
        val merged = mutableListOf<Window>()
        for (window in sorted) {
            val last = merged.lastOrNull()
            if (last == null || window.startMs > last.endMs) {
                merged.add(Window(window.startMs, window.endMs))
            } else if (window.endMs > last.endMs) {
                last.endMs = window.endMs
            }
        }
        return merged
    }

    private fun reconcileRingerMode(context: Context, shouldMute: Boolean) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val state = context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
        val managed = state.getBoolean(MANAGED_KEY, false)
        val currentMode = audioManager.ringerMode

        if (shouldMute) {
            if (managed) {
                // Respect a manual ringer-mode change made during a quiet window.
                if (currentMode != AudioManager.RINGER_MODE_SILENT) {
                    state.edit().remove(MANAGED_KEY).remove(ORIGINAL_RINGER_MODE_KEY).apply()
                }
                return
            }
            // Do not claim or later change a silent mode the user already selected.
            if (currentMode == AudioManager.RINGER_MODE_SILENT) return

            state.edit()
                .putInt(ORIGINAL_RINGER_MODE_KEY, currentMode)
                .putBoolean(MANAGED_KEY, true)
                .apply()
            try {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                NativeLogger.log(context, "PrayerSilence: enabled phone silent ringer mode")
            } catch (e: Exception) {
                state.edit().remove(MANAGED_KEY).remove(ORIGINAL_RINGER_MODE_KEY).apply()
                NativeLogger.log(context, "PrayerSilence: unable to enable silent ringer mode: ${e.message}")
            }
            return
        }

        if (!managed) return
        try {
            // Restore only if the phone is still in the silent mode this feature applied.
            if (audioManager.ringerMode == AudioManager.RINGER_MODE_SILENT) {
                val originalMode = state.getInt(
                    ORIGINAL_RINGER_MODE_KEY,
                    AudioManager.RINGER_MODE_NORMAL,
                )
                audioManager.ringerMode = originalMode
                NativeLogger.log(context, "PrayerSilence: restored previous ringer mode $originalMode")
            }
            state.edit().remove(MANAGED_KEY).remove(ORIGINAL_RINGER_MODE_KEY).apply()
        } catch (e: Exception) {
            NativeLogger.log(context, "PrayerSilence: unable to restore ringer mode: ${e.message}")
        }
    }

    /** Undo a DND state managed by the preceding app version, when that access is still granted. */
    private fun restoreLegacyDnd(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val state = context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
        if (!state.getBoolean(LEGACY_MANAGED_DND_KEY, false)) return

        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!manager.isNotificationPolicyAccessGranted) return
            if (manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS) {
                val originalFilter = state.getInt(
                    LEGACY_ORIGINAL_FILTER_KEY,
                    NotificationManager.INTERRUPTION_FILTER_ALL,
                )
                manager.setInterruptionFilter(originalFilter)
                NativeLogger.log(context, "PrayerSilence: restored legacy DND filter $originalFilter")
            }
            state.edit().remove(LEGACY_MANAGED_DND_KEY).remove(LEGACY_ORIGINAL_FILTER_KEY).apply()
        } catch (e: Exception) {
            NativeLogger.log(context, "PrayerSilence: unable to restore legacy DND state: ${e.message}")
        }
    }

    private fun scheduleBoundary(
        context: Context,
        alarmManager: AlarmManager,
        alarmId: Int,
        triggerAt: Long,
    ) {
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            boundaryIntent(context, alarmId),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (e: SecurityException) {
            // Keep the feature functional when exact-alarm special access is unavailable, while
            // Android may deliver the fallback later than the requested minute.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }
            } catch (fallback: Exception) {
                NativeLogger.log(context, "PrayerSilence: failed to schedule boundary: ${fallback.message}")
            }
        }
    }

    private fun cancelBoundaries(context: Context, alarmManager: AlarmManager) {
        for (alarmId in FIRST_ALARM_ID until FIRST_ALARM_ID + MAX_BOUNDARY_ALARMS) {
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                boundaryIntent(context, alarmId),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) ?: continue
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun boundaryIntent(context: Context, alarmId: Int): Intent =
        Intent(context, AlarmReceiver::class.java).apply {
            action = BOUNDARY_ACTION
            putExtra("alarm_id", alarmId)
            putExtra("payload", BOUNDARY_PAYLOAD)
        }

    private fun safeInt(value: Any?, default: Int): Int = when (value) {
        is Int -> value
        is Long -> value.toInt()
        is Float -> value.toInt()
        is String -> value.toIntOrNull() ?: default
        else -> default
    }
}
