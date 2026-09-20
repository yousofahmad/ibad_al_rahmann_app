import re

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('paperColor: currentColor', 'paperColor: null')

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/quran_reciters/ui/widgets/landscape_quran_readers_list_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = "import 'package:ibad_al_rahmann/core/theme/app_assets.dart';\n" + content

with open('lib/features/quran_reciters/ui/widgets/landscape_quran_readers_list_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
