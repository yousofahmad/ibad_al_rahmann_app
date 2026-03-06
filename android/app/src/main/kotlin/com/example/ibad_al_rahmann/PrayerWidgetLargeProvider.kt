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
 * - Top: Dynamic status prefix + live Chronometer
 * - Middle: 5 prayer columns (name + time), active prayer highlighted in white
 * - Bottom: Location + Hijri/Gregorian date
 *
 * Dynamic prefix logic:
 *   - If now < nextPrayerTime: "متبقي على [Name]" + count DOWN
 *   - If now > currentPrayerTime (within 30min): "مضى على [Name]" + count UP
 */
class PrayerWidgetLargeProvider : AppWidgetProvider() {

    companion object {
        private const val COLOR_DEFAULT = 0xFFE6D070.toInt() // Light elegant gold
        private const val COLOR_HIGHLIGHT = 0xFFFFFFFF.toInt()

        private val PRAYER_NAMES = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        private val PRAYER_TIME_KEYS = arrayOf("fajr_time", "dhuhr_time", "asr_time", "maghrib_time", "isha_time")

        // 45 minutes threshold for "مضى على" mode
        private const val COUNT_UP_THRESHOLD_MS = 45L * 60L * 1000L
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

        // ─── Data from Dart ───
        val location = widgetData.getString("location_name", "القاهرة").orEmpty()
        val hijri = widgetData.getString("hijri_date", "").orEmpty()
        val nextName = widgetData.getString("prayer_name", "الفجر").orEmpty()
        val targetEpochMs = widgetData.getLong("gold_target_epoch", widgetData.getLong("next_prayer_time_epoch", 0L))

        val activeHighlightIndex = widgetData.getInt("highlighted_prayer_index", widgetData.getInt("prayerIndex", -1))

        val prayerTimes = Array(5) { i ->
            widgetData.getString(PRAYER_TIME_KEYS[i], "--:--").orEmpty()
        }

        // ─── Dynamic Prefix + Chronometer Direction ───
        val nowMs = System.currentTimeMillis()
        val differenceMs = targetEpochMs - nowMs
        // Dart already provides a formatted nextName like "الفجر متبقي" or "مضى على الفجر"
        val isCountUp = targetEpochMs > 0L && differenceMs < 0 && Math.abs(differenceMs) <= COUNT_UP_THRESHOLD_MS
        val signStr = if (targetEpochMs > 0L) {
            if (isCountUp) "+" else "-"
        } else {
            ""
        }

        // ─── Update Header Status (Location removed, setting prefix only) ───
        views.setTextViewText(R.id.tv_large_status_prefix, nextName)
        views.setTextViewText(R.id.tv_large_status_sign, signStr)

        // Chronometer Logic
        if (targetEpochMs > 0L) {
            views.setViewVisibility(R.id.tv_large_chronometer, android.view.View.VISIBLE)
            
            val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                views.setChronometer(R.id.tv_large_chronometer, baseTime, null, true)
                views.setChronometerCountDown(R.id.tv_large_chronometer, !isCountUp)
            } else {
                views.setChronometer(R.id.tv_large_chronometer, baseTime, null, true)
            }
        } else {
            views.setViewVisibility(R.id.tv_large_chronometer, android.view.View.GONE)
        }

        // ─── Footer: Date (Hijri on one side, Gregorian on the other) ───
        val gregorian = SimpleDateFormat("dd MMMM yyyy", Locale("ar")).format(Date())
        views.setTextViewText(R.id.tv_large_date, hijri)
        // We reuse the location TextView to show the Gregorian date on the other side
        views.setTextViewText(R.id.tv_large_location, gregorian)

        // ─── 5-Prayer Row ───
        val nameIds = intArrayOf(R.id.tv_large_fajr_name, R.id.tv_large_dhuhr_name, R.id.tv_large_asr_name, R.id.tv_large_maghrib_name, R.id.tv_large_isha_name)
        val timeIds = intArrayOf(R.id.tv_large_fajr_time, R.id.tv_large_dhuhr_time, R.id.tv_large_asr_time, R.id.tv_large_maghrib_time, R.id.tv_large_isha_time)

        for (i in 0..4) {
            val textColor = if (i == activeHighlightIndex) COLOR_HIGHLIGHT else COLOR_DEFAULT
            views.setTextViewText(nameIds[i], PRAYER_NAMES[i])
            views.setTextColor(nameIds[i], textColor)
            views.setTextViewText(timeIds[i], prayerTimes[i])
            views.setTextColor(timeIds[i], textColor)
        }

        // ─── Tap → Open App (use root layout via the prayers_container as tap target) ───
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("target_page", "prayer_times")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId + 300, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.prayers_container, pendingIntent)
        } catch (e: Exception) { e.printStackTrace() }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
