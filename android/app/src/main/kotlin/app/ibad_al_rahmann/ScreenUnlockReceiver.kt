package app.ibad_al_rahmann

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File

/**
 * ScreenUnlockReceiver — يستمع لحدث فتح الشاشة (ACTION_USER_PRESENT)
 * ويشغل صوت الصلاة على النبي ﷺ فوراً بـ 0ms delay عبر SoundPool مع Debounce مانع للتكرار.
 */
class ScreenUnlockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScreenUnlockReceiver"
        private var soundPool: SoundPool? = null
        private val soundMap = HashMap<String, Int>()
        private var isSoundPoolReady = false
        private var lastPlayTime: Long = 0L

        private var mediaPlayer: MediaPlayer? = null
        private var originalVolume: Int? = null
        private var targetStream: Int = AudioManager.STREAM_MUSIC
        private var activeFocusRequest: Any? = null

        fun initSoundPool(context: Context) {
            if (soundPool != null && soundMap.isNotEmpty()) return  // Only skip if both pool AND sounds are loaded
            try {
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                val pool = SoundPool.Builder()
                    .setMaxStreams(1)
                    .setAudioAttributes(attributes)
                    .build()

                val res1 = context.resources.getIdentifier("saly_3ala_mo7amad", "raw", context.packageName)
                val res2 = context.resources.getIdentifier("salah_2", "raw", context.packageName)

                if (res1 != 0) soundMap["saly_3ala_mo7amad"] = pool.load(context, res1, 1)
                if (res2 != 0) soundMap["salah_2"] = pool.load(context, res2, 1)

                soundPool = pool
                isSoundPoolReady = true
                Log.d(TAG, "SoundPool initialized and raw sounds pre-loaded for 0ms delay")
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing SoundPool: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_USER_PRESENT && action != Intent.ACTION_SCREEN_ON) return

        // For ACTION_SCREEN_ON, only trigger if device has NO screen lock (not keyguard-locked)
        if (action == Intent.ACTION_SCREEN_ON) {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            val isLocked = keyguardManager?.isKeyguardLocked ?: false
            if (isLocked) {
                // Device has a lock screen / PIN / password; wait for ACTION_USER_PRESENT
                return
            }
        }

        // 10-second debounce
        val now = System.currentTimeMillis()
        if (now - lastPlayTime < 10000L) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("flutter.salah_unlock_enabled", false)
            || prefs.getBoolean("salah_unlock_enabled", false)
        if (!isEnabled) return

        // Check Silent / Vibrate mode - never play sound if user set device to Silent or Vibrate
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager != null) {
            val ringerMode = audioManager.ringerMode
            if (ringerMode == AudioManager.RINGER_MODE_SILENT || ringerMode == AudioManager.RINGER_MODE_VIBRATE) {
                Log.d(TAG, "Skipping screen unlock salawat because device is in Silent/Vibrate mode")
                return
            }
        }

        // Check quiet hours
        val quietHoursEnabled = prefs.getBoolean("flutter.quiet_hours_enabled", false)
            || prefs.getBoolean("quiet_hours_enabled", false)
        if (quietHoursEnabled && isInQuietHours(prefs)) {
            Log.d(TAG, "Skipping screen unlock salawat due to active quiet hours")
            return
        }

        val mode = prefs.getString("flutter.salah_unlock_mode", "saly_3ala_mo7amad")
            ?: prefs.getString("salah_unlock_mode", "saly_3ala_mo7amad")
            ?: "saly_3ala_mo7amad"

        lastPlayTime = now
        playSalawat(context, mode)
    }

    private fun isInQuietHours(prefs: SharedPreferences): Boolean {
        fun getSafeInt(key: String, def: Int): Int {
            return try {
                if (prefs.contains(key)) prefs.getInt(key, def) else def
            } catch (_: Exception) {
                def
            }
        }
        val startHour = getSafeInt("flutter.quiet_hours_start_hour", 23)
        val startMin = getSafeInt("flutter.quiet_hours_start_minute", 0)
        val endHour = getSafeInt("flutter.quiet_hours_end_hour", 7)
        val endMin = getSafeInt("flutter.quiet_hours_end_minute", 0)

        val cal = java.util.Calendar.getInstance()
        val nowTime = cal.get(java.util.Calendar.HOUR_OF_DAY) + cal.get(java.util.Calendar.MINUTE) / 60.0
        val startTime = startHour + startMin / 60.0
        val endTime = endHour + endMin / 60.0

        return if (startTime > endTime) {
            nowTime >= startTime || nowTime < endTime
        } else {
            nowTime in startTime..endTime
        }
    }

    private fun playSalawat(context: Context, mode: String) {
        initSoundPool(context)
        releasePlayer(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val useCustomVolume = prefs.getBoolean("flutter.salah_unlock_use_custom_volume", false)
            || prefs.getBoolean("salah_unlock_use_custom_volume", false)
        val volumeRatio = try {
            val v = if (prefs.contains("flutter.salah_unlock_volume")) {
                prefs.getFloat("flutter.salah_unlock_volume", 1.0f)
            } else {
                prefs.getFloat("salah_unlock_volume", 1.0f)
            }
            if (v > 0) v else 1.0f
        } catch (_: Exception) {
            1.0f
        }.coerceIn(0.1f, 1.0f)

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

        // Request transient audio focus with ducking so active media ducks
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                val focusRequest = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(playbackAttributes)
                    .setAcceptsDelayedFocusGain(false)
                    .setOnAudioFocusChangeListener { }
                    .build()
                activeFocusRequest = focusRequest
                audioManager?.requestAudioFocus(focusRequest)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "AudioFocus request error: ${e.message}")
        }

        val isHeadphones = audioManager?.isWiredHeadsetOn == true ||
            audioManager?.isBluetoothA2dpOn == true ||
            audioManager?.isBluetoothScoOn == true

        if (audioManager != null) {
            try {
                val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                if (useCustomVolume) {
                    originalVolume = currentVol
                    val targetVol = (maxVol * volumeRatio).toInt().coerceIn(1, maxVol)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
                } else if (!isHeadphones && currentVol < (maxVol * 0.45f).toInt()) {
                    originalVolume = currentVol
                    val targetVol = (maxVol * 0.55f).toInt().coerceIn(1, maxVol)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not adjust system volume: ${e.message}")
            }
        } else {
            originalVolume = null
        }

        val customPath = prefs.getString("flutter.salah_unlock_custom_path", null)

        // Try instant SoundPool playback for built-in audio (0ms latency!)
        val soundId = soundMap[mode]
        if (soundId != null && soundPool != null) {
            val streamId = soundPool!!.play(soundId, volumeRatio, volumeRatio, 1, 0, 1.0f)
            if (streamId != 0) {
                Log.d(TAG, "SoundPool played sound successfully: $mode (stream: $streamId)")
                Handler(Looper.getMainLooper()).postDelayed({
                    restoreVolume(context)
                }, 4500L)
                return
            } else {
                // SoundPool failed (possibly GC'd) — release and re-init for next time
                Log.w(TAG, "SoundPool play returned 0 for $mode — releasing for re-init")
                soundPool?.release()
                soundPool = null
                soundMap.clear()
                isSoundPoolReady = false
            }
        }

        // Fallback to MediaPlayer (e.g. for custom path)
        try {
            val mp: MediaPlayer? = if (mode == "custom" && !customPath.isNullOrEmpty() && File(customPath).exists()) {
                MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(context, Uri.fromFile(File(customPath)))
                    setVolume(volumeRatio, volumeRatio)
                    prepare()
                }
            } else {
                val resName = if (mode == "salah_2") "salah_2" else "saly_3ala_mo7amad"
                val resId = context.resources.getIdentifier(resName, "raw", context.packageName)
                if (resId != 0) {
                    MediaPlayer.create(context, resId)?.apply {
                        setVolume(volumeRatio, volumeRatio)
                    }
                } else null
            }

            if (mp != null) {
                mediaPlayer = mp
                mp.setOnCompletionListener {
                    releasePlayer(context)
                }
                mp.setOnErrorListener { _, _, _ ->
                    releasePlayer(context)
                    true
                }
                mp.start()
            } else {
                restoreVolume(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing salawat: ${e.message}", e)
            releasePlayer(context)
        }
    }

    private fun releasePlayer(context: Context) {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (_: Exception) {}
            mediaPlayer = null
        }
        restoreVolume(context)
    }

    private fun restoreVolume(context: Context) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                (activeFocusRequest as? android.media.AudioFocusRequest)?.let {
                    audioManager?.abandonAudioFocusRequest(it)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
            activeFocusRequest = null

            val orig = originalVolume
            if (orig != null) {
                originalVolume = null
                audioManager?.setStreamVolume(targetStream, orig, 0)
            }
        } catch (_: Exception) {}
    }
}
