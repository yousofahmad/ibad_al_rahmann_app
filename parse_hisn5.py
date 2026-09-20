import json
with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

texts = {}
duplicates = []
for category, items in data.items():
    if isinstance(items, dict):
        text_list = items.get('text', [])
        for i, t in enumerate(text_list):
            if t in texts:
                duplicates.append(t)
            texts[t] = category

with open('hisn_dupes.txt', 'w', encoding='utf-8') as out:
    for d in duplicates:
        out.write(d + '\n')
