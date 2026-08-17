import os
import re

files = [
    r'android\app\src\main\kotlin\app\ibad_al_rahmann\NotificationQueueManager.kt',
    r'android\app\src\main\kotlin\app\ibad_al_rahmann\PrayerNotificationService.kt',
    r'android\app\src\main\kotlin\app\ibad_al_rahmann\BackgroundMethodChannelPlugin.kt',
    r'android\app\src\main\kotlin\app\ibad_al_rahmann\NotificationActionReceiver.kt'
]

for file_path in files:
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Simple replacement for NotificationQueueManager
        content = content.replace('androidx.core.content.ContextCompat.startForegroundService(context, syncIntent)', 'try { androidx.core.content.ContextCompat.startForegroundService(context, syncIntent) } catch (e: Exception) { e.printStackTrace() }')
        content = content.replace('context.startForegroundService(serviceIntent)', 'try { context.startForegroundService(serviceIntent) } catch (e: Exception) { e.printStackTrace() }')
        content = content.replace('androidx.core.content.ContextCompat.startForegroundService(context, stopIntent)', 'try { androidx.core.content.ContextCompat.startForegroundService(context, stopIntent) } catch (e: Exception) { e.printStackTrace() }')

        # NotificationActionReceiver
        content = content.replace('androidx.core.content.ContextCompat.startForegroundService(context, serviceIntent)', 'try { androidx.core.content.ContextCompat.startForegroundService(context, serviceIntent) } catch (e: Exception) { e.printStackTrace() }')

        # BackgroundMethodChannelPlugin
        content = content.replace('context.startForegroundService(intent)', 'try { context.startForegroundService(intent) } catch (e: Exception) { e.printStackTrace() }')
        content = content.replace('androidx.core.content.ContextCompat.startForegroundService(context, intent)', 'try { androidx.core.content.ContextCompat.startForegroundService(context, intent) } catch (e: Exception) { e.printStackTrace() }')

        # PrayerNotificationService startForegroundSafe
        start_safe = '''    private fun startForegroundSafe(id: Int, notification: android.app.Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(id, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(id, notification)
        }
    }'''
        
        start_safe_fixed = '''    private fun startForegroundSafe(id: Int, notification: android.app.Notification) {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(id, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(id, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }'''
        
        content = content.replace(start_safe, start_safe_fixed)

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Fixed ' + file_path)
    except Exception as e:
        print('Error in ' + file_path + ': ' + str(e))
