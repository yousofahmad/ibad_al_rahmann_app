import re

with open('lib/features/wird/ui/new_khatma_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timeStr =
        '${_dailyTime.hour.toString().padLeft(2, '0')}:${_dailyTime.minute.toString().padLeft(2, '0')}';
        
    String? effectiveLabel;
    if (_effectiveDivision == 'prayer') {
      effectiveLabel = _nameController.text.trim();
    } else {
      if (_selectedAccountabilityLabel == '+ بند جديد بنفس اسم الختمة') {
        effectiveLabel = _nameController.text.trim();
      } else if (_selectedAccountabilityLabel == 'بدون ربط') {
        effectiveLabel = null;
      } else {
        effectiveLabel = _selectedAccountabilityLabel;
      }
    }
'''

content = content.replace('''    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timeStr =
        '${_dailyTime.hour.toString().padLeft(2, '0')}:${_dailyTime.minute.toString().padLeft(2, '0')}';''', replacement)

with open('lib/features/wird/ui/new_khatma_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
