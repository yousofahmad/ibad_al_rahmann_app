# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\ScreenUnlockReceiver.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_vol = 'val volumeLevel = flutterPrefs.getDouble("flutter.salah_unlock_volume", 1.0).toFloat()'
new_vol = '''            val volumeLevel = try {
                val bits = flutterPrefs.getLong("flutter.salah_unlock_volume", java.lang.Double.doubleToRawLongBits(1.0))
                java.lang.Double.longBitsToDouble(bits).toFloat()
            } catch (e: Exception) {
                try {
                    flutterPrefs.getFloat("flutter.salah_unlock_volume", 1.0f)
                } catch (e2: Exception) {
                    1.0f
                }
            }'''

content = content.replace(old_vol, new_vol)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")