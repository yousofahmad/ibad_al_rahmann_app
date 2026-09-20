import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran_reciters/data/models/reciter_model.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'static Future<Map<int, SurahAudioItem>> getSurahs' in line:
        for j in range(i, i+60):
            if j < len(lines):
                print(lines[j].strip())
        break
