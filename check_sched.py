# -*- coding: utf-8 -*-
path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\NativePrayerScheduler.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('fun scheduleToday')
print(content[start:start+1500])