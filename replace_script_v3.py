import sys

file_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\AlarmReceiver.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_sig = 'private fun showNotification('
start_idx = content.find(start_sig)
if start_idx == -1:
    print('Start not found')
    sys.exit(1)

# Find the end of the method by tracking braces
brace_count = 0
in_method = False
end_idx = -1

# Find the first brace after start_idx
first_brace = content.find('{', start_idx)
if first_brace == -1:
    print('First brace not found')
    sys.exit(1)

for i in range(first_brace, len(content)):
    if content[i] == '{':
        brace_count += 1
    elif content[i] == '}':
        brace_count -= 1
        if brace_count == 0:
            end_idx = i + 1
            break

if end_idx == -1:
    print('End of method not found')
    sys.exit(1)

part1 = content[:start_idx]
part2 = content[end_idx:]

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
    }"""

new_content = part1 + new_func + part2

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Done')
