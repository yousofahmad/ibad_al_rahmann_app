import re

with open('lib/screens/prayer_times_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Import
if 'int_extensions.dart' not in content:
    content = content.replace("import 'package:flutter_screenutil/flutter_screenutil.dart';", "import 'package:flutter_screenutil/flutter_screenutil.dart';\nimport 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';")

content = content.replace('_formatDuration(_timeToNext),', '_formatDuration(_timeToNext).toArabicNums,')
content = content.replace('PrayerService().formatTime(p.time),', 'PrayerService().formatTime(p.time).toArabicNums,')
content = content.replace('hijriStr =', 'hijriStrRaw =')
content = content.replace('final gregStr =', 'final hijriStr = hijriStrRaw.toArabicNums;\n    final gregStrRaw =')
content = content.replace('DateFormat(\'d MMMM yyyy\', \'ar\').format(_selectedDate);', 'DateFormat(\'d MMMM yyyy\', \'ar\').format(_selectedDate);\n    final gregStr = gregStrRaw.toArabicNums;')

with open('lib/screens/prayer_times_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
