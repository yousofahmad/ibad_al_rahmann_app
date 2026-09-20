with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()
import re

target = r'''      AppLogger\.log\("PrayerFocus", "writing prayer_focus_log_\$dateKey: \$\{json\.encode\(logMap\)\} AND temp_prayers: \$\{json\.encode\(tempMap\)\}"\);
      await prefs\.setString\('temp_prayers', json\.encode\(tempMap\)\);
    \}

    // إعادة حساب الاستريك الفعلي من السجل
    final newStreak = await _recalculateTrueStreak\(prefs\);'''

replacement = r'''      AppLogger.log("PrayerFocus", "writing prayer_focus_log_$dateKey: ${json.encode(logMap)} AND temp_prayers: ${json.encode(tempMap)}");
      await prefs.setString('temp_prayers', json.encode(tempMap));
    }
    
    await AccountabilitySyncService.syncAndSaveTodayStats();

    // إعادة حساب الاستريك الفعلي من السجل
    final newStreak = await _recalculateTrueStreak(prefs);'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/screens/prayer_focus_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced in _savePrayerStatusForDate")
else:
    print("Target not found!")
