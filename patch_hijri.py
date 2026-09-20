import re

with open("lib/services/hijri_source_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = """    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {"""

replacement = """    try {
      AppLogger.log('HijriSync', 'Fetching from $apiUrl');
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {"""

target2 = """      }
    } catch (e) {
      debugPrint("Dar Al-Ifta fetch error: $e");
    }
    return null;"""

replacement2 = """      } else {
        AppLogger.log('HijriSync', 'Error: Status code ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Exception: $e');
      debugPrint("Dar Al-Ifta fetch error: $e");
    }
    return null;"""

if target in content and target2 in content:
    content = content.replace(target, replacement)
    content = content.replace(target2, replacement2)
    # Add AppLogger import if not exists
    if "import 'package:ibad_al_rahmann/services/app_logger.dart';" not in content:
        content = content.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:ibad_al_rahmann/services/app_logger.dart';")
    with open("lib/services/hijri_source_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Patched HijriSourceService")
else:
    print("Targets not found")
