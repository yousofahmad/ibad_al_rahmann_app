with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target = r"if \(val is Map\) return \(val\['status'\] as String\?\) \?\? 'on_time';\s*if \(val is bool\) return val \? 'on_time' : null;\s*if \(val is String\) return val\.isNotEmpty \? val : null;\s*return 'on_time';"

replacement = r'''if (val is Map) {
                final st = (val['status'] as String?) ?? 'ontime';
                if (st == 'present' || st == 'on_time') return 'ontime';
                return st;
              }
              if (val is bool) return val ? 'ontime' : null;
              if (val is String) {
                if (val == 'present' || val == 'on_time') return 'ontime';
                return val.isNotEmpty ? val : null;
              }
              return 'ontime';'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/screens/prayer_focus_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced successfully!")
else:
    print("Target not found!")
