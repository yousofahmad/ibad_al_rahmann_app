import re

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockReceiver.kt', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the condition to check if mode is not 'none'
replacement = '''        val mode = prefs.getString("flutter.salah_unlock_mode", "none")
            ?: prefs.getString("salah_unlock_mode", "none")
            ?: "none"

        if (mode == "none") return'''

content = re.sub(r'''\s*val isEnabled = prefs\.getBoolean\("flutter\.salah_unlock_enabled", false\)\s*\|\| prefs\.getBoolean\("salah_unlock_enabled", false\)\s*if \(!isEnabled\) return''', replacement, content)

content = re.sub(r'''\s*val mode = prefs\.getString\("flutter\.salah_unlock_mode", "saly_3ala_mo7amad"\)\s*\?: prefs\.getString\("salah_unlock_mode", "saly_3ala_mo7amad"\)\s*\?: "saly_3ala_mo7amad"''', '', content)

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockReceiver.kt', 'w', encoding='utf-8') as f:
    f.write(content)
