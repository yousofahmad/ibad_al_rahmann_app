with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for j in range(500, 515):
    print(f"{j+1}: {repr(lines[j])}")
