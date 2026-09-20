with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()
import re
content = re.sub(r"import 'package:ibad_al_rahmann/core/helpers/cache_helper\.dart';", "import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';", content)

with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Import added")
