# -*- coding: utf-8 -*-
path = r'd:\flutter\ibad_al_rahmann\lib\services\prayer_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('Future<void> scheduleNotifications')
print(content[start:start+1000])