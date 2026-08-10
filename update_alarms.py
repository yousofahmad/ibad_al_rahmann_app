# -*- coding: utf-8 -*-
import re

def update_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Change scheduleNotifications to scheduleNotificationsDebounced
    content = content.replace('PrayerService().scheduleNotifications();', 'PrayerService().scheduleNotificationsDebounced();')
    
    # Change min: 5, step: 5 to min: 1, step: 1 for compactMinutesPicker
    content = re.sub(r'min:\s*5,', 'min: 1,', content)
    content = re.sub(r'step:\s*5,', 'step: 1,', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

update_file(r'd:\flutter\ibad_al_rahmann\lib\screens\alarms_screen.dart')
update_file(r'd:\flutter\ibad_al_rahmann\lib\screens\prayer_alarms_screen.dart')
print("Updated successfully")