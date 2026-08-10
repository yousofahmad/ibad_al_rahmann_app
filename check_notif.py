import re

path = r'd:\flutter\ibad_al_rahmann\lib\services\notification_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('static Future<void> scheduleSalawatReminders')
print(content[start:start+1000])