# -*- coding: utf-8 -*-
path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\PrayerNotificationService.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Change channel ID to new one and use IMPORTANCE_LOW to prevent heads-up popups
# Must use new ID because Android caches channel importance and ignores changes
content = content.replace('"persistent_prayer_v11"', '"persistent_prayer_v13"')

# Change IMPORTANCE_MAX to IMPORTANCE_LOW for the persistent channel
# We only want to change it in the persistent notification channel creation, not the prayer sound channel
# The persistent channel creation lines look like:
# val ch = NotificationChannel(channelId, "شريط وقت الصلاة", NotificationManager.IMPORTANCE_MAX)
import re

# Replace IMPORTANCE_MAX only in context of persistent channel (not prayer_sound_channel)
# We'll do a targeted replacement
old1 = 'val ch = NotificationChannel(channelId, "\u0634\u0631\u064a\u0637 \u0648\u0642\u062a \u0627\u0644\u0635\u0644\u0627\u0629", NotificationManager.IMPORTANCE_MAX)'
new1 = 'val ch = NotificationChannel(channelId, "\u0634\u0631\u064a\u0637 \u0648\u0642\u062a \u0627\u0644\u0635\u0644\u0627\u0629", NotificationManager.IMPORTANCE_LOW)'
content = content.replace(old1, new1)

# Also replace the buildPersistentNotification channel creation
old2 = 'val channel = NotificationChannel(channelId, "\u0634\u0631\u064a\u0637 \u0648\u0642\u062a \u0627\u0644\u0635\u0644\u0627\u0629", NotificationManager.IMPORTANCE_MAX)'
new2 = 'val channel = NotificationChannel(channelId, "\u0634\u0631\u064a\u0637 \u0648\u0642\u062a \u0627\u0644\u0635\u0644\u0627\u0629", NotificationManager.IMPORTANCE_LOW)'
content = content.replace(old2, new2)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Verify changes
with open(path, 'r', encoding='utf-8') as f:
    result = f.read()
    
count_v13 = result.count('persistent_prayer_v13')
count_low = result.count('IMPORTANCE_LOW')
count_max_persistent = result.count('IMPORTANCE_MAX')
print(f"v13 occurrences: {count_v13}")
print(f"IMPORTANCE_LOW occurrences: {count_low}")
print(f"IMPORTANCE_MAX remaining: {count_max_persistent}")