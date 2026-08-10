import re
path = r'd:\flutter\ibad_al_rahmann\lib\screens\home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('void initState() {')
if start == -1:
    print("initState not found")
else:
    print(content[start:start+1000])