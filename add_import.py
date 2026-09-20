import re

with open("lib/features/wird/ui/khatma_details_view.dart", "r", encoding="utf-8") as f:
    content = f.read()

if "import 'package:ibad_al_rahmann/services/app_logger.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ibad_al_rahmann/services/app_logger.dart';")
    with open("lib/features/wird/ui/khatma_details_view.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Import added")
else:
    print("Import already exists")
