package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Helper that reads stored prayer data (written by Flutter's HomeWidgetService)
 * and pushes fresh data to the persistent notification + all home-screen widgets.
 *
 * Called from AlarmReceiver when a prayer alarm (adhan) fires so the
 * notification & widgets automatically move to the next prayer without
 * needing the Flutter app to be in the foreground.
 */
object WidgetUpdateHelper {

    // Prayer IDs that map to fajr(0), dhuhr(1), asr(2), maghrib(3), isha(4)
    // Alarm IDs: 100=Fajr, 101=Sunrise, 102=Dhuhr, 103=Asr, 104=Maghrib, 105=Isha
    fun prayerIndexFromAlarmId(alarmId: Int): Int {
        return when (alarmId) {
            100 -> 0  // Fajr  -> next is Dhuhr (1) [or Sunrise]
            101 -> 1  // Sunrise -> next is Dhuhr (1)
            102 -> 1  // Dhuhr -> next is Asr (2)
            103 -> 2  // Asr -> next is Maghrib (3)
            104 -> 3  // Maghrib -> next is Isha (4)
            105 -> 4  // Isha -> next is Fajr (0) tomorrow
            else -> -1
        }
    }

    fun nextPrayerIndex(currentAlarmId: Int): Int {
        return when (currentAlarmId) {
            100 -> 1  // After Fajr adhan  → next is Dhuhr
            101 -> 1  // After Sunrise     → next is Dhuhr
            102 -> 2  // After Dhuhr adhan → next is Asr
            103 -> 3  // After Asr adhan   → next is Maghrib
            104 -> 4  // After Maghrib adhan → next is Isha
            105 -> 0  // After Isha adhan  → next is Fajr (tomorrow)
            else -> -1
        }
    }

    fun nextPrayerName(nextIndex: Int): String {
        return when (nextIndex) {
            0 -> "الفجر"
            1 -> "الظهر"
            2 -> "العصر"
            3 -> "المغرب"
            4 -> "العشاء"
            else -> ""
        }
    }

    fun nextPrayerTimeKey(nextIndex: Int): String {
        return when (nextIndex) {
            0 -> "fajr_time"
            1 -> "dhuhr_time"
            2 -> "asr_time"
            3 -> "maghrib_time"
            4 -> "isha_time"
            else -> ""
        }
    }

    /**
     * Called when a prayer alarm fires. Updates the persistent notification
     * and all widget providers with the next prayer info.
     */
    fun onPrayerAlarmFired(context: Context, alarmId: Int) {
        try {
            PrayerDataPatcher.patchTodayEpochsFrom30d(context)
            val activeWidgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()

            // 1) Evaluate the new targeted prayer epoch based solely on current time + native logic
            val fEpoch = activeWidgetData.getLong("fajr_epoch", 0L)
            val dEpoch = activeWidgetData.getLong("dhuhr_epoch", 0L)
            val aEpoch = activeWidgetData.getLong("asr_epoch", 0L)
            val mEpoch = activeWidgetData.getLong("maghrib_epoch", 0L)
            val iEpoch = activeWidgetData.getLong("isha_epoch", 0L)

            if (fEpoch == 0L) return

            val epochs = longArrayOf(fEpoch, dEpoch, aEpoch, mEpoch, iEpoch)
            val names = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")

            val oneDayMs = 24 * 60 * 60 * 1000L
            while (now >= epochs[0] + oneDayMs) {
                for (i in 0..4) epochs[i] += oneDayMs
            }

            var nextIdx = 0
            var found = false
            for (i in 0..4) {
                if (now < epochs[i]) {
                    nextIdx = i
                    found = true
                    break
                }
            }

            val nextTargetEpoch = if (!found) epochs[0] + oneDayMs else epochs[nextIdx]

            // 2) Update all home-screen widgets
            updateWidgets(context)

            // 3) Update persistent notification if enabled
            val isNotificationEnabled = activeWidgetData.getBoolean("persistent_notification_enabled", true)
            if (isNotificationEnabled) {
                updateNotification(context)
            }

            // 4) Schedule NEXT autonomous update alarm
            scheduleNextWidgetUpdate(context, nextTargetEpoch)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providers = arrayOf(
                PrayerWidgetProvider::class.java,
                PrayerWidgetLargeProvider::class.java
            )
            for (provider in providers) {
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, provider))
                if (ids.isNotEmpty()) {
                    val intent = Intent(context, provider).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(intent)
                }
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun updateNotification(context: Context) {
        // Disabled: Widgets should NOT randomly sync the notification service
        // It causes ForegroundServiceDidNotStartInTimeException if main thread is blocked.
    }

    private fun scheduleNextWidgetUpdate(context: Context, triggerAtMillis: Long) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
             putExtra("alarm_id", 999) // Special ID for widget update
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 999, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    // أضف هذه الدالة في نهاية الملف قبل القوس الأخير }
    fun scheduleMidnightRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("alarm_id", 9999) // ID مخصص لمنتصف الليل
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 9999, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // حساب وقت 12:01 صباحاً لليوم التالي
            val cal = java.util.Calendar.getInstance().apply {
                add(java.util.Calendar.DAY_OF_YEAR, 1)
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 1)
                set(java.util.Calendar.SECOND, 0)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    fun retryMidnightRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("alarm_id", 9999)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 9999, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Retry in 5 minutes
            val triggerTime = System.currentTimeMillis() + (5 * 60 * 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
        } catch (e: Exception) { e.printStackTrace() }
    }
}
