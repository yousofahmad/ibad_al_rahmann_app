package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/** Cancels the app-managed prayer alarm created by the previous app version. */
object PrayerRelativeAlarmScheduler {
    const val ALARM_ID = 12100
    const val EXTRA_MARKER = "prayer_relative_alarm"
    private const val ACTION = "app.ibad_al_rahmann.action.PRAYER_RELATIVE_ALARM"

    fun cancel(context: Context) {
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_ID,
            Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION
                putExtra("alarm_id", ALARM_ID)
            },
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        NativeLogger.log(context, "Legacy PrayerRelativeAlarm: cancelled")
    }
}
