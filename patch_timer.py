with open("lib/screens/widgets/prayer_detail_modal.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
content = re.sub(r'Text\(\s*timerStr,', r'Text(\n                AppFormatters.toArabicDigits(timerStr),', content)
if "import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")

with open("lib/screens/widgets/prayer_detail_modal.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced in prayer_detail_modal")
