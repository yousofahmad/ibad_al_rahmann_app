import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'QuranPlayerCubit' not in content:
    content = content.replace("import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';", "import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';\nimport 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';")
    content = content.replace('''        BlocProvider(create: (context) => ThemeCubit()),''', '''        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => QuranPlayerCubit()),''')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
