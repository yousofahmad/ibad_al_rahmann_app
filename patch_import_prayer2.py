with open("lib/screens/prayer_focus_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/features/accountability/accountability_sync_service.dart';")

with open("lib/screens/prayer_focus_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Import really added")
