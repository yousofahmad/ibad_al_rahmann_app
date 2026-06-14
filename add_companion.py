import sys

file_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\AlarmReceiver.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure it ends properly
content = content.rstrip()
if content.endswith('}'):
    # Remove the last brace to insert companion object inside the class
    content = content[:-1]
else:
    print("Unexpected end of file")
    sys.exit(1)

companion = """
    companion object {
        fun buildAndShowNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
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

        fun forceUpdateAllWidgets(context: Context) {
            val providers = arrayOf(PrayerWidgetProvider::class.java, PrayerWidgetLargeProvider::class.java, PrayerWidgetWideProvider::class.java)
            for (provider in providers) {
                val intent = Intent(context, provider).apply { action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE }
                val ids = android.appwidget.AppWidgetManager.getInstance(context).getAppWidgetIds(android.content.ComponentName(context, provider))
                if (ids.isNotEmpty()) {
                    intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    context.sendBroadcast(intent)
                }
            }
        }
    }
}
"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content + companion)
print('Done')
