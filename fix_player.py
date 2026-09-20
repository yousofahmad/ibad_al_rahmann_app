import re

with open('lib/features/quran/ui/widgets/menus/verse_details_bottom_sheet.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add dispose method to _VerseDetailsBottomSheetState
dispose_code = '''
  @override
  void dispose() {
    // Stop the audio player when the bottom sheet is closed
    if (mounted) {
      context.read<VersePlayerCubit>().closeVerse();
    }
    super.dispose();
  }
'''

content = content.replace('''  @override
  Widget build(BuildContext context) {''', dispose_code + '''
  @override
  Widget build(BuildContext context) {''')

with open('lib/features/quran/ui/widgets/menus/verse_details_bottom_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/quran/bloc/verse_player/verse_player_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('bool autoPlayNext = false;', 'bool autoPlayNext = true;')

with open('lib/features/quran/bloc/verse_player/verse_player_cubit.dart', 'w', encoding='utf-8') as f:
    f.write(content)

