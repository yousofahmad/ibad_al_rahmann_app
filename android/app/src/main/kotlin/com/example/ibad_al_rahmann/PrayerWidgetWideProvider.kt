package com.example.ibad_al_rahmann

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetWideProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val views = RemoteViews(context.packageName, R.layout.widget_wide).apply {

                    val fajr = widgetData.getString("fajr_time", "--:--").orEmpty()
                    val dhuhr = widgetData.getString("dhuhr_time", "--:--").orEmpty()
                    val asr = widgetData.getString("asr_time", "--:--").orEmpty()
                    val maghrib = widgetData.getString("maghrib_time", "--:--").orEmpty()
                    val isha = widgetData.getString("isha_time", "--:--").orEmpty()
                    val hijri = widgetData.getString("hijri_date", "").orEmpty()
                    val nextName = widgetData.getString("prayer_name", "الفجر").orEmpty()

                    // Use the unified highlighted prayer index from Dart
                    val activeHighlightIndex = widgetData.getInt("highlighted_prayer_index", widgetData.getInt("prayerIndex", -1))

                    // Live Chronometer using epoch from Dart
                    val targetEpochMs = widgetData.getLong("next_prayer_time_epoch", 0L)
                    val isCountUp = widgetData.getBoolean("is_count_up", false)
                    val signStr = if (targetEpochMs > 0L) {
                        if (isCountUp) "+" else "-"
                    } else {
                        ""
                    }
                    // ─── Apply to Views ───
                    setTextViewText(R.id.tv_widget_wide_next_prayer, nextName)
                    setTextViewText(R.id.tv_widget_wide_status_sign, signStr)
                    setTextViewText(R.id.tv_widget_wide_hijri, hijri)

                    // Live Chronometer
                    if (targetEpochMs > 0L) {
                        val nowMs = System.currentTimeMillis()
                        val differenceMs = targetEpochMs - nowMs
                        val baseTime = SystemClock.elapsedRealtime() + differenceMs

                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {  
                            setChronometer(R.id.tv_widget_wide_countdown, baseTime, null, true)      
                            setChronometerCountDown(R.id.tv_widget_wide_countdown, !isCountUp)       
                        } else {
                            setChronometer(R.id.tv_widget_wide_countdown, baseTime, null, true)
                        }
                    }

                    val timeIds = intArrayOf(R.id.tv_widget_wide_fajr, R.id.tv_widget_wide_dhuhr, R.id.tv_widget_wide_asr, R.id.tv_widget_wide_maghrib, R.id.tv_widget_wide_isha)
                    val accentColor = context.getColor(R.color.widget_accent)
                    val defaultColor = context.getColor(R.color.widget_text_primary)

                    val prayerTimes = arrayOf(fajr, dhuhr, asr, maghrib, isha)
                    for (i in 0..4) {
                        setTextViewText(timeIds[i], prayerTimes[i])
                        setTextColor(timeIds[i], if (i == activeHighlightIndex) accentColor else defaultColor)
                    }

                    // App Tap Intent
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP      
                    }
                    val pendingIntent = PendingIntent.getActivity(context, appWidgetId + 400, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    setOnClickPendingIntent(R.id.tv_widget_wide_fajr, pendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
