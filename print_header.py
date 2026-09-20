import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran/ui/widgets/components/header_widget.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[25:50]:
    print(line.rstrip())
