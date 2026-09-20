import re

with open('lib/features/quran_reciters/ui/widgets/quran_readers_list_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:ibad_al_rahmann/core/theme/app_assets.dart';", "")

with open('lib/features/quran_reciters/ui/widgets/quran_readers_list_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/quran_reciters/ui/widgets/landscape_quran_readers_list_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:ibad_al_rahmann/core/theme/app_assets.dart';", "")

with open('lib/features/quran_reciters/ui/widgets/landscape_quran_readers_list_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
