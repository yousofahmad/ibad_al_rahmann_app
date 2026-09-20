import re

with open('lib/features/quran_reciters/ui/widgets/quran_readers_list_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
        Align(
          alignment: Alignment.topCenter,
          child: TopBar(height: 242.h, label: 'القــراء'),
        ),
'''

content = re.sub(r'''\s*Positioned\.fill\(\s*child: Image\.asset\(\s*AppAssets\.imagesWhiteBackground,\s*fit: BoxFit\.cover,\s*\),\s*\),\s*Align\(\s*alignment: Alignment\.topCenter,\s*child: TopBar\(height: 242\.h, label: '[^']+'\),\s*\),''', replacement, content)

with open('lib/features/quran_reciters/ui/widgets/quran_readers_list_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
