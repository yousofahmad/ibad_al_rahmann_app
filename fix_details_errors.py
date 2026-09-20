import re

with open('lib/features/wird/ui/khatma_details_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the import
if 'khatma_model.dart' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';", "import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';\nimport 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';")

# Fix IconButton
content = content.replace('''return IconButton(
                    tooltip: 'ØªØ¹Ø¯ÙŠÙ„ ÙˆÙ‚Øª Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡',
                    onPressed: () {''', '''return IconButton(
                    tooltip: 'ØªØ¹Ø¯ÙŠÙ„ ÙˆÙ‚Øª Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡',
                    icon: const Icon(FontAwesomeIcons.clock),
                    onPressed: () {''')

# Same for Arabic version of the string just in case
content = content.replace('''return IconButton(
                    tooltip: 'تعديل وقت التنبيه',
                    onPressed: () {''', '''return IconButton(
                    tooltip: 'تعديل وقت التنبيه',
                    icon: const Icon(FontAwesomeIcons.clock),
                    onPressed: () {''')

with open('lib/features/wird/ui/khatma_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
