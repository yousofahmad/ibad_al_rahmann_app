package com.example.ibad_al_rahmann

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                
                // Top Section: Next Prayer Name
                val prayerName = widgetData.getString("prayer_name", "الصلاة القادمة").orEmpty()
                setTextViewText(R.id.tv_prayer_name, prayerName)

                // Live Chronometer (Chronometer)
                // We expect Dart to pass the target epoch time in milliseconds
                val targetEpochMs = widgetData.getLong("next_prayer_time_epoch", 0L)
                val isCountUp = widgetData.getBoolean("is_count_up", false)

                val signStr = if (targetEpochMs > 0L) {
                    if (isCountUp) "+" else "-"
                } else {
                    ""
                }
                
                setTextViewText(R.id.tv_prayer_name, prayerName)
                setTextViewText(R.id.tv_widget_small_status_sign, signStr)

                if (targetEpochMs > 0L) {
                    val nowMs = System.currentTimeMillis()
                    val differenceMs = targetEpochMs - nowMs
                    val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
                    
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        setChronometer(R.id.tv_widget_small_countdown, baseTime, null, true)
                        setChronometerCountDown(R.id.tv_widget_small_countdown, !isCountUp)
                        // Removed dynamic sign format that caused flickering
                    } else {
                        setChronometer(R.id.tv_widget_small_countdown, baseTime, null, true)
                    }
                }

                // Middle Section: 5 Prayers
                setTextViewText(R.id.tv_fajr, widgetData.getString("fajr_time", "--:--").orEmpty())
                setTextViewText(R.id.tv_dhuhr, widgetData.getString("dhuhr_time", "--:--").orEmpty())
                setTextViewText(R.id.tv_asr, widgetData.getString("asr_time", "--:--").orEmpty())
                setTextViewText(R.id.tv_maghrib, widgetData.getString("maghrib_time", "--:--").orEmpty())
                setTextViewText(R.id.tv_isha, widgetData.getString("isha_time", "--:--").orEmpty())

                // Bottom Section: Hijri Date
                val hijriDate = widgetData.getString("hijri_date", "").orEmpty()
                setTextViewText(R.id.tv_hijri_date, hijriDate)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
