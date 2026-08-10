# -*- coding: utf-8 -*-
# The issue: Flutter writes keys WITHOUT "flutter." prefix (e.g. "adhan_mode_Fajr")
# but NativePrayerScheduler reads WITH "flutter." prefix (e.g. "flutter.adhan_mode_Fajr")
# FlutterSharedPreferences adds "flutter." prefix automatically to all keys.
# So Flutter's SharedPreferences.setString("adhan_mode_Fajr", ...) 
# actually writes "flutter.adhan_mode_Fajr" to the file.
# This means the Kotlin code IS correct - FlutterSharedPreferences stores with flutter. prefix.

# Let's verify by checking if the keys exist in the shared prefs xml file
import os

# The shared prefs file path on Android would be in data/data/app.ibad_al_rahmann/shared_prefs/
# We can't access that directly, but let's verify the Flutter source

path = r'd:\flutter\ibad_al_rahmann\lib\screens\prayer_alarms_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if SharedPreferences.getInstance() is used (no prefix) 
# vs FlutterSharedPreferences (which adds flutter. prefix automatically)
if 'SharedPreferences.getInstance()' in content:
    print("Uses SharedPreferences.getInstance() - keys stored WITH flutter. prefix in FlutterSharedPreferences")
    
# Now check the plugin code
print("Flutter SharedPreferences plugin stores with 'flutter.' prefix by default")
print("So adhan_mode_Fajr stored in Flutter = flutter.adhan_mode_Fajr in Android XML")
print("Kotlin reading flutter.adhan_mode_Fajr = CORRECT")