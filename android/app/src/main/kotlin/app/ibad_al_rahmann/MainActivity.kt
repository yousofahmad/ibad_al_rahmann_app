package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity: AudioServiceFragmentActivity() {
    private val CHANNEL = "app.ibad_al_rahmann/native_notifications"
    
    companion object {
        var methodChannel: MethodChannel? = null
        var launchPayload: String? = null

        fun getAndClearLaunchPayload(): String? {
            val p = launchPayload
            launchPayload = null
            return p
        }

        fun scheduleAlarm(context: Context, id: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, soundName: String, title: String?, body: String?, payload: String?, isRepeating: Boolean, audioPath: String?, intervalMinutes: Int = 0, customSoundName: String? = null) {
            val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            scheduleAlarmInternal(context, editor, id, year, month, day, hour, minute, soundName, title, body, payload, isRepeating, audioPath, intervalMinutes, customSoundName)
            editor.apply()
        }

        fun scheduleAlarmInternal(context: Context, editor: android.content.SharedPreferences.Editor, id: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, soundName: String, title: String?, body: String?, payload: String?, isRepeating: Boolean, audioPath: String?, intervalMinutes: Int = 0, customSoundName: String? = null, allowedDays: String? = null) {
            // CRITICAL: Cancel existing alarm with this ID before scheduling a new one to prevent stacking
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val cancelIntent = Intent(context, AlarmReceiver::class.java)
            val oldPendingIntent = PendingIntent.getBroadcast(
                context, id, cancelIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (oldPendingIntent != null) {
                alarmManager.cancel(oldPendingIntent)
                oldPendingIntent.cancel()
            }

            editor.putInt("alarm_${id}_year", year)
            editor.putInt("alarm_${id}_month", month)
            editor.putInt("alarm_${id}_day", day)
            editor.putInt("alarm_${id}_hour", hour)
            editor.putInt("alarm_${id}_minute", minute)
            editor.putString("alarm_${id}_sound", soundName)
            editor.putString("alarm_${id}_audioPath", audioPath)
            if (title != null) editor.putString("alarm_${id}_title", title)
            if (body != null) editor.putString("alarm_${id}_body", body)
            if (payload != null) editor.putString("alarm_${id}_payload", payload)
            editor.putBoolean("alarm_${id}_active", true)
            editor.putInt("alarm_${id}_interval", intervalMinutes)
            if (allowedDays != null) editor.putString("alarm_${id}_allowed_days", allowedDays)
            
            // Persist custom sound so boot-reschedule can restore it
            if (customSoundName != null)
                editor.putString("alarm_${id}_custom_sound", customSoundName)
            else
                editor.remove("alarm_${id}_custom_sound")

            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("alarm_id", id)
                putExtra("year", year)
                putExtra("month", month)
                putExtra("day", day)
                putExtra("hour", hour)
                putExtra("minute", minute)
                putExtra("sound_name", soundName)
                putExtra("audio_path", audioPath)
                putExtra("interval_minutes", intervalMinutes)
                if (allowedDays != null) putExtra("allowed_days", allowedDays)
                if (title != null) putExtra("title", title)
                if (body != null) putExtra("body", body)
                if (payload != null) putExtra("payload", payload)
                if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            
            val calendar = Calendar.getInstance().apply {
                if (year != -1 && month != -1 && day != -1) {
                    set(Calendar.YEAR, year)
                    set(Calendar.MONTH, month - 1)
                    set(Calendar.DAY_OF_MONTH, day)
                }
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            if (year == -1 || intervalMinutes > 0) {
                 if (calendar.timeInMillis <= System.currentTimeMillis()) {
                      if (intervalMinutes > 0) {
                           // Catch up for interval-based alarms (e.g. Salawat)
                           while (calendar.timeInMillis <= System.currentTimeMillis()) {
                                calendar.add(Calendar.MINUTE, intervalMinutes)
                           }
                      } else {
                           // Standard daily/repeating alarm
                           calendar.add(Calendar.DAY_OF_YEAR, 1)
                      }
                 }
            } else {
                // For specific-date alarms, if it's already past (more than 1 min ago), don't schedule it.
                // This prevents "notification storms" on reboot.
                if (calendar.timeInMillis <= System.currentTimeMillis() - 60000) {
                    editor.putBoolean("alarm_${id}_active", false)
                    return
                }
                
                // If it's in the past few seconds (due to truncation), push it slightly forward
                if (calendar.timeInMillis <= System.currentTimeMillis()) {
                    calendar.timeInMillis = System.currentTimeMillis() + 2000 // 2 seconds from now
                }
            }

            // setAlarmClock pierces deep Doze mode and custom ROM battery limits.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val alarmClockInfo = AlarmManager.AlarmClockInfo(calendar.timeInMillis, pendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        // Disable state restoration to ensure app starts fresh on Home
        intent?.removeExtra("androidx.lifecycle.InstanceStateSavedStateRegistry.Key")
        super.onCreate(null)
        launchPayload = intent?.getStringExtra("target_page") ?: intent?.getStringExtra("payload")

        if (launchPayload == "prayer" || launchPayload == "jumuah") {
            val stopIntent = Intent(this, PrayerNotificationService::class.java).apply { action = "STOP_SOUND" }
            startService(stopIntent)
        }

        handleMigrationCleanup()
        
        // Refresh prayer times cache and reschedule all alarms on every app open
        Thread {
            try {
                NativePrayerManager.generateThirtyDayCache(this)
                NativePrayerScheduler.scheduleToday(this)
                NativeAzkarScheduler.scheduleAzkar(this)
                
                // Reschedule any custom interval alarms via AlarmReceiver
                val intent = Intent(this, AlarmReceiver::class.java).apply {
                    action = "android.intent.action.BOOT_COMPLETED"
                }
                sendBroadcast(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun handleMigrationCleanup() {
        val prefs = getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val currentMigrationVersion = 10 // Increment this when a major notification change happens
        val lastMigrationVersion = prefs.getInt("migration_version", 0)

        if (lastMigrationVersion < currentMigrationVersion) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Comprehensive list of IDs from old and current systems to wipe the slate clean
            val idsToCancel = mutableListOf<Int>()
            idsToCancel.addAll(1..20) // Basic Azkar
            idsToCancel.addAll(100..150) // Prayers
            idsToCancel.addAll(200..300) // Next Prayer
            idsToCancel.addAll(400..700) // Ramadan/Eid/Jumua
            idsToCancel.addAll(1000..1100) // Reminders
            idsToCancel.addAll(3000..6000) // Pre-prayer/Iqama
            idsToCancel.addAll(8000..9500) // Salawat/Takbeerat
            
            // Wipe standard IDs
            for (id in idsToCancel) {
                val intent = Intent(this, AlarmReceiver::class.java)
                val pi = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE)
                if (pi != null) {
                    alarmManager.cancel(pi)
                    pi.cancel()
                }
            }

            // Mark all native alarms as inactive so they must be rescheduled by the new version
            val editor = prefs.edit()
            val allKeys = prefs.all.keys
            for (key in allKeys) {
                if (key.startsWith("alarm_") && key.endsWith("_active")) {
                    editor.putBoolean(key, false)
                }
            }
            editor.putInt("migration_version", currentMigrationVersion)
            editor.apply()
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BackgroundMethodChannelPlugin())
        
        createNotificationChannels()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val target = intent.getStringExtra("target_page") ?: intent.getStringExtra("payload")
        if (target != null) {
            BackgroundMethodChannelPlugin.currentChannel?.invokeMethod("onPayloadReceived", target)
            if (target == "prayer" || target == "jumuah") {
                val stopIntent = Intent(this, PrayerNotificationService::class.java).apply { action = "STOP_SOUND" }
                startService(stopIntent)
            }
        }
    }

    private fun cancelAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        alarmManager.cancel(pendingIntent)
        // Mark as inactive so chaining logic won't restart it after it fires
        getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
            .edit().putBoolean("alarm_${id}_active", false).apply()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val groups = listOf(
                NotificationChannelGroup("prayers_group", "مواقيت الصلاة"),
                NotificationChannelGroup("azkar_group", "الأذكار والرقية"),
                NotificationChannelGroup("ramadan_group", "رمضان والصيام"),
                NotificationChannelGroup("eid_group", "العيد"),
                NotificationChannelGroup("wird_group", "الورد اليومي"),
                NotificationChannelGroup("reminders_group", "تذكيرات عامة"),
            )
            notificationManager.createNotificationChannelGroups(groups)

            // Re-create the standard channels here too to ensure they exist with the right names/groups
            val adhanChannel = NotificationChannel("prayer_sound_channel_v8", "الأذان والتنبيهات الصوتية", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(false)
                group = "prayers_group"
            }
            val silentChannel = NotificationChannel("strictly_silent_channel_v8", "التنبيهات الصامتة", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
                group = "reminders_group"
            }
            notificationManager.createNotificationChannels(listOf(adhanChannel, silentChannel))
        }
    }
}
