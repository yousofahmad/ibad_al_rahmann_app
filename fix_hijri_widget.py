import re

with open('lib/services/hijri_source_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'home_widget.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';", "import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';\nimport 'package:home_widget/home_widget.dart';")

content = content.replace('await prefs.setString(_confirmedDateKey, todayStr); // Confirmed by API', "await prefs.setString(_confirmedDateKey, todayStr); // Confirmed by API\n      await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');")
content = content.replace('await prefs.setString(_confirmedDateKey, todayStr);\n        return true;', "await prefs.setString(_confirmedDateKey, todayStr);\n        await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');\n        return true;")

with open('lib/services/hijri_source_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
