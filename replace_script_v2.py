import sys

file_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\AlarmReceiver.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_sig = 'private fun showNotification('
start_idx = content.find(start_sig)
if start_idx == -1:
    print('Start not found')
    sys.exit(1)

part1 = content[:start_idx]

new_func = """private fun showNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
        NativeLogger.log(context, "Notification Fired! Title: $title | Body: $content | AlarmId: $notifId | Payload: $targetPage")
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()

        // Absolute return for none/null — ensures no ghost notifications
        if (cleanSoundName == "none" || cleanSoundName == "null") return

        val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "PLAY_SOUND"
            putExtra("notification_id", notifId)
            putExtra("title", title)
            putExtra("body", content)
            putExtra("target_page", targetPage)
            putExtra("sound_name", soundName)
            if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
            if (audioPath != null) putExtra("audio_path", audioPath)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svcIntent)
        } else {
            context.startService(svcIntent)
        }
    }
}
"""

new_content = part1 + new_func
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Done')
