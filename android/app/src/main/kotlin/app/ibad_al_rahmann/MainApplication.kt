package app.ibad_al_rahmann

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.content.IntentFilter
import androidx.core.content.ContextCompat

class MainApplication : Application() {
    private var screenUnlockReceiver: ScreenUnlockReceiver? = null

    override fun onCreate() {
        super.onCreate()

        // Ensure prayer epoch data is always available for widgets & notification
        Thread {
            try {
                PrayerDataPatcher.patchTodayEpochsFrom30d(this)
            } catch (e: Exception) { e.printStackTrace() }
        }.start()

        // Register ScreenUnlockReceiver dynamically so it receives USER_PRESENT reliably
        try {
            ScreenUnlockReceiver.initSoundPool(this)
            val receiver = ScreenUnlockReceiver()
            screenUnlockReceiver = receiver
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            android.util.Log.d("MainApplication", "ScreenUnlockReceiver registered dynamically successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainApplication", "Failed to register ScreenUnlockReceiver: ${e.message}", e)
        }
    }
}
