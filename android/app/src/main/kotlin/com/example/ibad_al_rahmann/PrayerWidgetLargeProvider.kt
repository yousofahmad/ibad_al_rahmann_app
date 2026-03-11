package com.example.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
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
        private val PRAYER_NAMES = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        private val PRAYER_TIME_KEYS = arrayOf("fajr", "dhuhr", "asr", "maghrib", "isha")

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
        val location = widgetData.getString("locationName", "القاهرة").orEmpty()
        val hijri = widgetData.getString("hijri", "").orEmpty()
        
        // Epochs for Smart Logic
        val fEpoch = widgetData.getLong("fajr_epoch", 0L)
        val dEpoch = widgetData.getLong("dhuhr_epoch", 0L)
        val aEpoch = widgetData.getLong("asr_epoch", 0L)
        val mEpoch = widgetData.getLong("maghrib_epoch", 0L)
        val iEpoch = widgetData.getLong("isha_epoch", 0L)

        // Prayer times as strings for display
        val prayerTimes = Array(5) { i ->
            widgetData.getString(PRAYER_TIME_KEYS[i], "--:--").orEmpty()
        }

        // ─── Smart Logic ───
        val now = System.currentTimeMillis()
        val epochs = longArrayOf(fEpoch, dEpoch, aEpoch, mEpoch, iEpoch)
        val names = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        
        if (fEpoch == 0L) {
             // Fallback if epochs are not yet saved
             views.setTextViewText(R.id.tv_large_status_prefix, toArabicDigits("انتظر..."))
             appWidgetManager.updateAppWidget(appWidgetId, views)
             return
        }

        // 1. Determine Current Prayer index (the one we are 'after')
        var currentIndex = 4 // Default to Isha if before Fajr or after Isha
        if (now < fEpoch) {
            currentIndex = 4 // It's "after Isha" of yesterday
        } else {
            for (i in 0..4) {
                if (now >= epochs[i]) {
                    currentIndex = i
                } else {
                    break
                }
            }
        }
        
        // 2. Determine Next Prayer index
        var nextIndex = (currentIndex + 1) % 5
        var nextTargetEpoch = epochs[nextIndex]
        if (nextIndex == 0 && now >= epochs[4]) {
            // Next is Fajr Tomorrow (roughly fEpoch + 24h)
            nextTargetEpoch = fEpoch + (24 * 60 * 60 * 1000)
        } else if (now < fEpoch) {
            // Next is Today's Fajr
            nextTargetEpoch = fEpoch
        }

        // 3. Count-up Rule (45 mins)
        val currentEpoch = epochs[currentIndex]
        val elapsedFromCurrent = now - currentEpoch
        val countUpWindowMs = 45 * 60 * 1000L
        val isCountUp = elapsedFromCurrent in 0..countUpWindowMs
        
        val targetEpochMs = if (isCountUp) currentEpoch else nextTargetEpoch
        val statusName = if (isCountUp) "مضى على ${names[currentIndex]}" else "متبقي على ${names[nextIndex]}"
        val activeHighlightIndex = if (isCountUp) currentIndex else nextIndex

        // ─── Schedule refresh when count-up window expires ───
        if (isCountUp) {
            val switchTime = currentEpoch + countUpWindowMs + 1000
            scheduleRefresh(context, switchTime)
        }

        // ─── UI Update ───
        val differenceMs = targetEpochMs - now
        val signStr = if (isCountUp) "+" else "-"
        val formatStr = "$signStr%s"

        views.setTextViewText(R.id.tv_large_status_prefix, toArabicDigits(statusName))

        // Chronometer Logic
        val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            views.setChronometer(R.id.tv_large_chronometer, baseTime, formatStr, true)
            views.setChronometerCountDown(R.id.tv_large_chronometer, !isCountUp)
        } else {
            views.setChronometer(R.id.tv_large_chronometer, baseTime, formatStr, true)
        }

        // Footer: Date
        val gregorian = SimpleDateFormat("dd MMMM yyyy", Locale("ar")).format(Date())
        views.setTextViewText(R.id.tv_large_date, toArabicDigits(hijri))
        views.setTextViewText(R.id.tv_large_location, toArabicDigits(gregorian))

        // 5-Prayer Row
        val containerIds = intArrayOf(R.id.ll_large_fajr_container, R.id.ll_large_dhuhr_container, R.id.ll_large_asr_container, R.id.ll_large_maghrib_container, R.id.ll_large_isha_container)
        val nameIds = intArrayOf(R.id.tv_large_fajr_name, R.id.tv_large_dhuhr_name, R.id.tv_large_asr_name, R.id.tv_large_maghrib_name, R.id.tv_large_isha_name)
        val timeIds = intArrayOf(R.id.tv_large_fajr_time, R.id.tv_large_dhuhr_time, R.id.tv_large_asr_time, R.id.tv_large_maghrib_time, R.id.tv_large_isha_time)
        val ampmIds = intArrayOf(R.id.tv_large_fajr_ampm, R.id.tv_large_dhuhr_ampm, R.id.tv_large_asr_ampm, R.id.tv_large_maghrib_ampm, R.id.tv_large_isha_ampm)

        for (i in 0..4) {
            views.setTextViewText(nameIds[i], PRAYER_NAMES[i])
            val parts = prayerTimes[i].split(" ")
            if (parts.size >= 2) {
                views.setTextViewText(timeIds[i], toArabicDigits(parts[0]))
                views.setTextViewText(ampmIds[i], parts.subList(1, parts.size).joinToString(" "))
            } else {
                views.setTextViewText(timeIds[i], toArabicDigits(prayerTimes[i]))
                views.setTextViewText(ampmIds[i], "")
            }
            
            if (i == activeHighlightIndex) {
                views.setInt(containerIds[i], "setBackgroundResource", R.drawable.widget_gold_box_active)
                views.setTextColor(nameIds[i], android.graphics.Color.WHITE)
                views.setTextColor(timeIds[i], android.graphics.Color.WHITE)
                views.setTextColor(ampmIds[i], android.graphics.Color.WHITE)
            } else {
                views.setInt(containerIds[i], "setBackgroundResource", 0)
                views.setTextColor(nameIds[i], android.graphics.Color.parseColor("#F2D675"))
                views.setTextColor(timeIds[i], android.graphics.Color.parseColor("#FFFFFF"))
                views.setTextColor(ampmIds[i], android.graphics.Color.parseColor("#E0E0E0"))
            }
        }

        // Tap → Open App
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

    private fun scheduleRefresh(context: Context, triggerAtMillis: Long) {
        val intent = Intent(context, PrayerWidgetLargeProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, PrayerWidgetLargeProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 9992, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } catch (e: Exception) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun toArabicDigits(input: String): String {
        val english = arrayOf("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
        val arabic = arrayOf("٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩")
        var result = input
        for (i in english.indices) result = result.replace(english[i], arabic[i])
        return result
    }
}
