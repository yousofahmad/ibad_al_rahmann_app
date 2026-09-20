import re

with open('lib/features/quran_reciters/ui/quran_readers_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';\n", "")
content = content.replace('const QuranReadersScreen({super.key});', 'const QuranReadersScreen({super.key, this.paperColor});\n  final Color? paperColor;')
content = content.replace('      backgroundColor: context.watch<QuranThemeCubit>().state.quranPaperColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFFFF9E5)),', '      backgroundColor: paperColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFFFF9E5)),')

with open('lib/features/quran_reciters/ui/quran_readers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
