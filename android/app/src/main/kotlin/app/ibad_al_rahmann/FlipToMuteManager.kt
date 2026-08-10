package app.ibad_al_rahmann

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build

class FlipToMuteManager(private val context: Context) : SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var isListening = false

    // Start wasFaceUp=true so a phone that's already face-down fires immediately
    // (common case: user places phone on table before adhan finishes)
    private var wasFaceUp = true

    // Prevent repeated triggers on a single flip (debounce)
    private var lastMuteTime = 0L
    private val MUTE_COOLDOWN_MS = 3000L

    fun startListening() {
        if (isListening) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("flutter.flip_to_mute", false)
        if (!enabled) return

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        // Assume face-up so a face-down phone instantly triggers mute
        wasFaceUp = true
        lastMuteTime = 0L

        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            isListening = true
        }
    }

    fun stopListening() {
        if (!isListening) return
        try {
            sensorManager?.unregisterListener(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isListening = false
        sensorManager = null
        accelerometer = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_ACCELEROMETER) return
        val z = event.values[2]

        // Phone is face-up (or upright) — allow next face-down to trigger mute
        if (z > -4.0f) {
            wasFaceUp = true
        }

        // Phone is clearly face-down AND was face-up AND cooldown passed
        val now = System.currentTimeMillis()
        if (z < -9.5f && wasFaceUp && (now - lastMuteTime) > MUTE_COOLDOWN_MS) {
            lastMuteTime = now
            wasFaceUp = false // Reset so it doesn't re-trigger while still face-down
            try {
                // Stop audio in PrayerNotificationService
                val stopAdhanIntent = Intent(context, PrayerNotificationService::class.java).apply {
                    action = "STOP_SOUND"
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(stopAdhanIntent)
                } else {
                    context.startService(stopAdhanIntent)
                }

                // Also broadcast to NotificationDismissReceiver for any legacy stop handlers
                val stopGeneralIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
                    action = "app.ibad_al_rahmann.ACTION_STOP_SOUND"
                }
                context.sendBroadcast(stopGeneralIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            stopListening()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
