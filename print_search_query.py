import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/screens/hisn_muslim_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'widget.searchQuery != null' in line:
        for j in range(max(0, i-5), min(len(lines), i+15)):
            print(lines[j].strip())
        break
