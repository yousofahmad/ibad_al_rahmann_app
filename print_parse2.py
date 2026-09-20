import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'Map<String, String?> _parseLog' in line:
        for j in range(i, i+25):
            print(lines[j].strip())
        break
