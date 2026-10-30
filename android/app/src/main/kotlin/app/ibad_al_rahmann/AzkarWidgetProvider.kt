package app.ibad_al_rahmann

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import java.util.TimeZone

class AzkarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val startedAt = SystemClock.elapsedRealtime()
        NativeLogger.log(context, "AzkarWidget event=update_started trigger=appwidget_on_update widgets=${appWidgetIds.size}")

        val prayerPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val fajr = PrayerDataPatcher.getSafeLong(prayerPrefs, "fajr_epoch", 0L)
        val asr = PrayerDataPatcher.getSafeLong(prayerPrefs, "asr_epoch", 0L)
        val maghrib = PrayerDataPatcher.getSafeLong(prayerPrefs, "maghrib_epoch", 0L)
        val timeZone = TimeZone.getDefault()
        val session = AzkarWidgetData.sessionFor(now, fajr, asr, timeZone)
        val cycleDate = AzkarWidgetData.logicalDateKey(now, maghrib, timeZone)
        val category = if (session == AzkarWidgetData.Session.MORNING) "morning_azkar" else "evening_azkar"
        val title = if (session == AzkarWidgetData.Session.MORNING) "أذكار الصباح" else "أذكار المساء"
        val sessionPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val doneKey = "daily_${cycleDate}_$category"
        val startedKey = "daily_${cycleDate}_${category}_started"
        val isDone = readBoolean(sessionPrefs, doneKey)
        val isStarted = readBoolean(sessionPrefs, startedKey)
        val status = when {
            isDone -> "أتممت ورد اليوم"
            isStarted -> "أكمل أذكارك"
            else -> "ابدأ وردك الآن"
        }
        val timeHint = if (session == AzkarWidgetData.Session.MORNING) {
            "من الفجر إلى العصر"
        } else {
            "من العصر إلى الفجر"
        }

        var updated = 0
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_azkar)
                views.setTextViewText(R.id.tv_azkar_title, title)
                views.setTextViewText(R.id.tv_azkar_status, status)
                views.setTextViewText(R.id.tv_azkar_period, timeHint)
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId + 4400,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    views.setOnClickPendingIntent(R.id.widget_azkar_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
                updated++
            } catch (error: Exception) {
                NativeLogger.log(context, "AzkarWidget event=update_failed reason=${error.javaClass.simpleName}")
            }
        }

        NativeLogger.log(
            context,
            "AzkarWidget event=update_finished outcome=success session=${session.name.lowercase()} cycle_date=$cycleDate updated=$updated elapsed_ms=${SystemClock.elapsedRealtime() - startedAt}",
        )
    }

    private fun readBoolean(
        prefs: android.content.SharedPreferences,
        key: String,
    ): Boolean = (prefs.all["flutter.$key"] ?: prefs.all[key]) as? Boolean ?: false

    companion object {
        fun requestUpdate(context: Context, trigger: String) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AzkarWidgetProvider::class.java))
            NativeLogger.log(context, "AzkarWidget event=refresh_requested trigger=$trigger widgets=${ids.size}")
            if (ids.isEmpty()) return
            val intent = Intent(context, AzkarWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
