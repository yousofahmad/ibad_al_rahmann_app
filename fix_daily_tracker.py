import re

with open('lib/services/daily_tracker_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'accountability_sync_service.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';", "import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';")

replacement = '''        if (category == 'morning_azkar' || category == 'evening_azkar') {
          await _updateStreak(prefs, dateStr, category);
        }
      }
      await AccountabilitySyncService.syncAndSaveTodayStats();
    }'''

content = content.replace('''        if (category == 'morning_azkar' || category == 'evening_azkar') {
          await _updateStreak(prefs, dateStr, category);
        }
      }
    }''', replacement)

with open('lib/services/daily_tracker_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
