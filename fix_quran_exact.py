import re

with open('lib/screens/accountability_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(\"'??? ???????'\", \"'ورد التلاوة'\").replace(\"'??? ?????'\", \"'ورد الحفظ'\").replace(\"'??? ????????'\", \"'ورد المراجعة'\")

with open('lib/screens/accountability_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
