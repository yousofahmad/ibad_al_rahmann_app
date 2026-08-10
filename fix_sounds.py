# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\prayer_alarms_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("onSoundTap: () => _openSoundPicker('pre_sound_', 'صوت تنبيه قبل الأذان'),", "onSoundTap: null,")
content = content.replace("onSoundTap: () => _openSoundPicker('iqama_sound_', 'صوت الإقامة'),", "onSoundTap: null,")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")