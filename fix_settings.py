# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the text under Audio Channels dropdown
content = content.replace('اختر القناة التي سيعمل عليها الأذان لتجنب تداخله مع وضع الصامت.', 'اختر القناة التي سيعمل عليها الأذان. (ملاحظة: اختيار قناة الإشعارات سيجعل الأذان يعمل خارج السماعات أيضاً).')

# Remove the redundant list tile
tile_regex = r'_buildListTile\(\s*\'صوت الأذان خارج السماعات\',\s*\'يتحكم في ذلك نظام قناة الصوت تلقائياً — اضبط قنوات الصوت من: إعدادات الهاتف → التطبيقات → عباد الرحمن\',\s*Icons\.speaker_phone_rounded,\s*\),'
content = re.sub(tile_regex, '', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated settings successfully")