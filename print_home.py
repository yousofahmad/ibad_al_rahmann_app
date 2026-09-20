import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/screens/home_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("".join(lines[350:375]))
