# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\services\backup_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add PrayerService reschedule
old_prefs = '''        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }'''
new_prefs = '''        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }
      
      // Reschedule alarms with restored preferences
      try {
        PrayerService().scheduleNotificationsDebounced();
      } catch (_) {}'''
content = content.replace(old_prefs, new_prefs)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")