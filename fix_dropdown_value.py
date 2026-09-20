import re

with open('lib/features/wird/ui/new_khatma_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
                value: _isPerPrayer ? '+ بند جديد بنفس اسم الختمة' : (_accountabilityLabels.contains(_selectedAccountabilityLabel) ? _selectedAccountabilityLabel : _accountabilityLabels.first),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: AppConsts.cairo,
                  fontSize: 14,
                ),
                underline: const SizedBox(),
                items: (_isPerPrayer ? ['+ بند جديد بنفس اسم الختمة'] : _accountabilityLabels).map((label) {
'''

content = re.sub(r'                value:\s*_selectedAccountabilityLabel,\s*icon:\s*const Icon\(Icons\.arrow_drop_down,\s*color:\s*Colors\.white\),\s*dropdownColor:\s*isDark\s*\?\s*Colors\.grey\[900\]\s*:\s*Colors\.white,\s*style:\s*TextStyle\(\s*color:\s*isDark\s*\?\s*Colors\.white\s*:\s*Colors\.black87,\s*fontFamily:\s*AppConsts\.cairo,\s*fontSize:\s*14,\s*\),\s*underline:\s*const SizedBox\(\),\s*items:\s*\(_isPerPrayer \? \[\'\+ بند جديد بنفس اسم الختمة\'\] : _accountabilityLabels\)\.map\(\(label\)\s*\{', replacement.strip('\n'), content)

with open('lib/features/wird/ui/new_khatma_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
