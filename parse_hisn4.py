import json
with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

texts = {}
for category, items in data.items():
    if isinstance(items, dict):
        text_list = items.get('text', [])
        for i, t in enumerate(text_list):
            if t in texts:
                print(f"DUPLICATE FOUND: {t[:30]}...")
            texts[t] = category
