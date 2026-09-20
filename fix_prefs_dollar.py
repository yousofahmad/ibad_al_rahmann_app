import re

with open('lib/features/wird/bloc/khatma_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("await prefs.setString('khatma_', jsonStr);", "await prefs.setString('khatma_$khatmaId', jsonStr);")

with open('lib/features/wird/bloc/khatma_cubit.dart', 'w', encoding='utf-8') as f:
    f.write(content)
