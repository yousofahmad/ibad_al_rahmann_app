package app.ibad_al_rahmann

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

/**
 * ScreenUnlockService — Deprecated in favor of ScreenUnlockReceiver.
 * Stops immediately to prevent persistent notification.
 */
class ScreenUnlockService : Service() {

    companion object {
        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, ScreenUnlockService::class.java))
            } catch (_: Exception) {}
        }
    }

    override fun onCreate() {
        super.onCreate()
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
