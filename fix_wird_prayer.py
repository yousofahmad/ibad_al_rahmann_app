import re

with open('lib/features/wird/services/wird_completion_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _currentPrayerArabicName with _prayerNameFromIndex
replacement = '''
  static String _prayerNameFromIndex(int index) {
    switch (index % 5) {
      case 0: return 'الفجر';
      case 1: return 'الظهر';
      case 2: return 'العصر';
      case 3: return 'المغرب';
      case 4: return 'العشاء';
      default: return '';
    }
  }
'''

content = re.sub(r'  static String _currentPrayerArabicName.*?\n  \}', replacement.strip(), content, flags=re.DOTALL)

# Update the call site in complete()
content = content.replace('final pName = _currentPrayerArabicName();', 'final pName = _prayerNameFromIndex(wirdIndex);')

with open('lib/features/wird/services/wird_completion_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
