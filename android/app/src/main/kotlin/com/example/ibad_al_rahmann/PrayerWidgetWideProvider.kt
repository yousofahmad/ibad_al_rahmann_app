package com.example.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetWideProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        
        // Epochs for Smart Logic
        val fEpoch = widgetData.getLong("fajr_epoch", 0L)
        val dEpoch = widgetData.getLong("dhuhr_epoch", 0L)
        val aEpoch = widgetData.getLong("asr_epoch", 0L)
        val mEpoch = widgetData.getLong("maghrib_epoch", 0L)
        val iEpoch = widgetData.getLong("isha_epoch", 0L)

        if (fEpoch == 0L) return // No data yet

        // ─── Smart Logic ───
        val epochs = longArrayOf(fEpoch, dEpoch, aEpoch, mEpoch, iEpoch)
        val names = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        
        var currentIndex = 4
        if (now < fEpoch) {
            currentIndex = 4
        } else {
            for (i in 0..4) {
                if (now >= epochs[i]) currentIndex = i
                else break
            }
        }
        
        var nextIndex = (currentIndex + 1) % 5
        var nextTargetEpoch = if (nextIndex == 0 && now >= epochs[4]) fEpoch + (24 * 60 * 60 * 1000) else if (now < fEpoch) fEpoch else epochs[nextIndex]

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

        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_wide).apply {
                    val hijri = widgetData.getString("hijri", "").orEmpty()
                    val signStr = if (isCountUp) "+" else "-"

                    setTextViewText(R.id.tv_widget_wide_next_prayer, toArabicDigits(statusName))
                    setTextViewText(R.id.tv_widget_wide_status_sign, signStr)
                    setTextViewText(R.id.tv_widget_wide_hijri, toArabicDigits(hijri))

                    val differenceMs = targetEpochMs - now
                    val baseTime = SystemClock.elapsedRealtime() + differenceMs
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {  
                        setChronometer(R.id.tv_widget_wide_countdown, baseTime, null, true)      
                        setChronometerCountDown(R.id.tv_widget_wide_countdown, !isCountUp)       
                    } else {
                        setChronometer(R.id.tv_widget_wide_countdown, baseTime, null, true)
                    }

                    val timeIds = intArrayOf(R.id.tv_widget_wide_fajr, R.id.tv_widget_wide_dhuhr, R.id.tv_widget_wide_asr, R.id.tv_widget_wide_maghrib, R.id.tv_widget_wide_isha)
                    val accentColor = context.getColor(R.color.widget_accent)
                    val defaultColor = context.getColor(R.color.widget_text_primary)
                    
                    val prayerTimes = arrayOf(
                        widgetData.getString("fajr", "--:--").orEmpty(),
                        widgetData.getString("dhuhr", "--:--").orEmpty(),
                        widgetData.getString("asr", "--:--").orEmpty(),
                        widgetData.getString("maghrib", "--:--").orEmpty(),
                        widgetData.getString("isha", "--:--").orEmpty()
                    )
                    
                    for (i in 0..4) {
                        setTextViewText(timeIds[i], toArabicDigits(prayerTimes[i]))
                        setTextColor(timeIds[i], if (i == activeHighlightIndex) accentColor else defaultColor)
                    }

                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP      
                    }
                    val pendingIntent = PendingIntent.getActivity(context, appWidgetId + 400, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    setOnClickPendingIntent(R.id.widget_wide_layout, pendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun scheduleRefresh(context: Context, triggerAtMillis: Long) {
        val intent = Intent(context, PrayerWidgetWideProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, PrayerWidgetWideProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 9991, intent,
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
        for (i in english.indices) {
            result = result.replace(english[i], arabic[i])
        }
        return result
    }
}
