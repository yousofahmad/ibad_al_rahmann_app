# -*- coding: utf-8 -*-
path = r'd:\flutter\ibad_al_rahmann\lib\screens\more_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('class _SalawatReminderDialogState extends State<SalawatReminderDialog>')
print(content[start:start+1500])