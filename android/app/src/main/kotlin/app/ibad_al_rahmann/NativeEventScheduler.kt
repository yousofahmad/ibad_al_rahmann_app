package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Native event scheduling boundary. Seasonal/night/fasting notifications are
 * owned by Flutter notification_service; keeping a second native owner caused
 * duplicate notifications. Native owns only the midnight refresh wake-up.
 */
object NativeEventScheduler {
    private const val ID_MIDNIGHT_REFRESH = 9999
    private val LEGACY_EVENT_IDS = 2000..2007

    fun scheduleEvents(context: Context, todayEpochs: LongArray, tomorrowFajrEpoch: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Remove alarms created by the former native night/Ramadan/Arafah engine.
        // Use the same explicit receiver identity as scheduleSingleAlarm so the
        // cancellation also works after an app upgrade.
        for (id in LEGACY_EVENT_IDS) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
            try {
                val legacyIntent = Intent().setClassName(
                    context, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
                )
                val legacyPendingIntent = PendingIntent.getBroadcast(
                    context, id, legacyIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
                )
                if (legacyPendingIntent != null) {
                    alarmManager.cancel(legacyPendingIntent)
                    legacyPendingIntent.cancel()
                }
            } catch (_: Exception) { }
        }

        val now = System.currentTimeMillis()
        val midnight = Calendar.getInstance().apply {
            timeInMillis = now
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 1)
            set(Calendar.MILLISECOND, 0)
        }
        if (midnight.timeInMillis <= now) return

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("payload", "sync_only")
            putExtra("alarm_id", ID_MIDNIGHT_REFRESH)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, ID_MIDNIGHT_REFRESH, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(midnight.timeInMillis, pendingIntent), pendingIntent
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, midnight.timeInMillis, pendingIntent
            )
        }
    }
}
