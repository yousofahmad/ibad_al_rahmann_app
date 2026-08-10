# -*- coding: utf-8 -*-
import re

# 1. AndroidManifest.xml: Add USE_FULL_SCREEN_INTENT
manifest_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\AndroidManifest.xml'
with open(manifest_path, 'r', encoding='utf-8') as f:
    manifest = f.read()

if 'android.permission.USE_FULL_SCREEN_INTENT' not in manifest:
    manifest = manifest.replace('<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>', 
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(manifest)

# 2. PrayerNotificationService.kt: Fix LargeIcon
service_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\PrayerNotificationService.kt'
with open(service_path, 'r', encoding='utf-8') as f:
    service = f.read()

old_logic = '''            payload == "jumuah" || payload == "kahf" || alarmId in 705..719 -> "ic_jumuah"
            isAdhan(alarmId) -> "logo" // Default logo for Adhan
            else -> "logo"'''
new_logic = '''            payload == "jumuah" || payload == "kahf" || alarmId in 705..719 -> "ic_jumuah"
            payload.contains("prayer") || isAdhan(alarmId) -> {
                when (alarmId) {
                    100, 3000, 5000, 110 -> "ic_fajr"
                    101, 3001, 5001 -> {
                        val calendar = java.util.Calendar.getInstance()
                        if (calendar.get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY) "ic_jumuah_prayer" else "ic_dhuhr"
                    }
                    102, 3002, 5002 -> "ic_asr"
                    103, 3003, 5003 -> "ic_maghrib"
                    104, 3004, 5004 -> "ic_isha"
                    else -> "logo"
                }
            }
            else -> "logo"'''
service = service.replace(old_logic, new_logic)

with open(service_path, 'w', encoding='utf-8') as f:
    f.write(service)

print("Updated Manifest and PrayerNotificationService")