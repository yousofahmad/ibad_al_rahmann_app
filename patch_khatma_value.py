import re

with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Let's fix the `value` of DropdownButton:
# `value: _isPerPrayer ? '+ بند جديد بنفس اسم الختمة' : _selectedAccountabilityLabel,`
content = content.replace(
    'value: _selectedAccountabilityLabel,',
    'value: _isPerPrayer ? \'+ بند جديد بنفس اسم الختمة\' : _selectedAccountabilityLabel,'
)

with open("lib/features/wird/ui/new_khatma_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
