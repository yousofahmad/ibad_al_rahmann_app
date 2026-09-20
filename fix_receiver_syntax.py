import re

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockReceiver.kt', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('Context.MODE_PRIVATE)        val mode =', 'Context.MODE_PRIVATE)\n        val mode =')

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/ScreenUnlockReceiver.kt', 'w', encoding='utf-8') as f:
    f.write(content)
