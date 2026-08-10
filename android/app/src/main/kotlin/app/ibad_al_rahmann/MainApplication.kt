package app.ibad_al_rahmann

import android.app.Application
import android.content.Intent
import android.os.Build
import android.content.IntentFilter
import androidx.core.content.ContextCompat

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Ensure prayer epoch data is always available for widgets & notification
        Thread {
            try {
                PrayerDataPatcher.patchTodayEpochsFrom30d(this)
            } catch (e: Exception) { e.printStackTrace() }
        }.start()

    }
}
