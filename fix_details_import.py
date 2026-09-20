import re

with open('lib/features/wird/ui/khatma_details_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the import
if 'khatma_model.dart' not in content:
    content = "import 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';\n" + content

with open('lib/features/wird/ui/khatma_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
