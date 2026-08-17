package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.net.Uri
import android.os.Build
import java.util.Calendar
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val activeWidgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        // ── تحقق إن البيانات المخزنة للويدجيت هي لليوم الحالي ────────────────
        val storedFajr = PrayerDataPatcher.getSafeLong(activeWidgetData, "fajr_epoch", 0L)
        val todayStart = run {
            val c = Calendar.getInstance()
            c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0)
            c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0)
            c.timeInMillis
        }
        val storedIsToday = storedFajr in todayStart..(todayStart + 24 * 3600 * 1000L)

        NativeLogger.log(context, "Widget.update: storedFajr=$storedFajr isToday=$storedIsToday")

        // لو البيانات مش لليوم الحالي → احسب من النيتيف وخزّن
        if (!storedIsToday || storedFajr == 0L) {
            NativeLogger.log(context, "Widget.update: stale data → patching from native")
            PrayerDataPatcher.patchTodayEpochsFrom30d(context)
        }

        val views = RemoteViews(context.packageName, R.layout.prayer_widget)

        val fEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "fajr_epoch", 0L)
        val dEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "dhuhr_epoch", 0L)
        val aEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "asr_epoch", 0L)
        val mEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "maghrib_epoch", 0L)
        val iEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "isha_epoch", 0L)
        val nextFajrEpoch = PrayerDataPatcher.getSafeLong(activeWidgetData, "next_fajr_epoch", 0L)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pi = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        views.setOnClickPendingIntent(R.id.widget_root, pi)

        if (fEpoch == 0L) {
            NativeLogger.log(context, "Widget.update: fajr_epoch still 0 after patch → showing setup")
            views.setTextViewText(R.id.tv_prayer_name, "افتح التطبيق للتفعيل")
            views.setTextViewText(R.id.tv_countdown, "--:--")
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

        val statusText = if (isCountingUp) "مضى على $nextPrayerName" else "الصلاة القادمة: $nextPrayerName"
        views.setTextViewText(R.id.tv_prayer_name, toArabicDigits(statusText))

        val timeDifference = targetEpoch - now
        val chronometerBase = android.os.SystemClock.elapsedRealtime() + timeDifference
        
        val formatStr = if (isCountingUp) "+%s" else "-%s"
        views.setChronometer(R.id.tv_countdown, chronometerBase, formatStr, true)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.setChronometerCountDown(R.id.tv_countdown, !isCountingUp)
        }

        // Hijri Date
        val hijriStr = activeWidgetData.getString("hijri", "-- --") ?: "-- --"
        views.setTextViewText(R.id.tv_hijri_date, toArabicDigits(hijriStr))

        // Prayer Times
        views.setTextViewText(R.id.tv_fajr, toArabicDigits(activeWidgetData.getString("fajr", "--:--").orEmpty()))
        views.setTextViewText(R.id.tv_dhuhr, toArabicDigits(activeWidgetData.getString("dhuhr", "--:--").orEmpty()))
        views.setTextViewText(R.id.tv_asr, toArabicDigits(activeWidgetData.getString("asr", "--:--").orEmpty()))
        views.setTextViewText(R.id.tv_maghrib, toArabicDigits(activeWidgetData.getString("maghrib", "--:--").orEmpty()))
        views.setTextViewText(R.id.tv_isha, toArabicDigits(activeWidgetData.getString("isha", "--:--").orEmpty()))

        appWidgetManager.updateAppWidget(appWidgetId, views)
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
