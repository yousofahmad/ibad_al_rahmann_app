import re

with open('lib/screens/prayer_focus_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
  Future<int> _recalculateTrueStreak(SharedPreferences prefs) async {
    int streak = 0;
    bool shouldContinue = true;
    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < 730; dayOffset++) {
      if (!shouldContinue) break;
      final d = now.subtract(Duration(days: dayOffset));
      final dNext = d.add(const Duration(days: 1));
      
      final logDay = _parseLog(prefs, DateFormat('yyyy-MM-dd').format(d));
      final logNext = _parseLog(prefs, DateFormat('yyyy-MM-dd').format(dNext));

      final isFriday = d.weekday == DateTime.friday;
      final prayersInReverse = [
        'العشاء',
        'المغرب',
        'العصر',
        if (isFriday) 'الجمعة' else 'الظهر',
        'الفجر',
      ];

      if (dayOffset == 0) {
        try {
          final prayersToday = await PrayerService().getExtendedPrayers(date: d);
          final prayerMap = {
            'الفجر': prayersToday.firstWhere((p) => p.id == 'fajr').time,
            if (isFriday)
              'الجمعة': prayersToday.firstWhere((p) => p.id == 'dhuhr').time
            else
              'الظهر': prayersToday.firstWhere((p) => p.id == 'dhuhr').time,
            'العصر': prayersToday.firstWhere((p) => p.id == 'asr').time,
            'المغرب': prayersToday.firstWhere((p) => p.id == 'maghrib').time,
            'العشاء': prayersToday.firstWhere((p) => p.id == 'isha').time,
          };

          for (final p in prayersInReverse) {
            final pTime = prayerMap[p];
            final isPassed = pTime != null && now.isAfter(pTime);
            final log = (p == 'المغرب' || p == 'العشاء') ? logNext : logDay;
            final isLogged = log[p] != null;

            if (isLogged) {
              streak++;
            } else if (isPassed) {
              shouldContinue = false;
              streak = 0;
              break;
            }
          }
        } catch (_) {
          bool foundLatest = false;
          for (final p in prayersInReverse) {
            final log = (p == 'المغرب' || p == 'العشاء') ? logNext : logDay;
            final isLogged = log[p] != null;
            if (isLogged) {
              foundLatest = true;
              streak++;
            } else if (foundLatest) {
              shouldContinue = false;
              break;
            }
          }
        }
      } else {
        for (final p in prayersInReverse) {
          final log = (p == 'المغرب' || p == 'العشاء') ? logNext : logDay;
          final isLogged = log[p] != null;
          if (isLogged) {
            streak++;
          } else {
            shouldContinue = false;
            break;
          }
        }
      }
    }

    await prefs.setInt('prayer_streak_unified', streak);
    return streak;
  }
'''

content = re.sub(r'  Future<int> _recalculateTrueStreak\(SharedPreferences prefs\) async \{.*?\n    return streak;\n  \}', replacement.strip(), content, flags=re.DOTALL)

with open('lib/screens/prayer_focus_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
