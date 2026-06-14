package app.ibad_al_rahmann

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import java.io.File
import android.content.ContentResolver

class PrayerNotificationService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private lateinit var audioVolumeManager: AudioVolumeManager
    private var flipToMuteManager: FlipToMuteManager? = null
    
    private val refreshHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val refreshRunnable = object : Runnable {
        override fun run() {
            syncFromSharedPrefs()
            refreshHandler.postDelayed(this, 15 * 60 * 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioVolumeManager = AudioVolumeManager(this)
        flipToMuteManager = FlipToMuteManager(this)
    }

    private fun startForegroundSafe(id: Int, notification: android.app.Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(id, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(id, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // ALWAYS satisfy Android 8+ foreground service requirements immediately
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "persistent_prayer_v11"
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(channelId) == null) {
                val ch = NotificationChannel(channelId, "شريط وقت الصلاة", NotificationManager.IMPORTANCE_MAX)
                ch.setShowBadge(false); ch.setSound(null, null); ch.enableVibration(false)
                nm.createNotificationChannel(ch)
            }
            val placeholderNotif = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle("")
                .setContentText("")
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true)
                .build()
            startForegroundSafe(777, placeholderNotif)
        }

        val action = intent?.action ?: "SYNC"

        if (action == "SYNC" && !isPersistentNotificationEnabled()) {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                stopForeground(true)
                stopSelf(startId)
            }, 1500)
            return START_NOT_STICKY
        }

        when (action) {
            "PLAY_SOUND" -> handlePlaySound(intent)
            "STOP_SOUND" -> {
                stopAudio()
            }
            "UPDATE_PRAYER_NOTIFICATION" -> handleUpdateIntent(intent!!)
            "STOP_PRAYER_NOTIFICATION" -> {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    stopForeground(true)
                    stopSelf(startId)
                }, 1500)
            }
            else -> syncFromSharedPrefs(startId)
        }

        refreshHandler.removeCallbacks(refreshRunnable)
        refreshHandler.postDelayed(refreshRunnable, 15 * 60 * 1000)

        return START_STICKY
    }

    private fun handlePlaySound(intent: Intent?) {
        if (intent == null) return
        stopAudio() 

        val soundName = intent.getStringExtra("sound_name") ?: "default"
        val audioPath = intent.getStringExtra("audio_path")
        val customSoundName = intent.getStringExtra("custom_sound_name")
        val alarmId = intent.getIntExtra("notification_id", -1)

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val overrideSilent = flutterPrefs.getBoolean("flutter.override_silent_mode", false)
        val useCustomVolume = flutterPrefs.getBoolean("flutter.use_custom_notif_volume", false)
        val volumePercent = (flutterPrefs.all["flutter.custom_notif_volume_level"] as? Number)?.toInt() ?: 100

        // 1. Evaluate State FIRST before initializing MediaPlayer
        if (!AudioVibrationManager.evaluateAudioVibrationState(this, soundName, overrideSilent)) {
            showSoundNotification(intent, alarmId, isSilent = true) // Visual only
            NotificationQueueManager.onAudioFinished(this)
            return
        }

        audioVolumeManager.captureState()
        if (useCustomVolume || overrideSilent) {
            audioVolumeManager.applySettings(volumePercent, overrideSilent)
        }

        val soundUri = resolveSoundUri(soundName, audioPath, customSoundName, alarmId)
        
        // ALWAYS show the notification, regardless of whether the audio plays successfully
        showSoundNotification(intent, alarmId)
        
        if (soundUri != null) {
            try {
                mediaPlayer = MediaPlayer().apply {
                    setWakeMode(this@PrayerNotificationService, android.os.PowerManager.PARTIAL_WAKE_LOCK)
                    setDataSource(this@PrayerNotificationService, soundUri)
                    setAudioAttributes(AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build())
                    
                    setVolume(1.0f, 1.0f) // Maximize internal player volume
                    isLooping = false
                    setOnCompletionListener { 
                        stopAudio()
                    }
                    setOnErrorListener { _, _, _ -> 
                        stopAudio()
                        true 
                    }
                    prepare()
                    start()
                }
                
                flipToMuteManager?.startListening()
                
                // FORCE IMMEDIATE UI UPDATE FOR ONGOING NOTIFICATION AND WIDGETS
                syncFromSharedPrefs() 
                
            } catch (e: Exception) {
                e.printStackTrace()
                stopAudio()
            }
        } else {
            NotificationQueueManager.onAudioFinished(this)
        }
    }

    private fun resolveSoundUri(soundName: String, audioPath: String?, customSoundName: String?, alarmId: Int): Uri? {
        val cleanName = soundName.replace(".mp3", "").lowercase().trim()
        val cleanCustomName = customSoundName?.replace(".mp3", "")?.lowercase()?.trim()

        if (audioPath != null && File(audioPath).exists()) {
            return Uri.fromFile(File(audioPath))
        }

        // Prioritize custom sound if valid
        if (cleanCustomName != null && cleanCustomName != "default" && cleanCustomName.isNotEmpty()) {
            val resId = resources.getIdentifier(cleanCustomName, "raw", packageName)
            if (resId != 0) return Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$resId")
        }

        // Fallback for Adhan
        if (isAdhan(alarmId) && (cleanName == "default" || cleanName == "" || cleanName == "null")) {
            val nafisId = resources.getIdentifier("nafis", "raw", packageName)
            if (nafisId != 0) return Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$nafisId")
        }

        // Try standard sound name
        if (cleanName != "default" && cleanName != "silent" && cleanName != "none" && cleanName != "null") {
            var resId = resources.getIdentifier(cleanName, "raw", packageName)
            if (resId == 0) resId = resources.getIdentifier("adhan_$cleanName", "raw", packageName)
            if (resId == 0) resId = resources.getIdentifier("full_adhan_$cleanName", "raw", packageName)
            if (resId != 0) return Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$resId")
        }

        // Ultimate Fallback to App Default Tone
        val appToneId = resources.getIdentifier("ibad_al_rahmann_tone", "raw", packageName)
        if (appToneId != 0) {
            return Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$appToneId")
        }
        
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    private fun isAdhan(id: Int): Boolean = id in 100..139 || id == 110 || id == 99999

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (e: Exception) { e.printStackTrace() }
        mediaPlayer = null
        flipToMuteManager?.stopListening()
        audioVolumeManager.restoreState() // Restoration guarantee
        NotificationQueueManager.onAudioFinished(this)
    }

    private fun showSoundNotification(intent: Intent, alarmId: Int, isSilent: Boolean = false) {
        val title = intent.getStringExtra("title") ?: "تنبيه"
        val body = intent.getStringExtra("body") ?: ""
        
        NativeLogger.log(this, "Notification Fired! Title: $title | Body: $body | AlarmId: $alarmId | Silent: $isSilent")
        
        val payload = intent.getStringExtra("target_page") ?: "home"
        val soundName = intent.getStringExtra("sound_name") ?: "default"
        val customSoundName = intent.getStringExtra("custom_sound_name")
        val audioPath = intent.getStringExtra("audio_path")

        val stopIntent = Intent(this, NotificationActionReceiver::class.java).apply { action = "STOP_SOUND" }
        val stopPendingIntent = PendingIntent.getBroadcast(this, alarmId + 10000, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val fullIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val fullPendingIntent = PendingIntent.getActivity(this, alarmId, fullIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "prayer_sound_channel_v10"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create Groups
            notificationManager.createNotificationChannelGroup(android.app.NotificationChannelGroup("prayer_group", "إشعارات الصلاة"))
            notificationManager.createNotificationChannelGroup(android.app.NotificationChannelGroup("general_group", "إشعارات عامة"))

            // Create Channel and assign to Prayer Group
            val channel = NotificationChannel(channelId, "صوت الأذان والتنبيهات", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null) 
                enableVibration(true)
                group = "prayer_group" // Assign to group
            }
            notificationManager.createNotificationChannel(channel)
        }

        val isPrayerGroup = alarmId in 100..139 || alarmId in 3000..3099 || alarmId in 5000..5099 || alarmId == 110 || alarmId in 730..739
        val notifGroup    = if (isPrayerGroup) "PRAYER_GROUP" else "GENERAL_GROUP"
        val summaryTitle  = if (isPrayerGroup) "مواقيت الصلاة" else "تنبيهات عامة"

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(false) // User can swipe it
            .setAutoCancel(false) // But it won't disappear automatically
            .addAction(android.R.drawable.ic_media_pause, "إيقاف الصوت", stopPendingIntent)
            .setContentIntent(fullPendingIntent)
            .setGroup(notifGroup)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_ALL)

        // For Adhans, we can still use full screen intent to show over lock screen
        if (isAdhan(alarmId)) {
            builder.setFullScreenIntent(fullPendingIntent, true)
        }

        val bitmap = getLargeIconForPayload(payload, alarmId)
        if (bitmap != null) builder.setLargeIcon(bitmap)

        if (isSilent) {
            notificationManager.notify(alarmId, builder.build())
        } else {
            notificationManager.notify(alarmId, builder.build())
        }

        // Update the appropriate notification group summary (Prayer or General)
        val summaryId    = if (isPrayerGroup) 666 else 667
        val groupSummary = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(summaryTitle)
            .setSubText(summaryTitle)
            .setGroup(notifGroup)
            .setGroupSummary(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_ALL)
            .build()
        notificationManager.notify(summaryId, groupSummary)
    }

    private fun getLargeIconForPayload(payload: String, alarmId: Int): android.graphics.Bitmap? {
        val resName = when {
            payload == "sabah" || payload == "morning" -> "ic_sabah"
            payload == "masaa" || payload == "night" -> "ic_masaa"
            payload.contains("fasting") || alarmId in 720..729 -> "ic_fasting"
            payload.contains("khatma") || payload.contains("wird") -> "ic_wird"
            payload == "salawat" || alarmId in 8000..9500 -> "ic_salawat"
            payload == "jumuah" || payload == "kahf" || alarmId in 705..719 -> "ic_jumuah"
            isAdhan(alarmId) -> "logo" // Default logo for Adhan
            else -> "logo"
        }
        if (resName != null) {
            try {
                val resId = resources.getIdentifier(resName, "drawable", packageName)
                if (resId != 0) return android.graphics.BitmapFactory.decodeResource(resources, resId)
            } catch (e: Exception) { }
        }
        return null
    }

    private fun isPersistentNotificationEnabled(): Boolean {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("persistent_notification_enabled", true)
    }

    private fun handleUpdateIntent(intent: Intent) {
        val fajr = intent.getStringExtra("fajr") ?: "--:--"
        val dhuhr = intent.getStringExtra("dhuhr") ?: "--:--"
        val asr = intent.getStringExtra("asr") ?: "--:--"
        val maghrib = intent.getStringExtra("maghrib") ?: "--:--"
        val isha = intent.getStringExtra("isha") ?: "--:--"
        val nextName = intent.getStringExtra("nextName") ?: "انتظر"
        val countdown = intent.getStringExtra("countdown") ?: ""
        val hijri = intent.getStringExtra("hijri") ?: ""
        val currentPrayerIndex = intent.getIntExtra("prayerIndex", -1)
        val nextPrayerEpoch = intent.getLongExtra("next_prayer_time_epoch", 0L)
        val isCountUp = intent.getBooleanExtra("isCountUp", false)

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("fajr", fajr); putString("dhuhr", dhuhr); putString("asr", asr); putString("maghrib", maghrib); putString("isha", isha)
            putString("nextName", nextName); putString("hijri", hijri); putInt("prayerIndex", currentPrayerIndex)
            putLong("next_prayer_time_epoch", nextPrayerEpoch); putBoolean("is_count_up", isCountUp)
            apply()
        }

        val notification = buildPersistentNotification(fajr, dhuhr, asr, maghrib, isha, nextName, countdown, hijri, currentPrayerIndex, nextPrayerEpoch, isCountUp)
        startForegroundSafe(777, notification)
        updateAllWidgets()
        scheduleNextUpdate(currentPrayerIndex, nextPrayerEpoch, isCountUp)
    }

    private fun syncFromSharedPrefs(startId: Int = -1) {
        if (!isPersistentNotificationEnabled()) {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                stopForeground(true)
                if (startId != -1) stopSelf(startId) else stopSelf()
            }, 1500)
            return
        }

        // CRITICAL: On Android 8+, startForeground() MUST be called within 5 seconds
        // of startForegroundService(). We call it immediately with a minimal notification
        // to satisfy Android, then update it with real data below.
        val channelId = "persistent_prayer_v11"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(channelId, "شريط وقت الصلاة", NotificationManager.IMPORTANCE_MAX)
            ch.setShowBadge(false); ch.setSound(null, null); ch.enableVibration(false)
            nm.createNotificationChannel(ch)
        }
        val placeholderNotif = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("عباد الرحمن")
            .setContentText("جاري تحميل مواقيت الصلاة...")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setSilent(true)
            .build()
        startForegroundSafe(777, placeholderNotif)

        val now = System.currentTimeMillis()
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        // Retrieve today's epoch times from prefs or calculate them
        var fajr = PrayerDataPatcher.getSafeLong(prefs, "fajr_epoch", 0L)

        if (fajr <= 0L) {
            // Attempt native calculation. If it fails, leave the placeholder notification and return.
            val times = NativePrayerManager.calculatePrayerTimes(this)
            if (times != null) {
                fajr = times.fajr.time
            } else {
                // startForeground already called above — service stays alive with placeholder
                return 
            }
        }

        var dhuhr = PrayerDataPatcher.getSafeLong(prefs, "dhuhr_epoch", 0L)
        var asr = PrayerDataPatcher.getSafeLong(prefs, "asr_epoch", 0L)
        var maghrib = PrayerDataPatcher.getSafeLong(prefs, "maghrib_epoch", 0L)
        var isha = PrayerDataPatcher.getSafeLong(prefs, "isha_epoch", 0L)

        val times = NativePrayerManager.calculatePrayerTimes(this)
        if (dhuhr == 0L && times != null) {
            dhuhr = times.dhuhr.time; asr = times.asr.time; maghrib = times.maghrib.time; isha = times.isha.time
        }

        val cal = java.util.Calendar.getInstance()
        cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
        val tomorrow = NativePrayerManager.calculatePrayerTimes(this, cal.time)
        val nextFajr = tomorrow?.fajr?.time ?: (isha + 8 * 3600 * 1000L)

        // Calculate Expiry/Switch Thresholds
        val fajrThreshold = fajr + (60 * 60 * 1000L)
        val dhuhrThreshold = dhuhr + (45 * 60 * 1000L)
        val asrThreshold = asr + (45 * 60 * 1000L)
        val maghribThreshold = maghrib + ((isha - maghrib) / 2)
        val ishaThreshold = isha + (60 * 60 * 1000L)

        var targetName = ""
        var targetEpoch = 0L
        var activeIndex = 0

        when {
            now < fajrThreshold -> {
                targetName = "الفجر"; targetEpoch = fajr; activeIndex = 0
            }
            now < dhuhrThreshold -> {
                targetName = "الظهر"; targetEpoch = dhuhr; activeIndex = 1
            }
            now < asrThreshold -> {
                targetName = "العصر"; targetEpoch = asr; activeIndex = 2
            }
            now < maghribThreshold -> {
                targetName = "المغرب"; targetEpoch = maghrib; activeIndex = 3
            }
            now < ishaThreshold -> {
                targetName = "العشاء"; targetEpoch = isha; activeIndex = 4
            }
            else -> {
                targetName = "الفجر"; targetEpoch = nextFajr; activeIndex = 0
            }
        }

        val isCountingUp = now >= targetEpoch
        val statusName = if (isCountingUp) "مضى على $targetName" else "الصلاة القادمة: $targetName"
        
        val hijriStr = NativePrayerManager.getHijriDate(this)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val is24H = flutterPrefs.getBoolean("flutter.is_24_hour", false)
        val fmt = java.text.SimpleDateFormat(if (is24H) "HH:mm" else "hh:mm a", java.util.Locale(if (is24H) "en" else "ar"))

        val notification = if (times != null) {
            buildPersistentNotification(fmt.format(times.fajr), fmt.format(times.dhuhr), fmt.format(times.asr), fmt.format(times.maghrib), fmt.format(times.isha), statusName, "", hijriStr, activeIndex, targetEpoch, isCountingUp)
        } else {
            // Fallback to stored strings
            buildPersistentNotification(prefs.getString("fajr", "--:--")!!, prefs.getString("dhuhr", "--:--")!!, prefs.getString("asr", "--:--")!!, prefs.getString("maghrib", "--:--")!!, prefs.getString("isha", "--:--")!!, statusName, "", hijriStr, activeIndex, targetEpoch, isCountingUp)
        }
        
        startForegroundSafe(777, notification)
        scheduleNextUpdate(activeIndex, targetEpoch, isCountingUp)
        updateAllWidgets()

        // The notification is now built and sent. Now, force the Home Screen widgets to sync!
        AlarmReceiver.forceUpdateAllWidgets(this)
    }

    private fun updateAllWidgets() {
        val providers = arrayOf(PrayerWidgetProvider::class.java, PrayerWidgetLargeProvider::class.java)
        for (provider in providers) {
            val intent = Intent(this, provider).apply { action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE }
            val ids = android.appwidget.AppWidgetManager.getInstance(this).getAppWidgetIds(android.content.ComponentName(this, provider))
            if (ids.isNotEmpty()) {
                intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                sendBroadcast(intent)
            }
        }
    }

    private fun scheduleNextUpdate(currentIndex: Int, targetEpoch: Long, isCountUp: Boolean) {
        val now = System.currentTimeMillis()
        var delay = 0L
        
        if (isCountUp) {
            val window = when (currentIndex) {
                3 -> {
                    val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val maghrib = PrayerDataPatcher.getSafeLong(prefs, "maghrib_epoch", targetEpoch)
                    val isha = PrayerDataPatcher.getSafeLong(prefs, "isha_epoch", maghrib + 90 * 60 * 1000L)
                    (isha - maghrib) / 2
                }
                1, 2 -> 45 * 60 * 1000L
                else -> 60 * 60 * 1000L
            }
            delay = (targetEpoch + window) - now
        } else {
            delay = targetEpoch - now
        }

        if (delay > 0) {
            val intent = Intent(this, PrayerNotificationService::class.java).apply { action = "SYNC" }
            val pi = PendingIntent.getForegroundService(this, 9995, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) am.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + delay + 1000, pi)
            else am.setExact(android.app.AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + delay + 1000, pi)
        }
    }

    private fun buildPersistentNotification(fajr: String, dhuhr: String, asr: String, maghrib: String, isha: String, nextName: String, countdown: String, hijri: String, activeIndex: Int, nextPrayerEpoch: Long, isCountUp: Boolean): Notification {
        val channelId = "persistent_prayer_v11"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "شريط وقت الصلاة", NotificationManager.IMPORTANCE_MAX)
            channel.setShowBadge(false); channel.setSound(null, null); channel.enableVibration(false)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val collapsedView = RemoteViews(packageName, R.layout.notification_collapsed)
        collapsedView.setTextViewText(R.id.tv_next_prayer_name, toArabicDigits(nextName))
        collapsedView.setTextViewText(R.id.tv_hijri_date, toArabicDigits(hijri))
        val expandedView = RemoteViews(packageName, R.layout.custom_notification)
        fun setTime(timeStr: String, timeId: Int, ampmId: Int) {
            val parts = timeStr.trim().split(" ")
            expandedView.setTextViewText(timeId, toArabicDigits(parts.getOrNull(0) ?: timeStr))
            expandedView.setTextViewText(ampmId, parts.getOrNull(1) ?: "")
        }
        setTime(fajr, R.id.tv_fajr_time, R.id.tv_fajr_am_pm); setTime(dhuhr, R.id.tv_dhuhr_time, R.id.tv_dhuhr_am_pm)
        setTime(asr, R.id.tv_asr_time, R.id.tv_asr_am_pm); setTime(maghrib, R.id.tv_maghrib_time, R.id.tv_maghrib_am_pm)
        setTime(isha, R.id.tv_isha_time, R.id.tv_isha_am_pm)
        expandedView.setTextViewText(R.id.tv_next_prayer_name, toArabicDigits(nextName))
        expandedView.setTextViewText(R.id.tv_hijri_date, toArabicDigits(hijri))
        val differenceMs = nextPrayerEpoch - System.currentTimeMillis()
        val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
        val formatStr = if (isCountUp) "+%s" else "-%s"
        collapsedView.setChronometer(R.id.tv_next_prayer_countdown, baseTime, formatStr, true)
        expandedView.setChronometer(R.id.tv_next_prayer_countdown, baseTime, formatStr, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            collapsedView.setChronometerCountDown(R.id.tv_next_prayer_countdown, !isCountUp)
            expandedView.setChronometerCountDown(R.id.tv_next_prayer_countdown, !isCountUp)
        }
        val accent = Color.parseColor("#D0A871")
        val white = Color.WHITE
        val tIds = intArrayOf(R.id.tv_fajr_time, R.id.tv_dhuhr_time, R.id.tv_asr_time, R.id.tv_maghrib_time, R.id.tv_isha_time)
        val aIds = intArrayOf(R.id.tv_fajr_am_pm, R.id.tv_dhuhr_am_pm, R.id.tv_asr_am_pm, R.id.tv_maghrib_am_pm, R.id.tv_isha_am_pm)
        val lIds = intArrayOf(R.id.tv_fajr_label, R.id.tv_dhuhr_label, R.id.tv_asr_label, R.id.tv_maghrib_label, R.id.tv_isha_label)
        for (i in 0..4) {
            val c = if (i == activeIndex) accent else white
            expandedView.setTextColor(tIds[i], c); expandedView.setTextColor(aIds[i], c); expandedView.setTextColor(lIds[i], c)
        }
        expandedView.setTextColor(R.id.tv_next_prayer_name, accent); expandedView.setTextColor(R.id.tv_next_prayer_countdown, accent)
        val intent = Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        
        collapsedView.setOnClickPendingIntent(R.id.root_collapsed, pi)
        expandedView.setOnClickPendingIntent(R.id.root_expanded, pi)

        return NotificationCompat.Builder(this, channelId).setSmallIcon(R.mipmap.launcher_icon).setCustomContentView(collapsedView).setCustomBigContentView(expandedView).setStyle(NotificationCompat.DecoratedCustomViewStyle()).setOngoing(true).setPriority(NotificationCompat.PRIORITY_MAX).setCategory(NotificationCompat.CATEGORY_STATUS).setWhen(System.currentTimeMillis()).setSilent(true).setShowWhen(false).setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE).setContentIntent(pi).build()
    }

    private fun toArabicDigits(input: String): String {
        val eng = arrayOf("0","1","2","3","4","5","6","7","8","9")
        val ara = arrayOf("٠","١","٢","٣","٤","٥","٦","٧","٨","٩")
        var res = input
        for (i in eng.indices) res = res.replace(eng[i], ara[i])
        return res
    }

    override fun onDestroy() {
        stopAudio()
        audioVolumeManager.restoreState() // Safety guarantee
        refreshHandler.removeCallbacks(refreshRunnable)
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
