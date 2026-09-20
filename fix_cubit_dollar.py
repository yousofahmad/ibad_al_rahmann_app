import re

with open('lib/features/wird/bloc/khatma_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("await box.put('khatma_', jsonStr);", "await box.put('khatma_$khatmaId', jsonStr);")

with open('lib/features/wird/bloc/khatma_cubit.dart', 'w', encoding='utf-8') as f:
    f.write(content)
