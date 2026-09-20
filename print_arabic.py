import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("android/app/src/main/kotlin/app/ibad_al_rahmann/NativePrayerManager.kt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'fun getArabicDate' in line:
        for j in range(i, i+30):
            print(lines[j].strip())
        break
