package app.ibad_al_rahmann

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

object AudioVibrationManager {
    
    /**
     * يقيم حالة الصوت والاهتزاز بدقة بناءً على القواعد الصارمة:
     * 1. صوت التطبيق صامت ("none", "silent_notif", "silent", "ruqyah") -> لا صوت إطلاقاً (false).
     * 2. الموبايل في وضع صامت (RINGER_MODE_SILENT) -> لا صوت إطلاقاً (false).
     * 3. الموبايل في وضع اهتزاز (RINGER_MODE_VIBRATE) -> لا صوت إطلاقاً (false).
     * 4. بخلاف ذلك (وضع رنين عادي + صوت غير صامت) -> السماح بتشغيل الصوت (true).
     */
    fun evaluateAudioVibrationState(context: Context, soundName: String, overrideSilent: Boolean = false): Boolean {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()
        if (cleanSoundName == "none" || cleanSoundName == "null" || cleanSoundName.isEmpty()) return false

        val isAppSilent = cleanSoundName == "silent_notif" || cleanSoundName == "ruqyah" || cleanSoundName == "silent"
        if (isAppSilent) {
            if (cleanSoundName != "ruqyah") {
                triggerVibration(context)
            }
            return false
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val ringerMode = audioManager.ringerMode
        
        // إذا كان الموبايل في وضع صامت أو اهتزاز -> منع الصوت منعاً باتاً
        if (ringerMode == AudioManager.RINGER_MODE_SILENT || ringerMode == AudioManager.RINGER_MODE_VIBRATE) {
            return false
        }

        return true
    }

    private fun triggerVibration(context: Context) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 500, 300, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
