import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/wird/ui/wird_dashboard_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'Map<String, int>' in line and 'showDialog' in line:
        for j in range(i-5, i+25):
            if j >= 0 and j < len(lines):
                print(lines[j].strip())
        break
