with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target = r'''    final h = HijriCalendar.fromDate(effectiveDate);
    final hijriStr = "\\u200F\$\{h.hDay\} \$\{h.longMonthName\} \$\{h.hYear\}\\u200F";
    CacheHelper.prefs.setString\('shared_hijri_date', hijriStr\);'''

replacement = r'''    final h = HijriCalendar.fromDate(effectiveDate);
    final hijriStr = "\u200F${h.hDay} ${h.longMonthName} ${h.hYear}\u200F";
    final gDateStr = "${baseDate.year}-${baseDate.month.toString().padLeft(2, '0')}-${baseDate.day.toString().padLeft(2, '0')}";
    CacheHelper.prefs.setString('shared_hijri_date', hijriStr);
    CacheHelper.prefs.setString('shared_hijri_date_$gDateStr', hijriStr);'''

if target in content:
    print("Found with simple string!")

# Since simple string doesn't work well due to escapes, let's replace exact text
target2 = '''    final h = HijriCalendar.fromDate(effectiveDate);
    final hijriStr = "\\u200F${h.hDay} ${h.longMonthName} ${h.hYear}\\u200F";
    CacheHelper.prefs.setString('shared_hijri_date', hijriStr);'''

replacement2 = '''    final h = HijriCalendar.fromDate(effectiveDate);
    final hijriStr = "\\u200F${h.hDay} ${h.longMonthName} ${h.hYear}\\u200F";
    final gDateStr = "${baseDate.year}-${baseDate.month.toString().padLeft(2, '0')}-${baseDate.day.toString().padLeft(2, '0')}";
    CacheHelper.prefs.setString('shared_hijri_date', hijriStr);
    CacheHelper.prefs.setString('shared_hijri_date_$gDateStr', hijriStr);'''

if target2 in content:
    content = content.replace(target2, replacement2)
    with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced successfully!")
else:
    print("Target2 not found")
