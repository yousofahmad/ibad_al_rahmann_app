import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran/ui/widgets/components/header_widget.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'height:' in line:
        print(f"Line {i+1}: {line.strip()}")
