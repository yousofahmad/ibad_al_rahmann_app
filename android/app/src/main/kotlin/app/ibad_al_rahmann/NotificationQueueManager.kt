package app.ibad_al_rahmann

import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.LinkedList
import java.util.PriorityQueue

/**
 * مدير الطابور المتقدم: يمنع تداخل الأصوات ويحترم الأولويات.
 * الأذان (Priority 0) له الأولوية القصوى.
 */
object NotificationQueueManager {
    
    // تعريف الأولويات
    enum class Priority(val value: Int) {
        ADHAN(0),
        NOTIFICATION_WITH_SOUND(1),
        SILENT(2)
    }

    data class NotificationRequest(
        val intent: Intent,
        val priority: Priority,
        val timestamp: Long = System.currentTimeMillis()
    )

    // الطابور مرتب حسب الأولوية ثم الوقت
    private val queue = PriorityQueue<NotificationRequest> { a, b ->
        if (a.priority != b.priority) a.priority.value - b.priority.value
        else (a.timestamp - b.timestamp).toInt()
    }

    var isAudioPlaying = false
    private var currentActivePriority: Priority? = null

    /**
     * معالجة الإشعار القادم
     */
    fun processNotification(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra("notification_id", -1)
        val soundName = intent.getStringExtra("sound_name") ?: ""
        
        // تحديد الأولوية
        val priority = when {
            isAdhan(alarmId) -> Priority.ADHAN
            isSilent(soundName) -> Priority.SILENT
            else -> Priority.NOTIFICATION_WITH_SOUND
        }

        val request = NotificationRequest(intent, priority)

        if (priority == Priority.SILENT) {
            // الإشعارات الصامتة تظهر فوراً دون انتظار
            showVisualNotification(context, intent)
            return
        }

        synchronized(this) {
            if (isAudioPlaying) {
                if (priority == Priority.ADHAN) {
                    // Always replace the current audio with the new Adhan
                    stopCurrentAudio(context)
                    startAudioService(context, request)
                } else if (priority == Priority.NOTIFICATION_WITH_SOUND) {
                    // التكبيرات والصلاة على النبي (interval alarms): لو صوت شغّال، تجاهل الجديد
                    // عشان منسمعش صوتين متداخلين
                    // نعرض الإشعار البصري فقط
                    showVisualNotification(context, intent)
                }
                // لا نضيف للطابور لتجنب التراكم
            } else {
                startAudioService(context, request)
            }
        }
    }


    /**
     * يُستدعى عند انتهاء الصوت أو إغلاقه
     */
    fun onAudioFinished(context: Context) {
        synchronized(this) {
            isAudioPlaying = false
            currentActivePriority = null
            
            // Force update persistent notification and widgets after Adhan finishes
            val syncIntent = Intent(context, PrayerNotificationService::class.java).apply { action = "SYNC" }
            androidx.core.content.ContextCompat.startForegroundService(context, syncIntent)

            val nextRequest = queue.poll()
            if (nextRequest != null) {
                startAudioService(context, nextRequest)
            }
        }
    }

    private fun startAudioService(context: Context, request: NotificationRequest) {
        isAudioPlaying = true
        currentActivePriority = request.priority
        
        val serviceIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "PLAY_SOUND"
            putExtras(request.intent)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun stopCurrentAudio(context: Context) {
        val stopIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "STOP_SOUND"
        }
        androidx.core.content.ContextCompat.startForegroundService(context, stopIntent)
    }

    private fun showVisualNotification(context: Context, intent: Intent) {
        // تنفيذ مباشر لعرض الإشعار بدون صوت طويل
        val id = intent.getIntExtra("notification_id", (Math.random() * 1000).toInt())
        val title = intent.getStringExtra("title") ?: ""
        val body = intent.getStringExtra("body") ?: ""
        val payload = intent.getStringExtra("target_page") ?: "home"
        // Force silent sound!
        val soundName = "silent" 
        
        AlarmReceiver.buildAndShowNotification(context, id, title, body, soundName, payload, null, null)
    }

    private fun isAdhan(id: Int): Boolean = id in 100..139 || id in 400..799 || id in 9000..9199 || id == 950 || id == 99999
    
    private fun isSilent(soundName: String?): Boolean {
        if (soundName == null) return false
        val clean = soundName.replace(".mp3", "").lowercase().trim()
        return clean == "silent" || clean == "silent_notif" || clean == "none" || clean == "null" || clean == "ruqyah"
    }
}
