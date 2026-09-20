with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

target1 = '''  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyHijriOffset, offset);
    // احفظ الشهر الهجري المُعدَّل (مع الـ offset) وليس raw الشهر
    await prefs.setInt(keyHijriOffsetMonth, getHijriWithOffset(offset).hMonth);
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

replacement1 = '''  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyHijriOffset, offset);
    final hDate = getHijriWithOffset(offset);
    await prefs.setInt(keyHijriOffsetMonth, hDate.hMonth);
    await prefs.setString('shared_hijri_date', "\\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\\u200F");
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

if target1 in content:
    content = content.replace(target1, replacement1)
    print("Replaced setHijriOffset")
else:
    print("setHijriOffset not found")

target2 = '''  Future<void> setLocalHijriDelta(int delta) async {
    _localHijriDelta = delta;
    final prefs = CacheHelper.prefs;
    await prefs.setInt('manual_day_adjustment', delta);
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

replacement2 = '''  Future<void> setLocalHijriDelta(int delta) async {
    _localHijriDelta = delta;
    final prefs = CacheHelper.prefs;
    await prefs.setInt('manual_day_adjustment', delta);
    final hDate = getHijriWithOffset(0);
    await prefs.setString('shared_hijri_date', "\\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\\u200F");
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }'''

if target2 in content:
    content = content.replace(target2, replacement2)
    print("Replaced setLocalHijriDelta")
else:
    print("setLocalHijriDelta not found")

with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
    f.write(content)
