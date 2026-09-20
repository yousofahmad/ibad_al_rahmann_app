import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = "import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';\n" + content

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
