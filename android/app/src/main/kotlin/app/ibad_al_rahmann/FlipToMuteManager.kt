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

    // Require an explicit transition from Face-Up to Face-Down.
    // If the phone was already face-down when adhan started, it MUST keep ringing
    // until the user flips it face-up and then flat face-down again.
    private var wasFaceUp = false

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

        // Always start as false so an already-inverted phone doesn't silently auto-mute
        wasFaceUp = false
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
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        // Phone is face-up (or upright in hand) — arm the trigger for the next flat face-down flip
        if (z > 3.0f || (z > -2.0f && Math.abs(z) > Math.abs(x) && Math.abs(z) > Math.abs(y))) {
            wasFaceUp = true
        }

        // Phone must be TRULY flat face-down (not in a pocket or tilted vertically/horizontally):
        // 1. z must be strongly negative (pointing straight down into surface): z < -8.0f
        // 2. x and y tilt must be small: Math.abs(x) < 3.5f && Math.abs(y) < 3.5f (prevents pocket/vertical/slanted false triggers)
        // 3. wasFaceUp must be true (user explicitly picked it up / turned it face-up first)
        // 4. Cooldown passed
        val isFlatFaceDown = z < -8.0f && Math.abs(x) < 3.5f && Math.abs(y) < 3.5f
        val now = System.currentTimeMillis()

        if (isFlatFaceDown && wasFaceUp && (now - lastMuteTime) > MUTE_COOLDOWN_MS) {
            lastMuteTime = now
            wasFaceUp = false // Disarm so it doesn't re-trigger
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
