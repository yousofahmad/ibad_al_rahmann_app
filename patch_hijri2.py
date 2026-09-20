with open("lib/services/prayer_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

# Remove globalHijriOffset
content = re.sub(
    r"int get hijriOffset => RemoteConfigService\.globalHijriOffset \+ _hijriOffset \+ _localHijriDelta;",
    r"int get hijriOffset => _hijriOffset + _localHijriDelta;",
    content
)

# And in getHijriWithOffset, remove remoteOffset
target_func = r'''static HijriCalendar getHijriWithOffset\(int remoteOffset, \[DateTime\? date\]\) \{
    final baseDate = date \?\? DateTime\.now\(\);
    
    // الأولوية 1: local_hijri_offset \(المحسوب من API دار الإفتاء\)
    final localOffset = CacheHelper\.prefs\.getInt\('local_hijri_offset'\);
    final manualAdjustment = CacheHelper\.prefs\.getInt\('manual_day_adjustment'\) \?\? 0;

    // لو فيه تأكيد محلي، نتجاهل الفايربيز تماماً في مصر
    final offsetDays = \(localOffset != null\)
        \? localOffset \+ manualAdjustment
        : remoteOffset \+ manualAdjustment;'''

replacement_func = r'''static HijriCalendar getHijriWithOffset(int _, [DateTime? date]) {
    final baseDate = date ?? DateTime.now();
    
    // الأولوية: local_hijri_offset (المحسوب من API دار الإفتاء)
    final localOffset = CacheHelper.prefs.getInt('local_hijri_offset') ?? 0;
    final manualAdjustment = CacheHelper.prefs.getInt('manual_day_adjustment') ?? 0;

    final offsetDays = localOffset + manualAdjustment;'''

if re.search(target_func, content):
    content = re.sub(target_func, replacement_func, content)
    with open("lib/services/prayer_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed getHijriWithOffset and hijriOffset in prayer_service.dart")
else:
    print("Target not found!")
