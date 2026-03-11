package com.example.ibad_al_rahmann

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
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.example.ibad_al_rahmann/native_notifications"
    
    companion object {
        var methodChannel: MethodChannel? = null

        fun scheduleAlarm(context: Context, id: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, soundName: String, title: String?, body: String?, payload: String?, isRepeating: Boolean, audioPath: String?, intervalMinutes: Int = 0) {
            val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
            with(prefs.edit()) {
                putInt("alarm_${id}_year", year)
                putInt("alarm_${id}_month", month)
                putInt("alarm_${id}_day", day)
                putInt("alarm_${id}_hour", hour)
                putInt("alarm_${id}_minute", minute)
                putString("alarm_${id}_sound", soundName)
                putString("alarm_${id}_audioPath", audioPath)
                if (title != null) putString("alarm_${id}_title", title)
                if (body != null) putString("alarm_${id}_body", body)
                if (payload != null) putString("alarm_${id}_payload", payload)
                putBoolean("alarm_${id}_active", true)
                putInt("alarm_${id}_interval", intervalMinutes)
                apply()
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
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
                if (title != null) putExtra("title", title)
                if (body != null) putExtra("body", body)
                if (payload != null) putExtra("payload", payload)
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
            
            if (year == -1) {
                 if (calendar.timeInMillis <= System.currentTimeMillis() || isRepeating) {
                      calendar.add(Calendar.DAY_OF_YEAR, 1)
                 }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    cancelAlarm(id)
                    result.success("Canceled")
                }
                "checkLaunchPayload" -> {
                    val target = intent?.getStringExtra("target_page")
                    result.success(target)
                }
                "updatePrayerNotification" -> {
                    try {
                        val nextName = call.argument<String>("nextName")
                        val hijri = call.argument<String>("hijri")
                        val prayerIndex = call.argument<Int>("prayerIndex") ?: -1
                        val nextPrayerEpoch = when (val epochArg = call.argument<Any>("nextPrayerEpoch")) {
                            is Long -> epochArg
                            is Int -> epochArg.toLong()
                            is String -> epochArg.toLongOrNull() ?: 0L
                            else -> 0L
                        }

                        val serviceIntent = Intent(this, PrayerNotificationService::class.java).apply {
                            action = "UPDATE_PRAYER_NOTIFICATION"
                            putExtra("fajr", call.argument<String>("fajr"))
                            putExtra("dhuhr", call.argument<String>("dhuhr"))
                            putExtra("asr", call.argument<String>("asr"))
                            putExtra("maghrib", call.argument<String>("maghrib"))
                            putExtra("isha", call.argument<String>("isha"))
                            putExtra("nextName", nextName)
                            putExtra("countdown", call.argument<String>("countdown"))
                            putExtra("hijri", hijri)
                            putExtra("prayerIndex", prayerIndex)
                            putExtra("nextPrayerEpoch", nextPrayerEpoch)
                            putExtra("isCountUp", call.argument<Boolean>("isCountUp") ?: false)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "stopPrayerNotification" -> {
                    val serviceIntent = Intent(this, PrayerNotificationService::class.java).apply {
                        action = "STOP_PRAYER_NOTIFICATION"
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val year = call.argument<Int>("year") ?: -1
                    val month = call.argument<Int>("month") ?: -1
                    val day = call.argument<Int>("day") ?: -1
                    val hour = call.argument<Int>("hour") ?: 6
                    val minute = call.argument<Int>("minute") ?: 0
                    val soundName = call.argument<String>("soundName") ?: "default"
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val payload = call.argument<String>("payload")
                    val audioPath = call.argument<String>("audioPath")
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    
                    scheduleAlarm(this, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes)
                    result.success("Scheduled")
                }
                "vibrate" -> {
                    val duration = call.argument<Int>("duration")?.toLong() ?: 100L
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(duration, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(duration)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        createNotificationChannels()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val target = intent.getStringExtra("target_page")
        if (target != null) {
            methodChannel?.invokeMethod("onPayloadReceived", target)
        }
    }

    private fun cancelAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        alarmManager.cancel(pendingIntent)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val groups = listOf(
                NotificationChannelGroup("prayers_group", "الأذان والإقامة"),
                NotificationChannelGroup("azkar_group", "الأذكار والرقية والصلاة على النبي"),
                NotificationChannelGroup("ramadan_group", "رمضان"),
                NotificationChannelGroup("eid_group", "العيد"),
                NotificationChannelGroup("wird_group", "الورد اليومي"),
                NotificationChannelGroup("reminders_group", "تذكيرات عامة"),
            )

            notificationManager.createNotificationChannelGroups(groups)
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
            // Restore IDs including Khatma (6000+) and Salawat (8000+)
            val allIds = (1..1000).toList() + (6000..7000).toList() + (8000..8010).toList()
            for (id in allIds) {
                if (prefs.getBoolean("alarm_${id}_active", false)) {
                    val hour = prefs.getInt("alarm_${id}_hour", 6)
                    val minute = prefs.getInt("alarm_${id}_minute", 0)
                    val soundName = prefs.getString("alarm_${id}_sound", "default") ?: "default"
                    val title = prefs.getString("alarm_${id}_title", "تنبيه")
                    val body = prefs.getString("alarm_${id}_body", "حان الوقت")
                    val payload = prefs.getString("alarm_${id}_payload", null)
                    val audioPath = prefs.getString("alarm_${id}_audioPath", null)
                    val interval = prefs.getInt("alarm_${id}_interval", 0)

                    MainActivity.scheduleAlarm(context, id, -1, -1, -1, hour, minute, soundName, title, body, payload, false, audioPath, interval)
                }
            }
            return
        }

        val alarmId = intent.getIntExtra("alarm_id", 0)
        val soundName = intent.getStringExtra("sound_name") ?: "default"
        val title = intent.getStringExtra("title") ?: "تنبيه"
        val body = intent.getStringExtra("body") ?: "حان الوقت"
        val payload = intent.getStringExtra("payload") ?: "home"
        val audioPath = intent.getStringExtra("audio_path")

        showNotification(context, alarmId, title, body, soundName, payload, audioPath)

        if (alarmId == 1 || alarmId == 2) {
            showNotification(
                context,
                alarmId + 1000,
                "🛡️ الرقية الشرعية",
                "حصن نفسك الآن بالرقية الشرعية",
                "ruqyah",
                "ruqyah",
                null
            )
        }

        if (alarmId < 1000) {
            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            val interval = intent.getIntExtra("interval_minutes", 0)
            MainActivity.scheduleAlarm(context, alarmId, -1, -1, -1, hour, minute, soundName, title, body, payload, true, audioPath, interval)
        } else if (alarmId in 8000..8999) {
            // Chaining Salawat Reminders
            val interval = intent.getIntExtra("interval_minutes", 0)
            if (interval > 0) {
                val cal = Calendar.getInstance()
                val currentDay = cal.get(Calendar.DAY_OF_YEAR)
                cal.add(Calendar.MINUTE, interval)
                
                // Only schedule next if it's still the SAME day
                if (cal.get(Calendar.DAY_OF_YEAR) == currentDay) {
                    MainActivity.scheduleAlarm(
                        context, alarmId,
                        cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                        cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE),
                        soundName, title, body, payload, false, audioPath, interval
                    )
                }
            }
        }
    }

    private fun showNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?) {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase()
        val baseChannelId: String
        val channelName: String
        val importance: Int

        if (audioPath != null) {
            baseChannelId = "custom_channel"
            channelName = "أصوات مخصصة"
            importance = NotificationManager.IMPORTANCE_HIGH
        } else if (cleanSoundName.contains("eid") || cleanSoundName.contains("takbeerat")) {
            baseChannelId = "events_channel"
            channelName = "المناسبات (العيد)"
            importance = NotificationManager.IMPORTANCE_HIGH
        } else if (cleanSoundName == "iqama") {
            baseChannelId = "iqama_channel"
            channelName = "إقامة الصلاة"
            importance = NotificationManager.IMPORTANCE_HIGH
        } else if (cleanSoundName.contains("adhan") || cleanSoundName == "fajr" || cleanSoundName.contains("sunrise") || 
            cleanSoundName.contains("shurooq") || cleanSoundName.contains("duha") || cleanSoundName.contains("qiyam") ||
            cleanSoundName == "makkah" || cleanSoundName == "madina" || cleanSoundName == "sabah" || cleanSoundName == "masaa") {
            baseChannelId = "adhan_channel"
            channelName = "الأذان والتنبيهات الهامة"
            importance = NotificationManager.IMPORTANCE_HIGH
        } else if (cleanSoundName == "ruqyah" || cleanSoundName == "silent") {
            baseChannelId = "silent_channel"
            channelName = "تنبيهات صامتة"
            importance = NotificationManager.IMPORTANCE_LOW
        } else {
            baseChannelId = "reminders_channel"
            channelName = "تذكيرات عامة"
            importance = NotificationManager.IMPORTANCE_DEFAULT
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // --- Resolve Sound URI ---
        var soundUri: Uri? = null
        val isSilent = cleanSoundName == "ruqyah" || cleanSoundName == "silent"

        if (!isSilent) {
            if (audioPath != null) {
                val file = File(audioPath)
                if (file.exists()) {
                    try {
                        soundUri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        context.grantUriPermission("com.android.systemui", soundUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else if (cleanSoundName != "default") {
                var resId = context.resources.getIdentifier(cleanSoundName, "raw", context.packageName)
                if (resId == 0) {
                    resId = context.resources.getIdentifier("adhan_$cleanSoundName", "raw", context.packageName)
                    if (resId == 0) {
                        if (cleanSoundName.contains("iqama")) {
                            resId = context.resources.getIdentifier("iqama", "raw", context.packageName)
                            if (resId == 0) resId = context.resources.getIdentifier("takbeer_makkah", "raw", context.packageName)
                        } else if (cleanSoundName.contains("adhan") || cleanSoundName == "nafis") {
                            resId = context.resources.getIdentifier("full_adhan_makkah", "raw", context.packageName)
                        }
                    }
                }
                if (resId != 0) {
                    soundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/$resId")
                } else {
                    soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
            } else {
                soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
        }

        // --- Channel ID ---
        val finalChannelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (audioPath != null) {
                "custom_${cleanSoundName}_v2"
            } else {
                "${baseChannelId}_${cleanSoundName}_v2"
            }
        } else {
            baseChannelId
        }

        // --- Create Channel (NO sound on channel — we play via MediaPlayer) ---
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(finalChannelId, channelName, importance)
            // No channel sound — we handle it ourselves via MediaPlayer
            channel.setSound(null, null)
            channel.enableVibration(true)

            // Assign channel to correct group based on notification ID
            channel.group = when (notifId) {
                in 1..3 -> "azkar_group"        // أذكار + رقية
                in 100..399 -> "prayers_group"  // أذان + إقامة + قبل الصلاة
                in 400..499 -> "ramadan_group"   // رمضان
                in 500..599 -> "eid_group"       // العيد
                in 600..699, in 6000..6999 -> "wird_group" // الورد
                in 700..799 -> "prayers_group"   // ضحى، قيام، ثلث الليل
                in 8000..8999 -> "azkar_group"   // الصلاة على النبي
                else -> "reminders_group"
            }

            notificationManager.createNotificationChannel(channel)
        }

        // --- Content Intent (tap) ---
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("target_page", targetPage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, notifId, openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // --- Delete Intent (dismiss → stop sound) ---
        val deleteIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
            putExtra("notification_id", notifId)
        }
        val deletePendingIntent = PendingIntent.getBroadcast(
            context, notifId + 10000, deleteIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val logoResId = context.resources.getIdentifier("logo", "drawable", context.packageName)
        val largeIconResId = if (logoResId != 0) logoResId else R.mipmap.ic_launcher
        val largeIconBitmap = BitmapFactory.decodeResource(context.resources, largeIconResId)

        val groupKey = when (notifId) {
            in 1..3 -> "group_azkar"       // Azkar + Ruqyah
            in 100..199 -> "group_prayers"  // Adhan
            in 200..299 -> "group_prayers"  // Pre-prayer
            in 300..399 -> "group_prayers"  // Iqama
            in 400..499 -> "group_ramadan"  // Ramadan (Iftar, Suhoor)
            in 500..599 -> "group_eid"      // Eid + Takbeerat
            in 600..699, in 6000..6999 -> "group_wird" // Wird
            in 700..799 -> "group_prayers"  // Duha, Qiyam, Thirds, Midnight, Jumua
            in 8000..8999 -> "group_azkar"  // Friday Salawat
            else -> "group_azkar"
        }

        val builder = NotificationCompat.Builder(context, finalChannelId)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setLargeIcon(largeIconBitmap)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDeleteIntent(deletePendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setGroup(groupKey)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O && soundUri != null) {
            builder.setSound(soundUri)
            builder.setVibrate(longArrayOf(0, 500, 500, 500))
        }

        notificationManager.notify(notifId, builder.build())

        // --- Play sound via MediaPlayer (respects ringer mode) ---
        if (!isSilent && soundUri != null) {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val ringerMode = audioManager.ringerMode

            // Only play if NOT silent and NOT vibrate-only
            if (ringerMode == AudioManager.RINGER_MODE_NORMAL) {
                try {
                    // Stop any previous sound
                    NotificationDismissReceiver.stopSound()

                    val mediaPlayer = MediaPlayer()
                    mediaPlayer.setDataSource(context, soundUri)
                    mediaPlayer.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .build()
                    )
                    mediaPlayer.isLooping = false
                    mediaPlayer.setOnCompletionListener { mp ->
                        mp.release()
                        if (NotificationDismissReceiver.activeMediaPlayer == mp) {
                            NotificationDismissReceiver.activeMediaPlayer = null
                        }
                    }
                    mediaPlayer.setOnErrorListener { mp, _, _ ->
                        mp.release()
                        if (NotificationDismissReceiver.activeMediaPlayer == mp) {
                            NotificationDismissReceiver.activeMediaPlayer = null
                        }
                        true
                    }
                    mediaPlayer.prepare()
                    mediaPlayer.start()
                    NotificationDismissReceiver.activeMediaPlayer = mediaPlayer
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}

// Stops sound when notification is swiped away
class NotificationDismissReceiver : BroadcastReceiver() {
    companion object {
        var activeMediaPlayer: MediaPlayer? = null

        fun stopSound() {
            try {
                activeMediaPlayer?.let {
                    if (it.isPlaying) it.stop()
                    it.release()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            activeMediaPlayer = null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        stopSound()
    }
}