with open("stage13_full_clean.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if '13.2' in line or '13.3' in line or '13.4' in line or '13.5' in line:
        for j in range(i, min(i+10, len(lines))):
            if '13.' in lines[j] and j != i: break
            print(lines[j].strip())
