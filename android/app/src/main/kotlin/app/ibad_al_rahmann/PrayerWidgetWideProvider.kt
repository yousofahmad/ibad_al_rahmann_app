package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

class PrayerWidgetWideProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        PrayerDataPatcher.patchTodayEpochsFrom30d(context)
        val activeWidgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        
        // Epochs for Smart Logic
        val fEpoch = activeWidgetData.getLong("fajr_epoch", 0L)
        val dEpoch = activeWidgetData.getLong("dhuhr_epoch", 0L)
        val aEpoch = activeWidgetData.getLong("asr_epoch", 0L)
        val mEpoch = activeWidgetData.getLong("maghrib_epoch", 0L)
        val iEpoch = activeWidgetData.getLong("isha_epoch", 0L)

        if (fEpoch == 0L) return // No data yet

        // ─── Smart Logic ───
        val epochs = longArrayOf(fEpoch, dEpoch, aEpoch, mEpoch, iEpoch)
        val names = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        
        val oneDayMs = 24 * 60 * 60 * 1000L
        while (now >= epochs[0] + oneDayMs) {
            for (i in 0..4) epochs[i] += oneDayMs
        }

        var currentIndex = 4
        if (now < epochs[0]) {
            currentIndex = 4
        } else {
            for (i in 0..4) {
                if (now >= epochs[i]) currentIndex = i
                else break
            }
        }
        
        var nextIndex = (currentIndex + 1) % 5
        var nextTargetEpoch = if (nextIndex == 0 && now >= epochs[4]) epochs[0] + oneDayMs else if (now < epochs[0]) epochs[0] else epochs[nextIndex]

        val currentEpoch = epochs[currentIndex]
        val elapsedFromCurrent = now - currentEpoch
        val countUpWindowMs = 45 * 60 * 1000L
        val isCountUp = elapsedFromCurrent in 0..countUpWindowMs
        
        val targetEpochMs = if (isCountUp) currentEpoch else nextTargetEpoch
        val statusName = if (isCountUp) "مضى على ${names[currentIndex]}" else "متبقي على ${names[nextIndex]}"
        val activeHighlightIndex = if (isCountUp) currentIndex else nextIndex

        // ─── Native Hijri Calculation ───
        val hijriOffset = activeWidgetData.getInt("widget_hijri_offset", 0)
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, hijriOffset)
        
        var hijriString = ""
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val islamicCalendar = android.icu.util.IslamicCalendar()
            islamicCalendar.time = calendar.time
            val hDay = islamicCalendar.get(android.icu.util.IslamicCalendar.DAY_OF_MONTH)
            val hMonth = islamicCalendar.get(android.icu.util.IslamicCalendar.MONTH)
            val hYear = islamicCalendar.get(android.icu.util.IslamicCalendar.YEAR)
            val monthNames = arrayOf("محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة")
            hijriString = "$hDay ${monthNames[hMonth]} $hYear هـ"
        } else {
            hijriString = activeWidgetData.getString("hijri", "").orEmpty()
        }

        // ─── Schedule refresh when count-up window expires ───
        if (isCountUp) {
            val switchTime = currentEpoch + countUpWindowMs + 1000
            scheduleRefresh(context, switchTime)
        }

        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_wide).apply {
                    val signStr = if (isCountUp) "+" else "-"

                    setTextViewText(R.id.tv_widget_wide_next_prayer, toArabicDigits(statusName))
                    setTextViewText(R.id.tv_widget_wide_status_sign, signStr)
                    setTextViewText(R.id.tv_widget_wide_hijri, toArabicDigits(hijriString))

                    var differenceMs = targetEpochMs - now
                    if (!isCountUp && differenceMs < 0) {
                        differenceMs = 0
                    }
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
                        activeWidgetData.getString("fajr", "--:--").orEmpty(),
                        activeWidgetData.getString("dhuhr", "--:--").orEmpty(),
                        activeWidgetData.getString("asr", "--:--").orEmpty(),
                        activeWidgetData.getString("maghrib", "--:--").orEmpty(),
                        activeWidgetData.getString("isha", "--:--").orEmpty()
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
