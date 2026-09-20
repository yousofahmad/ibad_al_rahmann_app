with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()
import re
target = r'''      AppLogger\.log\("Accountability", "writing \$logKey: \$\{json\.encode\(focusMap\)\} AND temp_prayers: \$\{json\.encode\(map\)\}"\);
      await prefs\.setString\(logKey, json\.encode\(focusMap\)\);
    \}'''

replacement = r'''      AppLogger.log("Accountability", "writing $logKey: ${json.encode(focusMap)} AND temp_prayers: ${json.encode(map)}");
      await prefs.setString(logKey, json.encode(focusMap));
    }
    await AccountabilitySyncService.syncAndSaveTodayStats();'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added syncAndSaveTodayStats to _updateStateAndSave")
else:
    print("Target not found")
