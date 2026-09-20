import re

with open('lib/features/wird/ui/khatma_details_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the import
if 'wird_completion_service.dart' not in content:
    content = "import '../services/wird_completion_service.dart';\n" + content

with open('lib/features/wird/ui/khatma_details_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
