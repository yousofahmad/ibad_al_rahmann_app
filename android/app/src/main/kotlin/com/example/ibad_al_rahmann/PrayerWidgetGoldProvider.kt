package com.example.ibad_al_rahmann

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetGoldProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val views = RemoteViews(context.packageName, R.layout.widget_gold).apply {
                
                // --- Data Fetching ---
                val city = widgetData.getString("location_name", "القاهرة").orEmpty()
                val hijri = widgetData.getString("hijri_date", "--/--/----").orEmpty()
                val nextName = widgetData.getString("prayer_name", "الفجر").orEmpty()
                
                val fajr = widgetData.getString("fajr_time", "--:--").orEmpty()
                val dhuhr = widgetData.getString("dhuhr_time", "--:--").orEmpty()
                val asr = widgetData.getString("asr_time", "--:--").orEmpty()
                val maghrib = widgetData.getString("maghrib_time", "--:--").orEmpty()
                val isha = widgetData.getString("isha_time", "--:--").orEmpty()
                
                val activeIndex = widgetData.getInt("highlighted_prayer_index", widgetData.getInt("prayerIndex", -1))
                
                // Advanced Logic: 45-Minute Rule Flags
                val targetEpochMs = widgetData.getLong("gold_target_epoch", 0L)
                val isCountUp = widgetData.getBoolean("gold_is_count_up", false)

                // --- UI Updates ---
                setTextViewText(R.id.tv_gold_city, city)
                setTextViewText(R.id.tv_gold_hijri, hijri)
                setTextViewText(R.id.tv_gold_next_name, nextName)
                
                setTextViewText(R.id.tv_fajr_time, fajr)
                setTextViewText(R.id.tv_dhuhr_time, dhuhr)
                setTextViewText(R.id.tv_asr_time, asr)
                setTextViewText(R.id.tv_maghrib_time, maghrib)
                setTextViewText(R.id.tv_isha_time, isha)

                // --- Chronometer (Live Timer) ---
                if (targetEpochMs > 0L) {
                    val nowMs = System.currentTimeMillis()
                    val differenceMs = targetEpochMs - nowMs
                    val baseTime = SystemClock.elapsedRealtime() + differenceMs
                    
                    // Set Sign (+ or -)
                    setTextViewText(R.id.tv_gold_timer_sign, if (isCountUp) "+" else "–")
                    
                    // setChronometer(viewId, base, format, started)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        setChronometer(R.id.tv_gold_timer, baseTime, null, true)
                        setChronometerCountDown(R.id.tv_gold_timer, !isCountUp)
                    } else {
                        setChronometer(R.id.tv_gold_timer, baseTime, null, true)
                    }
                }

                // --- Active State Highlighting (Text Color + Box BG) ---
                val boxIds = intArrayOf(R.id.box_fajr, R.id.box_dhuhr, R.id.box_asr, R.id.box_maghrib, R.id.box_isha)
                val labelIds = intArrayOf(R.id.tv_fajr_label, R.id.tv_dhuhr_label, R.id.tv_asr_label, R.id.tv_maghrib_label, R.id.tv_isha_label)
                val timeIds = intArrayOf(R.id.tv_fajr_time, R.id.tv_dhuhr_time, R.id.tv_asr_time, R.id.tv_maghrib_time, R.id.tv_isha_time)
                val accentColor = context.getColor(R.color.widget_accent)
                val inactiveColor = Color.parseColor("#CCFFFFFF")
                val inactiveTimeColor = Color.WHITE
                
                for (i in boxIds.indices) {
                    if (i == activeIndex) {
                        setInt(boxIds[i], "setBackgroundResource", R.drawable.widget_active_box_bg)
                        setTextColor(labelIds[i], accentColor)
                        setTextColor(timeIds[i], accentColor)
                    } else {
                        setInt(boxIds[i], "setBackgroundColor", Color.TRANSPARENT)
                        setTextColor(labelIds[i], inactiveColor)
                        setTextColor(timeIds[i], inactiveTimeColor)
                    }
                }

                // --- Interactivity: Tap to navigate ---
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("target_page", "prayer_times")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 
                    appWidgetId + 200, // Unique request code
                    intent, 
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                setOnClickPendingIntent(R.id.widget_gold_bg, pendingIntent)
            }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
