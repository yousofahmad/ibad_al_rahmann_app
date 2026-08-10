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

    private fun playSalawat() {
        releasePlayer() // أوقف أي صوت سابق فوراً

        val prefs     = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val mode      = prefs.getString("flutter.salah_unlock_mode", "saly_3ala_mo7amad") ?: "saly_3ala_mo7amad"
        val volume    = prefs.getFloat("flutter.salah_unlock_volume", 1.0f)
            .coerceIn(0.0f, 1.0f)

        // اختر الصوت
        val soundName = when (mode) {
            "both"   -> if (Math.random() < 0.5) "saly_3ala_mo7amad" else "salah_2"
            "none"   -> return  // مُعطَّل
            else     -> mode    // "saly_3ala_mo7amad" أو "salah_2" مباشرةً
        }

        val assetPath = "assets/audio/$soundName.mp3"

        try {
            val afd = applicationContext.assets.openFd(assetPath)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setLegacyStreamType(AudioManager.STREAM_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setVolume(volume, volume)
                isLooping = false
                setOnCompletionListener { releasePlayer() }
                setOnErrorListener { _, _, _ -> releasePlayer(); true }
                prepare()
                start()
            }
            Log.d(TAG, "Playing: $soundName at volume $volume")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play salawat: ${e.message}")
            releasePlayer()
        }
    }

    private fun releasePlayer() {
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
