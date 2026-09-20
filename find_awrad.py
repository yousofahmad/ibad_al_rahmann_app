with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'الأوراد' in line:
        for j in range(max(0, i-5), min(len(lines), i+20)):
            print(f"{j}: {lines[j].strip()}")
