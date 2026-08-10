import re
path = r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('persistent_notification_enabled')
if start == -1:
    print("KEY NOT FOUND in settings_screen.dart")
else:
    print(content[start-200:start+300])