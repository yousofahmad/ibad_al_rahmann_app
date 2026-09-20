import re

with open('lib/screens/prayer_times_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';", "import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")

content = content.replace('_formatDuration(_timeToNext).toArabicNums,', 'AppFormatters.toArabicDigits(_formatDuration(_timeToNext)),')
content = content.replace('PrayerService().formatTime(p.time).toArabicNums,', 'AppFormatters.toArabicDigits(PrayerService().formatTime(p.time)),')
content = content.replace('final hijriStr = hijriStrRaw.toArabicNums;', 'final hijriStr = AppFormatters.toArabicDigits(hijriStrRaw);')
content = content.replace('final gregStr = gregStrRaw.toArabicNums;', 'final gregStr = AppFormatters.toArabicDigits(gregStrRaw);')

with open('lib/screens/prayer_times_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
