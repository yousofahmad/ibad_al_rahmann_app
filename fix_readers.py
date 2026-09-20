import re

with open('lib/features/quran_reciters/ui/quran_readers_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'widgets/quran_readers_screen_body.dart';", "import 'widgets/quran_readers_screen_body.dart';\nimport 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';")
content = content.replace('      body: BlocProvider(', '''      backgroundColor: context.watch<QuranThemeCubit>().state.quranPaperColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFFFF9E5)),
      body: BlocProvider(''')

with open('lib/features/quran_reciters/ui/quran_readers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
