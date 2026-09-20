import re

with open('lib/features/wird/ui/new_khatma_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''                value: _selectedAccountabilityLabel,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),''', '''                value: _isPerPrayer ? '+ بند جديد بنفس اسم الختمة' : (_accountabilityLabels.contains(_selectedAccountabilityLabel) ? _selectedAccountabilityLabel : _accountabilityLabels.first),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),''')

with open('lib/features/wird/ui/new_khatma_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
