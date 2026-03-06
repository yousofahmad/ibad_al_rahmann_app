package com.example.ibad_al_rahmann

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
        val nextIdx = nextPrayerIndex(alarmId)
        if (nextIdx < 0) return

        val widgetData = HomeWidgetPlugin.getData(context)
        val fajr = widgetData.getString("fajr_time", "--:--") ?: "--:--"
        val dhuhr = widgetData.getString("dhuhr_time", "--:--") ?: "--:--"
        val asr = widgetData.getString("asr_time", "--:--") ?: "--:--"
        val maghrib = widgetData.getString("maghrib_time", "--:--") ?: "--:--"
        val isha = widgetData.getString("isha_time", "--:--") ?: "--:--"
        val hijri = widgetData.getString("hijri_date", "") ?: ""

        val prayerName = nextPrayerName(nextIdx)
        val timeKey = nextPrayerTimeKey(nextIdx)
        val prayerTime = widgetData.getString(timeKey, "--:--") ?: "--:--"

        // Save updated prayerIndex and prayer_name for widgets
        widgetData.edit()
            .putInt("prayerIndex", nextIdx)
            .putString("prayer_name", prayerName)
            .putString("prayer_time", prayerTime)
            .apply()

        // 1) Update persistent notification
        try {
            val serviceIntent = Intent(context, PrayerNotificationService::class.java).apply {
                action = "UPDATE_PRAYER_NOTIFICATION"
                putExtra("fajr", fajr)
                putExtra("dhuhr", dhuhr)
                putExtra("asr", asr)
                putExtra("maghrib", maghrib)
                putExtra("isha", isha)
                putExtra("nextName", prayerName)
                putExtra("countdown", "")
                putExtra("hijri", hijri)
                putExtra("prayerIndex", nextIdx)
                putExtra("nextPrayerEpoch", 0L) // Will be recalculated when app opens
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2) Update all home-screen widgets
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)

            val providers = arrayOf(
                PrayerWidgetProvider::class.java,
                PrayerWidgetWideProvider::class.java,
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
