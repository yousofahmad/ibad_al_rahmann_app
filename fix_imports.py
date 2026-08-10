# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\prayer_focus_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports
imports = '''import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:adhan/adhan.dart';
'''
# Find the last import and add them
content = re.sub(r"(import 'package:shared_preferences/shared_preferences.dart';)", r"\1\n" + imports, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")