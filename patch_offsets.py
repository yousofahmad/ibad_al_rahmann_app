with open("lib/features/wird/ui/khatma_details_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
# We need to replace int.tryParse(fajrCtrl.text) with int.tryParse(AppFormatters.toEnglishDigits(fajrCtrl.text))
content = re.sub(r'int\.tryParse\(([^)]+)Ctrl\.text\)', r'int.tryParse(AppFormatters.toEnglishDigits(\1Ctrl.text))', content)

# Check if AppFormatters is imported
if "AppFormatters" in content and "app_formatters.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")

with open("lib/features/wird/ui/khatma_details_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

with open("lib/features/wird/ui/wird_dashboard_screen.dart", "r", encoding="utf-8") as f:
    content2 = f.read()
content2 = re.sub(r'int\.tryParse\(([^)]+)Ctrl\.text\)', r'int.tryParse(AppFormatters.toEnglishDigits(\1Ctrl.text))', content2)
if "AppFormatters" in content2 and "app_formatters.dart" not in content2:
    content2 = content2.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';")

with open("lib/features/wird/ui/wird_dashboard_screen.dart", "w", encoding="utf-8") as f:
    f.write(content2)

print("Applied toEnglishDigits for parsing offsets")
