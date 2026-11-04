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
            if (context != null) {
                val stopIntent = Intent(context, PrayerNotificationService::class.java).apply {
                    action = "STOP_SOUND"
                }
                try {
                    androidx.core.content.ContextCompat.startForegroundService(context, stopIntent)
                    NativeLogger.log(context, "NotificationDismissReceiver: forwarded audio stop to PrayerNotificationService")
                } catch (e: Exception) {
                    NativeLogger.log(context, "NotificationDismissReceiver: foreground stop request failed; errorType=${e.javaClass.simpleName}")
                    try {
                        context.startService(stopIntent)
                    } catch (fallbackError: Exception) {
                        NativeLogger.log(context, "NotificationDismissReceiver: stop fallback failed; errorType=${fallbackError.javaClass.simpleName}")
                    }
                }
            }
        }

        fun startFlipToMute(context: Context) {
            if (flipToMuteManager == null) {
                flipToMuteManager = FlipToMuteManager(context)
            }
            flipToMuteManager?.startListening()
        }

        fun cleanupEmptyGroupSummaries(context: Context, dismissedAlarmId: Int = -1) {
            if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M) return

            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                val activeEntries = notificationManager.activeNotifications
                    ?.map { sbn -> ActiveNotificationGroupEntry(sbn.id, sbn.notification.group) }
                    .orEmpty()
                val summariesToCancel = NotificationGroupCleanupPolicy.summariesToCancel(
                    activeEntries,
                    dismissedNotificationId = dismissedAlarmId,
                )

                for (summaryId in summariesToCancel) {
                    val groupName = if (summaryId == NotificationGroupCleanupPolicy.PRAYER_SUMMARY_ID) {
                        NotificationGroupCleanupPolicy.PRAYER_GROUP
                    } else {
                        NotificationGroupCleanupPolicy.GENERAL_GROUP
                    }
                    NativeLogger.log(context, "NotificationDismissReceiver: No active children in $groupName. Cancelling summary $summaryId.")
                    notificationManager.cancel(summaryId)
                }
            } catch (e: Exception) {
                NativeLogger.log(context, "NotificationDismissReceiver: group summary cleanup failed; errorType=${e.javaClass.simpleName}")
            }
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
        cleanupEmptyGroupSummaries(context, alarmId)
    }
}
