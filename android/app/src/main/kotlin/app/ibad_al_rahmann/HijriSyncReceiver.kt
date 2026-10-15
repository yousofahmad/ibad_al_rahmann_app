package app.ibad_al_rahmann

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Receives only system/date events for the isolated Hijri synchronization flow. */
class HijriSyncReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == HijriSyncScheduler.ACTION_MIDNIGHT_CHECK) {
            HijriSyncScheduler.onMidnightAlarm(context)
        } else {
            HijriSyncScheduler.onSystemEvent(context, action)
        }
    }
}
