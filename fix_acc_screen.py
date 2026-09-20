import re

with open('lib/screens/accountability_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'accountability_sync_service.dart' not in content:
    content = content.replace("import '../services/daily_tracker_service.dart';", "import '../services/daily_tracker_service.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';")

content = content.replace('await _saveStatsSilent();', 'await AccountabilitySyncService.syncAndSaveTodayStats();')
content = content.replace('await _saveData();', 'await AccountabilitySyncService.syncAndSaveTodayStats();')

with open('lib/screens/accountability_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
