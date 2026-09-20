with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for j in range(500, 520):
    print(f"{j+1}: {lines[j].strip()}")
