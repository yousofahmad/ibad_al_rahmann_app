package app.ibad_al_rahmann

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer

import android.media.AudioManager

class NotificationDismissReceiver : BroadcastReceiver() {
    companion object {
        var activeMediaPlayer: MediaPlayer? = null
        private var flipToMuteManager: FlipToMuteManager? = null
        
        var originalVolume: Int = -1
        var originalStreamType: Int = AudioManager.STREAM_MUSIC

        fun stopSound(context: Context? = null) {
            try {
                flipToMuteManager?.stopListening()
                activeMediaPlayer?.let {
                    try {
                        if (it.isPlaying) it.stop()
                    } catch (_: Exception) {}
                    try {
                        it.release()
                    } catch (_: Exception) {}
                }
                
                // Restore volume if it was saved (either in static var or SharedPreferences backup)
                if (context != null) {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val volPrefs = context.getSharedPreferences("VolumeBackup", Context.MODE_PRIVATE)
                    
                    val vol = if (originalVolume != -1) originalVolume else volPrefs.getInt("orig_vol", -1)
                    val stream = if (originalVolume != -1) originalStreamType else volPrefs.getInt("orig_stream", AudioManager.STREAM_MUSIC)
                    
                    if (vol != -1) {
                        try {
                            audioManager.setStreamVolume(stream, vol, 0)
                        } catch (_: Exception) {}
                        // Clear backups
                        originalVolume = -1
                        volPrefs.edit().clear().apply()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            activeMediaPlayer = null
        }

        fun startFlipToMute(context: Context) {
            if (flipToMuteManager == null) {
                flipToMuteManager = FlipToMuteManager(context)
            }
            flipToMuteManager?.startListening()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val alarmId = intent.getIntExtra("alarm_id", -1)
        NativeLogger.log(context, "NotificationDismissReceiver: Action: $action. AlarmId: $alarmId")
        stopSound(context)
        if (alarmId != -1) {
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                nm.cancel(alarmId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
