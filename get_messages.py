import json

with open('C:/Users/youse/.gemini/antigravity/brain/e3703144-1fb4-4673-ba6d-b4911b095dba/.system_generated/logs/transcript.jsonl', 'r', encoding='utf-8') as f:
    messages = []
    for line in f:
        obj = json.loads(line)
        if obj.get('type') == 'USER_INPUT':
            messages.append(obj.get('content'))

with open('user_messages.txt', 'w', encoding='utf-8') as out:
    for m in messages:
        out.write(m + '\n---\n')
