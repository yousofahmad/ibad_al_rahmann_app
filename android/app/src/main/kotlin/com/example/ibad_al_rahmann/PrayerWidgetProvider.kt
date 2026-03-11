package com.example.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
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
        val now = System.currentTimeMillis()
        
        // Epochs for Smart Logic
        val fEpoch = widgetData.getLong("fajr_epoch", 0L)
        val dEpoch = widgetData.getLong("dhuhr_epoch", 0L)
        val aEpoch = widgetData.getLong("asr_epoch", 0L)
        val mEpoch = widgetData.getLong("maghrib_epoch", 0L)
        val iEpoch = widgetData.getLong("isha_epoch", 0L)

        // ─── Trigger Notification Sync ───
        val isNotificationEnabled = widgetData.getBoolean("persistent_notification_enabled", true)
        if (isNotificationEnabled) {
            val serviceIntent = Intent(context, PrayerNotificationService::class.java).apply {
                action = "SYNC"
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                try { context.startForegroundService(serviceIntent) } catch (e: Exception) {}
            } else {
                context.startService(serviceIntent)
            }
        }

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

        // ─── Schedule refresh when count-up window expires ───
        if (isCountUp) {
            val switchTime = currentEpoch + countUpWindowMs + 1000 // 1 second after window ends
            scheduleRefresh(context, switchTime)
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setTextViewText(R.id.tv_prayer_name, toArabicDigits(statusName))

                val differenceMs = targetEpochMs - now
                val signStr = if (isCountUp) "+" else "-"
                val formatStr = "$signStr%s"

                val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    setChronometer(R.id.tv_countdown, baseTime, formatStr, true)
                    setChronometerCountDown(R.id.tv_countdown, !isCountUp)
                } else {
                    setChronometer(R.id.tv_countdown, baseTime, formatStr, true)
                }

                setTextViewText(R.id.tv_fajr, toArabicDigits(widgetData.getString("fajr", "--:--").orEmpty()))
                setTextViewText(R.id.tv_dhuhr, toArabicDigits(widgetData.getString("dhuhr", "--:--").orEmpty()))
                setTextViewText(R.id.tv_asr, toArabicDigits(widgetData.getString("asr", "--:--").orEmpty()))
                setTextViewText(R.id.tv_maghrib, toArabicDigits(widgetData.getString("maghrib", "--:--").orEmpty()))
                setTextViewText(R.id.tv_isha, toArabicDigits(widgetData.getString("isha", "--:--").orEmpty()))
                setTextViewText(R.id.tv_hijri_date, toArabicDigits(widgetData.getString("hijri", "").orEmpty()))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /**
     * Schedule an exact alarm to trigger a widget refresh at the specified time.
     * This ensures the widget switches from count-up to countdown mode precisely.
     */
    private fun scheduleRefresh(context: Context, triggerAtMillis: Long) {
        val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, PrayerWidgetProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            9990, // Unique request code for this refresh
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } catch (e: Exception) {
            // Fallback for devices that restrict exact alarms
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

