import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran_audio/logic/quran_player/quran_player_cubit.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'Future<String> getSurahUrl' in line:
        for j in range(i, i+15):
            if j < len(lines):
                print(lines[j].strip())
        break
