package app.ibad_al_rahmann

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == "STOP_SOUND") {
            val serviceIntent = Intent(context, PrayerNotificationService::class.java).apply {
                this.action = "STOP_SOUND"
            }
            androidx.core.content.ContextCompat.startForegroundService(context, serviceIntent)
        }
    }
}
