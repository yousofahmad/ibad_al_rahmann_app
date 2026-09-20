import json

with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for category, items in data.items():
    if isinstance(items, dict):
        texts = items.get('text', [])
        print(f"Category: {category}, has {len(texts)} texts")
