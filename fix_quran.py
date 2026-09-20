import re

with open('lib/screens/accountability_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
  final List<String> _defaultQuran = [
    'ورد التلاوة',
    'ورد الحفظ',
    'ورد المراجعة',
  ];
'''
content = re.sub(r'  final List<String> _defaultQuran = \[\s*\'\?\?\? \?\?\?\?\?\?\?\',\s*\'\?\?\? \?\?\?\?\?\',\s*\'\?\?\? \?\?\?\?\?\?\?\?\',\s*\];', replacement.strip(), content)

with open('lib/screens/accountability_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
