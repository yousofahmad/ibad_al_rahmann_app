import re

with open('lib/features/quran_reciters/data/models/reciter_model.dart', 'r', encoding='utf-8') as f:
    text = f.read()

names = re.findall(r"name:\s*'([^']+)'", text)
from collections import Counter
c = Counter(names)
for k, v in c.items():
    if v > 1:
        print(f'{k}: {v}')
