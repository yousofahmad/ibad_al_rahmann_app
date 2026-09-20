with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target = r'''// إعادة حساب الاستريك الفعلي من السجل
    final newStreak = await _recalculateTrueStreak\(prefs\);'''

replacement = r'''await AccountabilitySyncService.syncAndSaveTodayStats();
    
    // إعادة حساب الاستريك الفعلي من السجل
    final newStreak = await _recalculateTrueStreak(prefs);'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    # Also add import at the top
    content = content.replace("import 'package:ibad_al_rahmann/services/notification_service.dart';", "import 'package:ibad_al_rahmann/services/notification_service.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';")
    with open("lib/screens/prayer_focus_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added syncAndSaveTodayStats and import")
else:
    print("Target not found")
