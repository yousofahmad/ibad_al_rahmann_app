import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'notificationOffsetMinutesMap' in line:
        for j in range(i-2, i+15):
            if j >= 0 and j < len(lines):
                print(lines[j].strip())
        break
