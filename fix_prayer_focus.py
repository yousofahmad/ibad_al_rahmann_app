import re

with open('lib/screens/prayer_focus_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'accountability_sync_service.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';", "import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';")

content = content.replace('''      await prefs.setString(logKey, json.encode(dayMap));
      if (mounted) setState(() {});''', '''      await prefs.setString(logKey, json.encode(dayMap));
      await AccountabilitySyncService.syncAndSaveTodayStats();
      if (mounted) setState(() {});''')

with open('lib/screens/prayer_focus_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
