import re

with open('lib/screens/accountability_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''          child: ExpansionTile(
            collapsedIconColor: const Color(0xFFD0A871),''', '''          child: ExpansionTile(
            initiallyExpanded: true,
            collapsedIconColor: const Color(0xFFD0A871),''')

with open('lib/screens/accountability_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
