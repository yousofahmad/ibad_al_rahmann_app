import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/wird/bloc/khatma_cubit.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'Future<void> updatePrayerOffsets' in line:
        for j in range(i, i+30):
            print(lines[j].strip())
        break
