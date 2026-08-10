package app.ibad_al_rahmann

import android.content.Context
import android.media.AudioManager
import android.os.Build

/**
 * مسئول عن إدارة مستويات الصوت وحالة الرنين للجهاز.
 * يقوم بحفظ الحالة قبل الأذان واسترجاعها بدقة بعد الانتهاء.
 */
class AudioVolumeManager(private val context: Context) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    
    private var originalRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private var originalAlarmVolume: Int = 0
    private var originalMusicVolume: Int = 0
    private var originalRingVolume: Int = 0
    private var originalSpeakerphoneOn: Boolean = false
    private var originalMode: Int = AudioManager.MODE_NORMAL
    private var isStateCaptured = false

    /**
     * يلتقط الحالة الحالية للجهاز.
     */
    fun captureState() {
        if (isStateCaptured) return // لا تكرر الالتقاط إذا كان هناك صوت يعمل
        
        originalRingerMode = audioManager.ringerMode
        originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        originalRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
        originalSpeakerphoneOn = audioManager.isSpeakerphoneOn
        originalMode = audioManager.mode
        isStateCaptured = true
    }

    /**
     * يطبق إعدادات المستخدم (تخطى الصامت + مستوى الصوت المخصص).
     */
    fun applySettings(targetVolumePercent: Int, bypassSilent: Boolean, forceSpeaker: Boolean) {
        if (!isStateCaptured) captureState()

        try {
            if (bypassSilent && audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }

        try {
            if (forceSpeaker) {
                // MODE_IN_COMMUNICATION forces audio to the earpiece on many phones!
                // We MUST use MODE_NORMAL for the speaker.
                // audioManager.mode = AudioManager.MODE_NORMAL
                // audioManager.isSpeakerphoneOn = true is also not needed for STREAM_ALARM.
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            if (targetVolumePercent >= 0) {
                // تحويل النسبة المئوية إلى مستوى صوت فعلي
                val maxAlarmVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                val targetAlarmVol = (maxAlarmVol * (targetVolumePercent / 100.0)).toInt()
                
                val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val targetMusicVol = (maxMusicVol * (targetVolumePercent / 100.0)).toInt()
                
                val maxRingVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
                val targetRingVol = (maxRingVol * (targetVolumePercent / 100.0)).toInt()

                // تطبيق الصوت على القنوات المعنية
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetAlarmVol, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetMusicVol, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_RING, targetRingVol, 0)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * يسترجع الحالة الأصلية للجهاز.
     */
    fun restoreState() {
        if (!isStateCaptured) return

        try {
            audioManager.isSpeakerphoneOn = originalSpeakerphoneOn
            audioManager.mode = originalMode
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            // استرجاع مستوى الصوت أولاً
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalMusicVolume, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, originalRingVolume, 0)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        try {
            // استرجاع حالة الرنين
            audioManager.ringerMode = originalRingerMode
        } catch (e: Exception) {
            e.printStackTrace()
        }

        isStateCaptured = false
    }
}
