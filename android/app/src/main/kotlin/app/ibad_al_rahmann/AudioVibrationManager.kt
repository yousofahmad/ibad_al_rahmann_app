package app.ibad_al_rahmann

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

object AudioVibrationManager {
    
    /**
     * يقيم حالة الصوت والاهتزاز بدقة بناءً على القواعد المطلوبة:
     * 1. RINGER_MODE_SILENT -> لا صوت ولا اهتزاز.
     * 2. RINGER_MODE_VIBRATE -> اهتزاز فقط (برمجياً).
     * 3. إشعار صامت من التطبيق -> اهتزاز فقط (برمجياً).
     * 4. بخلاف ذلك -> السماح بتشغيل الصوت.
     * 
     * يُرجع [true] إذا كان يجب تشغيل الصوت، و [false] إذا كان الإشعار يجب أن يكون صامتاً.
     */
    fun evaluateAudioVibrationState(context: Context, soundName: String, overrideSilent: Boolean): Boolean {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()
        if (cleanSoundName == "none" || cleanSoundName == "null") return false

        val isAppSilent = cleanSoundName == "silent_notif" || cleanSoundName == "ruqyah" || cleanSoundName == "silent"
        if (overrideSilent && !isAppSilent) return true

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return when (audioManager.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> false
            AudioManager.RINGER_MODE_VIBRATE -> {
                triggerVibration(context)
                false
            }
            else -> {
                if (isAppSilent) {
                    triggerVibration(context)
                    false
                } else true
            }
        }
    }

    private fun triggerVibration(context: Context) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            // نمط اهتزاز مخصص للإشعارات
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
