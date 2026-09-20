import re

with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'''\s*_buildGridItem\(\s*[^,]+,\s*FontAwesomeIcons\.headphones,\s*const QuranReadersScreen\(\),\s*\),''', '', content)
content = re.sub(r"import 'package:ibad_al_rahmann/features/quran_reciters/ui/quran_readers_screen\.dart';", "", content)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
