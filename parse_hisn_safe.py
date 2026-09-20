import json
import codecs

with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for category, items in data.items():
    if isinstance(items, dict):
        text_list = items.get('text', [])
        for i, t in enumerate(text_list):
            if '546' in t or '449' in t:
                print(f"Found 546/449 in category: {category.encode('utf-8')}, item {i}")
            if '476' in t or '534' in t:
                print(f"Found 476/534 in category: {category.encode('utf-8')}, item {i}")
