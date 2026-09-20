import re

with open('lib/features/quran/ui/widgets/menus/verse_details_bottom_sheet.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('context.read<VersePlayerCubit>().closeVerse();', 'context.read<VersePlayerCubit>().hide();')

with open('lib/features/quran/ui/widgets/menus/verse_details_bottom_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(content)
