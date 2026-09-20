import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/screens/nawawi_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '_getSnippet' in line:
        for j in range(max(0, i-5), min(len(lines), i+20)):
            print(lines[j].strip())
        break
