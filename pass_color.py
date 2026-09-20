import re

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('context.push(const QuranReadersScreen());', 'context.push(QuranReadersScreen(paperColor: currentColor));')

with open('lib/features/quran/ui/widgets/menus/single_tap_menu.dart', 'w', encoding='utf-8') as f:
    f.write(content)
