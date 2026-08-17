package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Calendar

/**
 * Large Golden Prayer Widget (4×2 minimum).
 */
class PrayerWidgetLargeProvider : AppWidgetProvider() {

    companion object {
        private val PRAYER_NAMES = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        private val PRAYER_TIME_KEYS = arrayOf("fajr", "dhuhr", "asr", "maghrib", "isha")
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
        // 1. Centralized Data Source (HomeWidgetPreferences)
        val activeWidgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        // Trigger a refresh if data is missing
        if (PrayerDataPatcher.getSafeLong(activeWidgetData, "fajr_epoch", 0L) == 0L) {
            PrayerDataPatcher.patchTodayEpochsFrom30d(context)
        }

        val views = RemoteViews(context.packageName, R.layout.widget_large_golden)
        val now = System.currentTimeMillis()

        // ─── Data from Native Master ───
        val fEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "fajr_epoch", 0L)
        val dEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "dhuhr_epoch", 0L)
        val aEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "asr_epoch", 0L)
        val mEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "maghrib_epoch", 0L)
        val iEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "isha_epoch", 0L)
        val nextFajrEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "next_fajr_epoch", 0L)

        // 3. Fix the "Open App" Check
        if (fEpoch == 0L) {
             views.setTextViewText(R.id.tv_large_status_prefix, "افتح التطبيق للتفعيل")
             appWidgetManager.updateAppWidget(appWidgetId, views)
             return
        }

        // Fix next_fajr_epoch if missing
        val finalNextFajr = if (nextFajrEpoch == 0L) fEpoch + 86400000L else nextFajrEpoch

        val fajrThreshold = fEpoch + (60 * 60 * 1000L)
        val dhuhrThreshold = dEpoch + (45 * 60 * 1000L)
        val asrThreshold = aEpoch + (45 * 60 * 1000L)
        val maghribThreshold = mEpoch + ((iEpoch - mEpoch) / 2)
        val ishaThreshold = iEpoch + (60 * 60 * 1000L)

        var nextPrayerName = ""
        var targetEpoch = 0L
        var isCountingUp = false

        when {
            now < fajrThreshold -> { nextPrayerName = "الفجر"; targetEpoch = fEpoch }
            now < dhuhrThreshold -> { nextPrayerName = "الظهر"; targetEpoch = dEpoch }
            now < asrThreshold -> { nextPrayerName = "العصر"; targetEpoch = aEpoch }
            now < maghribThreshold -> { nextPrayerName = "المغرب"; targetEpoch = mEpoch }
            now < ishaThreshold -> { nextPrayerName = "العشاء"; targetEpoch = iEpoch }
            else -> { nextPrayerName = "الفجر"; targetEpoch = finalNextFajr }
        }

        isCountingUp = now >= targetEpoch
        val activeHighlightIndex = when(nextPrayerName) {
            "الفجر" -> 0
            "الظهر" -> 1
            "العصر" -> 2
            "المغرب" -> 3
            "العشاء" -> 4
            else -> 0
        }

        val statusText = if (isCountingUp) "مضى على $nextPrayerName" else "الصلاة القادمة: $nextPrayerName"
        views.setTextViewText(R.id.tv_large_status_prefix, toArabicDigits(statusText))

        val timeDifference = targetEpoch - now
        val chronometerBase = android.os.SystemClock.elapsedRealtime() + timeDifference
        val formatStr = if (isCountingUp) "+%s" else "-%s"
        views.setChronometer(R.id.tv_large_chronometer, chronometerBase, formatStr, true)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.setChronometerCountDown(R.id.tv_large_chronometer, !isCountingUp)
        }

        // ─── Native Hijri Calculation ───
        val hijriStr = try {
            NativePrayerManager.getHijriDate(context)
        } catch (_: Exception) {
            activeWidgetData.getString("hijri", "-- --") ?: "-- --"
        }
        val gregorian = SimpleDateFormat("dd MMMM yyyy", Locale("ar")).format(Date())
        views.setTextViewText(R.id.tv_large_date, toArabicDigits(hijriStr))
        views.setTextViewText(R.id.tv_large_location, toArabicDigits(gregorian))

        val containerIds = intArrayOf(R.id.ll_large_fajr_container, R.id.ll_large_dhuhr_container, R.id.ll_large_asr_container, R.id.ll_large_maghrib_container, R.id.ll_large_isha_container)
        val nameIds = intArrayOf(R.id.tv_large_fajr_name, R.id.tv_large_dhuhr_name, R.id.tv_large_asr_name, R.id.tv_large_maghrib_name, R.id.tv_large_isha_name)
        val timeIds = intArrayOf(R.id.tv_large_fajr_time, R.id.tv_large_dhuhr_time, R.id.tv_large_asr_time, R.id.tv_large_maghrib_time, R.id.tv_large_isha_time)
        val ampmIds = intArrayOf(R.id.tv_large_fajr_ampm, R.id.tv_large_dhuhr_ampm, R.id.tv_large_asr_ampm, R.id.tv_large_maghrib_ampm, R.id.tv_large_isha_ampm)

        for (i in 0..4) {
            views.setTextViewText(nameIds[i], PRAYER_NAMES[i])
            val prayerTime = activeWidgetData.getString(PRAYER_TIME_KEYS[i], "--:--").orEmpty()
            val parts = prayerTime.split(" ")
            if (parts.size >= 2) {
                views.setTextViewText(timeIds[i], toArabicDigits(parts[0]))
                views.setTextViewText(ampmIds[i], parts.subList(1, parts.size).joinToString(" "))
            } else {
                views.setTextViewText(timeIds[i], toArabicDigits(prayerTime))
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

        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("target_page", "prayer_times")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId + 300, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.prayers_container, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
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
        val pendingIntent = PendingIntent.getBroadcast(context, 9992, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try { alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent) } catch (e: Exception) { alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent) }
    }

    private fun toArabicDigits(input: String): String {
        val english = arrayOf("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
        val arabic = arrayOf("٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩")
        var result = input
        for (i in english.indices) result = result.replace(english[i], arabic[i])
        return result
    }
}
