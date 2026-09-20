with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''    final h = HijriCalendar.fromDate(effectiveDate);
    AppLogger.log("PrayerService", "getHijriWithOffset() -> baseDate: ${baseDate.toIso8601String()}, localOffset: $localOffset, manual: $manualAdjustment, remote: $remoteOffset, effective: ${effectiveDate.toIso8601String()}, Hijri: ${h.hDay} ${h.longMonthName} ${h.hYear}");
    return h;'''

replacement = '''    final h = HijriCalendar.fromDate(effectiveDate);
    final hijriStr = "\\u200F${h.hDay} ${h.longMonthName} ${h.hYear}\\u200F";
    CacheHelper.prefs.setString('shared_hijri_date', hijriStr);
    AppLogger.log("PrayerService", "getHijriWithOffset() -> baseDate: ${baseDate.toIso8601String()}, localOffset: $localOffset, manual: $manualAdjustment, remote: $remoteOffset, effective: ${effectiveDate.toIso8601String()}, Hijri: $hijriStr");
    return h;'''

if target in content:
    content = content.replace(target, replacement)
    with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added shared_hijri_date to getHijriWithOffset")
else:
    print("getHijriWithOffset not found")
