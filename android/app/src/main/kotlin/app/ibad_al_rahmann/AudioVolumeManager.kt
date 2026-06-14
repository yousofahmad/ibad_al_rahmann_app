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
    private var isStateCaptured = false

    /**
     * يلتقط الحالة الحالية للجهاز.
     */
    fun captureState() {
        if (isStateCaptured) return // لا تكرر الالتقاط إذا كان هناك صوت يعمل
        
        originalRingerMode = audioManager.ringerMode
        originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        isStateCaptured = true
    }

    /**
     * يطبق إعدادات المستخدم (تخطى الصامت + مستوى الصوت المخصص).
     */
    fun applySettings(targetVolumePercent: Int, bypassSilent: Boolean) {
        if (!isStateCaptured) captureState()

        try {
            if (bypassSilent && audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            }
        } catch (e: SecurityException) {
            // Cannot change ringer mode without ACCESS_NOTIFICATION_POLICY permission
            e.printStackTrace()
        }

        try {
            // تحويل النسبة المئوية إلى مستوى صوت فعلي
            val maxAlarmVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val targetAlarmVol = (maxAlarmVol * (targetVolumePercent / 100.0)).toInt()
            
            val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetMusicVol = (maxMusicVol * (targetVolumePercent / 100.0)).toInt()

            // تطبيق الصوت على القنوات المعنية (الأذان غالباً ALARM أو MUSIC)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetAlarmVol, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetMusicVol, 0)
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
            // استرجاع مستوى الصوت أولاً
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalMusicVolume, 0)
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
