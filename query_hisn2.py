import json

with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for category, items in data.items():
    for item in items:
        if str(item.get('ID')) in ['546', '449', '476', '534']:
            print(item.get('ID'), category)
