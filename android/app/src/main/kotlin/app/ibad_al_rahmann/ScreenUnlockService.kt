package app.ibad_al_rahmann

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * ScreenUnlockService — يشغّل صوت الصلاة على النبي ﷺ عند فتح قفل الشاشة.
 *
 * - يعمل كـ foreground service خفيف (الإشعار قابل للإخفاء على API 33+)
 * - يستمع لـ ACTION_USER_PRESENT (ما بعد رفع القفل بالكامل)
 * - يقرأ إعدادات الصوت من FlutterSharedPreferences:
 *     • flutter.salah_unlock_mode   — اسم الملف الصوتي (saly_3ala_mo7amad / salah_2 / both)
 *     • flutter.salah_unlock_volume — مستوى الصوت 0.0–1.0 (مستقل عن إعدادات الأذان)
 * - يُوقف التشغيل السابق إذا وصل فتح جديد للشاشة قبل انتهاء الصوت
 */
class ScreenUnlockService : Service() {

    companion object {
        private const val TAG           = "ScreenUnlockSvc"
        private const val CHANNEL_ID    = "screen_unlock_salawat_channel"
        private const val NOTIF_ID      = 7777

        /** مساعد لإيقاف الخدمة من الخارج (من BackgroundMethodChannelPlugin) */
        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenUnlockService::class.java))
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var screenReceiver: BroadcastReceiver? = null

    // ──────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildSilentNotification())
        registerScreenReceiver()
        Log.d(TAG, "Service started — listening for screen unlock")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        super.onDestroy()
        unregisterScreenReceiver()
        releasePlayer()
        Log.d(TAG, "Service stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ──────────────────────────────────────────────────────────────────────────
    // Screen Receiver
    // ──────────────────────────────────────────────────────────────────────────

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_USER_PRESENT) {
                    Log.d(TAG, "Screen unlocked — playing salawat")
                    playSalawat()
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    private fun unregisterScreenReceiver() {
        screenReceiver?.let {
            try { unregisterReceiver(it) } catch (e: Exception) { /* already unregistered */ }
            screenReceiver = null
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Audio Playback
    // ──────────────────────────────────────────────────────────────────────────

    private var originalVolume: Int? = null
    private var targetStream: Int = AudioManager.STREAM_MUSIC

    private fun playSalawat() {
        releasePlayer() // أوقف أي صوت سابق فوراً

        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val mode = prefs.getString("flutter.salah_unlock_mode", "saly_3ala_mo7amad") ?: "saly_3ala_mo7amad"
        if (mode == "none") return

        // Check if custom volume override is enabled
        val useCustomVolume = prefs.getBoolean("flutter.salah_unlock_use_custom_volume", false)

        // Read volume ratio (0.0 .. 1.0)
        val volumeRatio = try {
            val v = prefs.getFloat("flutter.salah_unlock_volume", 1.0f)
            if (v > 0) v else 1.0f
        } catch (_: Exception) {
            1.0f
        }.coerceIn(0.1f, 1.0f)

        // Adjust system volume temporarily only if user enabled custom volume
        if (useCustomVolume) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                try {
                    targetStream = AudioManager.STREAM_MUSIC
                    val maxVol = audioManager.getStreamMaxVolume(targetStream)
                    originalVolume = audioManager.getStreamVolume(targetStream)
                    val targetVol = (maxVol * volumeRatio).toInt().coerceIn(1, maxVol)
                    audioManager.setStreamVolume(targetStream, targetVol, 0)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not adjust system volume: ${e.message}")
                }
            }
        } else {
            originalVolume = null
        }

        val customPath = prefs.getString("flutter.salah_unlock_custom_path", null)

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setLegacyStreamType(targetStream)
                        .build()
                )

                if (mode == "custom" && !customPath.isNullOrEmpty() && java.io.File(customPath).exists()) {
                    setDataSource(customPath)
                } else {
                    val soundName = when (mode) {
                        "both" -> if (Math.random() < 0.5) "saly_3ala_mo7amad" else "salah_2"
                        "custom" -> "saly_3ala_mo7amad" // Fallback if custom file not found
                        else -> mode
                    }
                    val assetPath = "assets/audio/$soundName.mp3"
                    val afd = applicationContext.assets.openFd(assetPath)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                }

                isLooping = false
                setOnCompletionListener { releasePlayer() }
                setOnErrorListener { _, _, _ -> releasePlayer(); true }
                prepare()
                start()
            }
            Log.d(TAG, "Playing salawat mode=$mode at volume ratio $volumeRatio")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play salawat: ${e.message}")
            releasePlayer()
        }
    }

    private fun releasePlayer() {
        // Restore system volume if it was elevated
        if (originalVolume != null) {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                audioManager?.setStreamVolume(targetStream, originalVolume!!, 0)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to restore original volume: ${e.message}")
            }
            originalVolume = null
        }

        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (e: Exception) { /* ignore */ }
            mediaPlayer = null
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Notification (foreground requirement — minimal, dismissible on API 33+)
    // ──────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "تذكير الصلاة على النبي",
                NotificationManager.IMPORTANCE_MIN   // لا صوت ولا اهتزاز للإشعار نفسه
            ).apply {
                description = "يعمل بصمت في الخلفية لتشغيل الصلاة على النبي ﷺ عند فتح الشاشة"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildSilentNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("الصلاة على النبي ﷺ")
            .setContentText("يعمل في الخلفية عند فتح الشاشة")
            .setSmallIcon(android.R.drawable.star_on)
            .setPriority(Notification.PRIORITY_MIN)
            .build()
    }
}
