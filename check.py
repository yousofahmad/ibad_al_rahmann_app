# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\services\notification_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace scheduleSalawatReminders hardcoded sound
# First, look at what's around line 649.
# We'll inject shared preferences logic if not there.