package com.example.ibad_al_rahmann

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Large Golden Prayer Widget (4×2 minimum).
 *
 * Layout: widget_large_golden.xml
 * - Top: Status prefix + live Chronometer
 * - Middle: 5 prayer columns (name + time), active prayer highlighted in white
 * - Bottom: Location + Hijri/Gregorian date
 *
 * Uses ONLY RemoteViews-safe widgets (LinearLayout, TextView, Chronometer).
 * All logic wrapped in try-catch to prevent "Failed to load widget" crashes.
 */
class PrayerWidgetLargeProvider : AppWidgetProvider() {

    companion object {
        // Default text color: Dark Golden-Brown (elegant on gold background)
        private const val COLOR_DEFAULT = 0xFF4A3B00.toInt()

        // Highlighted (active prayer): Solid White for pop effect
        private const val COLOR_HIGHLIGHT = 0xFFFFFFFF.toInt()

        // Prayer names in Arabic
        private val PRAYER_NAMES = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        private val PRAYER_TIME_KEYS = arrayOf("fajr_time", "dhuhr_time", "asr_time", "maghrib_time", "isha_time")
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.widget_large_golden)

        // ─── Data from Dart (single source of truth) ───
        val location = widgetData.getString("location_name", "القاهرة").orEmpty()
        val hijri = widgetData.getString("hijri_date", "").orEmpty()
        val nextName = widgetData.getString("prayer_name", "الفجر").orEmpty()
        val targetEpochMs = widgetData.getLong("gold_target_epoch", 0L)
        val isCountUp = widgetData.getBoolean("gold_is_count_up", false)
        
        // Use highlighted_prayer_index (Dart-computed), fallback to prayerIndex
        val activeHighlightIndex = widgetData.getInt("highlighted_prayer_index", widgetData.getInt("prayerIndex", -1))
        
        val prayerTimes = Array(5) { i ->
            widgetData.getString(PRAYER_TIME_KEYS[i], "--:--").orEmpty()
        }

        // ─── Update Header Status ───
        views.setTextViewText(R.id.tv_large_location, location)
        views.setTextViewText(R.id.tv_large_status_prefix, "$nextName ")

        // Chronometer Logic (Live Countdown/Count-up)
        if (targetEpochMs > 0L) {
            val nowMs = System.currentTimeMillis()
            val differenceMs = targetEpochMs - nowMs
            val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
            
            // Sign for count-up
            if (isCountUp) {
                views.setViewVisibility(R.id.tv_large_timer_sign, android.view.View.VISIBLE)
                views.setTextViewText(R.id.tv_large_timer_sign, "+")
            } else {
                views.setViewVisibility(R.id.tv_large_timer_sign, android.view.View.GONE)
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                views.setChronometer(R.id.tv_large_chronometer, baseTime, null, true)
                views.setChronometerCountDown(R.id.tv_large_chronometer, !isCountUp)
            } else {
                views.setChronometer(R.id.tv_large_chronometer, baseTime, null, true)
            }
        }

        // ─── Footer: Date ───
        val gregorian = SimpleDateFormat("dd MMM yyyy", Locale("ar")).format(Date())
        views.setTextViewText(R.id.tv_large_date, if (hijri.isNotEmpty()) "$hijri — $gregorian" else gregorian)

        // ─── 5-Prayer Row: Highlight active prayer ───
        val nameIds = intArrayOf(R.id.tv_large_fajr_name, R.id.tv_large_dhuhr_name, R.id.tv_large_asr_name, R.id.tv_large_maghrib_name, R.id.tv_large_isha_name)
        val timeIds = intArrayOf(R.id.tv_large_fajr_time, R.id.tv_large_dhuhr_time, R.id.tv_large_asr_time, R.id.tv_large_maghrib_time, R.id.tv_large_isha_time)

        for (i in 0..4) {
            val textColor = if (i == activeHighlightIndex) COLOR_HIGHLIGHT else COLOR_DEFAULT
            views.setTextViewText(nameIds[i], PRAYER_NAMES[i])
            views.setTextColor(nameIds[i], textColor)
            views.setTextViewText(timeIds[i], prayerTimes[i])
            views.setTextColor(timeIds[i], textColor)
        }

        // ─── Tap → Open App ───
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("target_page", "prayer_times")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId + 300, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_large_root, pendingIntent)
        } catch (e: Exception) { e.printStackTrace() }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

