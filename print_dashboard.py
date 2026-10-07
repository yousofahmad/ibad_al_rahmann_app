import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/wird/ui/wird_dashboard_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[140:190]:
    print(line.rstrip())
