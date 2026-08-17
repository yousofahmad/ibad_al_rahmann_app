package app.ibad_al_rahmann

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == "STOP_SOUND") {
            NativeLogger.log(context, "NotificationActionReceiver: STOP_SOUND clicked. Stopping audio without dismissing notification.")
            val serviceIntent = Intent(context, PrayerNotificationService::class.java).apply {
                this.action = "STOP_SOUND"
            }
            try { androidx.core.content.ContextCompat.startForegroundService(context, serviceIntent) } catch (e: Exception) { e.printStackTrace() }
        }
    }
}
