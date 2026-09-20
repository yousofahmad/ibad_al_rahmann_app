import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("lib/features/quran_audio/ui/widgets/surah_widget.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[30:70]:
    print(line.strip())
