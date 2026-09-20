import json

with open('assets/data/hisn.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for item in data:
    if str(item.get('ID')) in ['546', '449', '476', '534']:
        print(item.get('ID'), item.get('TITLE'))
