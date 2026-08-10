# -*- coding: utf-8 -*-
path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\PrayerNotificationService.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('fun getLargeIconForPayload')
if start == -1:
    start = content.find('getLargeIconForPayload')
print(content[start-200:start+1000])