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

        // Queued payload when the Flutter channel isn't ready yet
        var pendingNavigationPayload: String? = null

        fun getAndClearLaunchPayload(): String? {
            val p = launchPayload
            launchPayload = null
            return p
        }

        /**
         * Delivers payload to Flutter immediately if the channel is ready,
         * otherwise stores it so it can be flushed when the channel attaches.
         * Logs every attempt to NativeLogger.
         */
        fun deliverPayloadToFlutter(context: android.content.Context, payload: String) {
            val channel = BackgroundMethodChannelPlugin.currentChannel
            if (channel != null) {
                channel.invokeMethod("onPayloadReceived", payload)
                NativeLogger.log(context, "Navigation: payload '$payload' delivered to Flutter channel ✓")
                pendingNavigationPayload = null
            } else {
                NativeLogger.log(context, "Navigation: Flutter channel null — queuing payload '$payload' for retry")
                pendingNavigationPayload = payload
            }
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
        // Only accept payloads that come from a real notification tap.
        // Widget taps and PrayerFocusOverlay internal navigation do NOT set from_notification,
        // so they won't trigger spurious warm-restart deliveries on subsequent app opens.
        val fromNotification = intent?.getBooleanExtra("from_notification", false) ?: false
        launchPayload = if (fromNotification) {
            intent?.getStringExtra("target_page") ?: intent?.getStringExtra("payload")
        } else {
            null
        }
        NativeLogger.log(this, "MainActivity.onCreate payload detected: $launchPayload (fromNotif=$fromNotification)")


        val stopSound = intent?.getBooleanExtra("stop_sound_on_open", true) ?: true
        if (stopSound && (launchPayload == "prayer" || launchPayload == "jumuah")) {
            val stopIntent = Intent(this, PrayerNotificationService::class.java).apply { action = "STOP_SOUND" }
            startService(stopIntent)
            NativeLogger.log(this, "MainActivity: Sent STOP_SOUND to PrayerNotificationService")
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

                val fp = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                // Start PrayerNotificationService (صلاتي bar) if enabled
                val isPersistentEnabled = fp.getBoolean("flutter.persistent_notification_enabled", true)
                if (isPersistentEnabled) {
                    val svcIntent = Intent(this, PrayerNotificationService::class.java).apply { action = "SYNC" }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(svcIntent)
                    else startService(svcIntent)
                }

                // Screen unlock receiver is now managed dynamically inside PrayerNotificationService
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun handleMigrationCleanup() {
        val prefs = getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val currentMigrationVersion = 11 // Bump to cancel old fasting alarm ID 2003
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
            idsToCancel.add(2003) // Old native fasting alarm (now handled by Flutter only)
            
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

        // Handle screen unlock service start/stop from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.ibad_al_rahmann/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenUnlockService" -> {
                        val svcIntent = Intent(this, PrayerNotificationService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(svcIntent)
                        else startService(svcIntent)
                        result.success(null)
                    }
                    "stopScreenUnlockService" -> {
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Warm-restart payload delivery ──────────────────────────────────────
        // When the Android process is still alive (common on Samsung / MIUI),
        // swiping from Recent + tapping a notification triggers a NEW Activity
        // (onCreate fires) but reuses the existing Flutter engine. This means
        // SplashScreen._checkUser() never re-runs and launchPayload is never
        // consumed by Dart's getLaunchPayload().
        //
        // Strategy: read launchPayload AFTER a 1.5 s delay.
        //   • Cold start  → SplashScreen calls getLaunchPayload() at ~1 s,
        //     which calls getAndClearLaunchPayload() and sets launchPayload=null.
        //     At 1.5 s the callback finds null → no-op (navigation already handled).
        //   • Warm restart → getLaunchPayload() is never called, so launchPayload
        //     still holds the value at 1.5 s → we deliver it via onPayloadReceived,
        //     which the already-running Dart listener picks up immediately.
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            val payload = launchPayload          // read AFTER delay, not before
            if (payload != null) {
                NativeLogger.log(this,
                    "configureFlutterEngine: warm-restart delivery of '$payload'")
                deliverPayloadToFlutter(this, payload)
                launchPayload = null             // prevent double delivery on next configure
            }
        }, 1500)
    }



    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val target = intent.getStringExtra("target_page") ?: intent.getStringExtra("payload")
        NativeLogger.log(this, "MainActivity.onNewIntent payload detected: $target | channel ready: ${BackgroundMethodChannelPlugin.currentChannel != null}")
        if (target != null) {
            val stopSound = intent.getBooleanExtra("stop_sound_on_open", true)
            if (stopSound && (target == "prayer" || target == "jumuah")) {
                val stopIntent = Intent(this, PrayerNotificationService::class.java).apply { action = "STOP_SOUND" }
                startService(stopIntent)
            }
            // Deliver with retry — if channel is null now, queue it for when it becomes ready
            deliverPayloadToFlutter(this, target)
            if (pendingNavigationPayload != null) {
                // Schedule a retry after 500ms to cover Flutter engine startup delay
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    val queued = pendingNavigationPayload
                    if (queued != null) {
                        deliverPayloadToFlutter(this, queued)
                    }
                }, 500)
                // And one more retry after 1.5s in case of slow startup
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    val queued = pendingNavigationPayload
                    if (queued != null) {
                        NativeLogger.log(this, "Navigation: 1.5s retry for payload '$queued' — channel: ${BackgroundMethodChannelPlugin.currentChannel != null}")
                        deliverPayloadToFlutter(this, queued)
                    }
                }, 1500)
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
