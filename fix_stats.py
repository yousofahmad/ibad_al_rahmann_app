import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\prayer_focus_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_logic = '''
    int totalOnTime = 0, totalLate = 0, totalMissed = 0;
    final now = DateTime.now();
    final displayMonth = DateTime(now.year, now.month + _calendarMonthOffset, 1);
    
    int expectedPrayers = 0;
    if (displayMonth.year == now.year && displayMonth.month == now.month) {
      int daysPassed = now.day - 1;
      expectedPrayers += daysPassed * 5;
      final cp = PrayerService().getPrayerTimes()?.currentPrayer() ?? Prayer.none;
      if (cp == Prayer.fajr) expectedPrayers += 1;
      else if (cp == Prayer.dhuhr) expectedPrayers += 2;
      else if (cp == Prayer.asr) expectedPrayers += 3;
      else if (cp == Prayer.maghrib) expectedPrayers += 4;
      else if (cp == Prayer.isha) expectedPrayers += 5;
    } else if (displayMonth.isBefore(now)) {
      int daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
      expectedPrayers += daysInMonth * 5;
    }

    final monthEntries = _monthLog.entries.where((e) {
      try {
        final d = DateTime.parse(e.key);
        return d.year == displayMonth.year && d.month == displayMonth.month;
      } catch (_) { return false; }
    });

    for (final entry in monthEntries) {
      for (final status in entry.value.values) {
        if (status == 'ontime') totalOnTime++;
        else if (status == 'late') totalLate++;
      }
    }
    totalMissed = expectedPrayers - (totalOnTime + totalLate);
    if (totalMissed < 0) totalMissed = 0;
'''

content = re.sub(r'int totalOnTime = 0, totalLate = 0, totalMissed = 0;.*?catch \(\_\) \{\}\n    \}', new_logic.strip(), content, flags=re.DOTALL)

# Remove the streak widget from header
streak_regex = r'const Spacer\(\),\s*if \(_unifiedStreak > 0\)\s*Container\([\s\S]*?\]\,\s*\)\,\s*\)\,'
content = re.sub(streak_regex, '', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")
