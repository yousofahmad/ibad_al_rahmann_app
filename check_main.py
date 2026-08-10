import re
path = r'd:\flutter\ibad_al_rahmann\lib\main.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

print(content[:1500])