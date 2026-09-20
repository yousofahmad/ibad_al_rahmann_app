import re

with open('lib/screens/accountability_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''
  final List<String> _defaultQuran = [
    '??? ???????',
    '??? ?????',
    '??? ????????',
  ];'''.strip('\n'), '''
  final List<String> _defaultQuran = [
    'ورد التلاوة',
    'ورد الحفظ',
    'ورد المراجعة',
  ];'''.strip('\n'))

with open('lib/screens/accountability_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
