with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
with open("awrad_above.txt", "w", encoding="utf-8") as out:
    for j in range(500, 540):
        out.write(f"{j}: {lines[j]}")
