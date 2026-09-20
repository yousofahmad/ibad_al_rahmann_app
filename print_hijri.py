import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'static HijriCalendar getHijriWithOffset' in line:
        for j in range(i, i+30):
            print(lines[j].strip())
        break
