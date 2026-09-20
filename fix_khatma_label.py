import re

with open('lib/features/wird/ui/new_khatma_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('accountabilityLabel: effectiveLabel,', "accountabilityLabel: effectiveLabel ?? '',")

with open('lib/features/wird/ui/new_khatma_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
