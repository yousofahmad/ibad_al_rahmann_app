import re

with open('lib/screens/share_setup_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'height:\s*1\.6,', 'height: 1.95,', content)

with open('lib/screens/share_setup_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
