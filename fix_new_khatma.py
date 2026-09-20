import re

with open('lib/features/wird/ui/new_khatma_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
                items: (_isPerPrayer ? ['+ بند جديد بنفس اسم الختمة'] : _accountabilityLabels).map((label) {
                  return DropdownMenuItem<String>(
                    value: label,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
'''

content = re.sub(r'                items:\s*_accountabilityLabels\.map\(\(label\)\s*\{\s*return DropdownMenuItem<String>\(\s*value:\s*label,\s*child:\s*Text\(label,\s*overflow:\s*TextOverflow\.ellipsis\),\s*\);\s*\}\)\.toList\(\),', replacement.strip('\n'), content)

# ensure we also update _selectedAccountabilityLabel when _isPerPrayer changes!
# We can do this right inside the onChanged of _reminderType and _noneDivision, or just safely default it before saving.
# It's easier to just enforce it at save time!
save_replacement = '''
    // Determine start parameters
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timeStr =
        ':';
        
    final effectiveLabel = _isPerPrayer ? '+ بند جديد بنفس اسم الختمة' : _selectedAccountabilityLabel;
'''
content = content.replace('''
    // Determine start parameters
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timeStr =
        ':';
'''.strip('\n'), save_replacement.strip('\n'))

content = content.replace('accountabilityLabel: _selectedAccountabilityLabel,', 'accountabilityLabel: effectiveLabel,')

with open('lib/features/wird/ui/new_khatma_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
