import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran_reciters/services/quran_audio_download_service.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if i >= 25 and i <= 35:
        print(f"{i+1}: {line.rstrip()}")
