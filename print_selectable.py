import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/screens/hisn_muslim_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'SelectableText' in line or 'Selectable' in line:
        print(f"Line {i+1}: {line.strip()}")
