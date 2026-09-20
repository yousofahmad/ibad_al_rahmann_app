with open("lib/screens/widgets/prayer_detail_modal.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
content = content.replace("fontFamily: 'Courier', // Monospace", "fontFamily: AppConsts.expoArabic,")
content = content.replace("Text(\n                  timerStr,", "Text(\n                  AppFormatters.toArabicDigits(timerStr),")
# Wait, need to check if AppFormatters is imported in prayer_detail_modal.dart
if "import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")

with open("lib/screens/widgets/prayer_detail_modal.dart", "w", encoding="utf-8") as f:
    f.write(content)

with open("lib/screens/home_screen.dart", "r", encoding="utf-8") as f:
    home_content = f.read()
home_content = home_content.replace("fontFamily: 'Courier',", "fontFamily: AppConsts.expoArabic,")
if "import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';" not in home_content:
    home_content = home_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")
with open("lib/screens/home_screen.dart", "w", encoding="utf-8") as f:
    f.write(home_content)

with open("lib/screens/time_for_allah_screen.dart", "r", encoding="utf-8") as f:
    time_content = f.read()
time_content = time_content.replace("fontFamily: 'Courier',", "fontFamily: AppConsts.expoArabic,")
if "import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';" not in time_content:
    time_content = time_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")
with open("lib/screens/time_for_allah_screen.dart", "w", encoding="utf-8") as f:
    f.write(time_content)

print("Replaced Courier in all 3 files")
