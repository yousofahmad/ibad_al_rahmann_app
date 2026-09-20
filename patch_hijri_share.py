with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

# We need to save shared_hijri_date in getHijriWithOffset or wherever it updates!
# But getHijriWithOffset is static and can be called multiple times.
# Let's save it inside setHijriOffset and setLocalHijriDelta!
# Actually, the user asked to save it so Native Kotlin can read it.
# Let's see `setHijriOffset` and `setLocalHijriDelta`

target = r'''  Future<void> setHijriOffset\(int offset\) async \{
    _hijriOffset = offset;
    final prefs = CacheHelper\.prefs;
    await prefs\.setInt\(keyHijriOffset, offset\);
    // احفظ الشهر الهجري المُعدَّل \(مع الـ offset\) وليس raw الشهر
    await prefs\.setInt\(keyHijriOffsetMonth, getHijriWithOffset\(offset\)\.hMonth\);
    notifyListeners\(\);
    await scheduleNotifications\(isUserAction: true\);
  \}'''

replacement = r'''  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyHijriOffset, offset);
    final hDate = getHijriWithOffset(offset);
    await prefs.setInt(keyHijriOffsetMonth, hDate.hMonth);
    await prefs.setString('shared_hijri_date', "\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\u200F");
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added shared_hijri_date to setHijriOffset")
else:
    print("Target setHijriOffset not found")

target2 = r'''  Future<void> setLocalHijriDelta\(int delta\) async \{
    _localHijriDelta = delta;
    final prefs = CacheHelper\.prefs;
    await prefs\.setInt\('manual_day_adjustment', delta\);
    notifyListeners\(\);
    await scheduleNotifications\(isUserAction: true\);
  \}'''

replacement2 = r'''  Future<void> setLocalHijriDelta(int delta) async {
    _localHijriDelta = delta;
    final prefs = CacheHelper.prefs;
    await prefs.setInt('manual_day_adjustment', delta);
    final hDate = getHijriWithOffset(0);
    await prefs.setString('shared_hijri_date', "\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\u200F");
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

if re.search(target2, content):
    content = re.sub(target2, replacement2, content)
    with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added shared_hijri_date to setLocalHijriDelta")
else:
    print("Target setLocalHijriDelta not found")
