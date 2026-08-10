# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\NotificationQueueManager.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Comment out nm.cancel(alarmId)
content = re.sub(r'(nm\.cancel\(\d+ \+ index\))', r'// \1', content)
content = re.sub(r'(nm\.cancel\(alarmId\))', r'// \1', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")