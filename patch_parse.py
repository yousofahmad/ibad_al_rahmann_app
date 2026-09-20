with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

# Look for `if (status == 'missed') return null; return status;`
# in `_parseLog`

target = r"if \(status == 'missed'\) return null;\n\s*return status;"
replacement = r"if (status == 'missed') return null;\n              if (status == 'present') return 'ontime';\n              return status;"

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/screens/prayer_focus_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced in _parseLog")
else:
    print("Not found target!")

# Also add AccountabilitySyncService call to _savePrayerStatus
target2 = r"Future<void> _savePrayerStatusForDate\(String prayer, String\? status, String dateKey\) async \{"

replacement2 = r"import 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';\n\n  Future<void> _savePrayerStatusForDate(String prayer, String? status, String dateKey) async {"

# Wait, `import` must go at the top!
