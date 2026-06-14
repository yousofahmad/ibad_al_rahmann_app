package app.ibad_al_rahmann

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

class FlipToMuteManager(private val context: Context) : SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var isListening = false

    fun startListening() {
        if (isListening) return
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("flutter.flip_to_mute", false)
        if (!enabled) return

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            isListening = true
        }
    }

    fun stopListening() {
        if (!isListening) return
        sensorManager?.unregisterListener(this)
        isListening = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val z = event.values[2]
            
            // Phone is face down (more sensitive threshold)
            if (z < -3) {
                try {
                    // Send broadcast to NotificationDismissReceiver (for old general notifications if any)
                    val stopGeneralIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
                        action = "app.ibad_al_rahmann.ACTION_STOP_SOUND"
                    }
                    context.sendBroadcast(stopGeneralIntent)

                    // Send intent to PrayerNotificationService (for Adhan & new unified notifications)
                    val stopAdhanIntent = Intent(context, PrayerNotificationService::class.java).apply {
                        action = "STOP_SOUND"
                    }
                    context.startService(stopAdhanIntent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                stopListening()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
