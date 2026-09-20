import re

with open('lib/features/quran/bloc/verse_player/verse_player_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix autoPlayNext default
content = content.replace('bool autoPlayNext = false;', 'bool autoPlayNext = true;')

# Fix the word-by-word highlight logic
highlight_code_broken = '''              if (isHighlightWordByWord) {
                for (final seg in wordSegments) {
                  if (ms >= seg.startMs && ms <= seg.endMs) {
                    currentWord = seg.wordIndex;
                    break;
                  }
                }
              }
              if (currentWord != state.activeWordIndex) {'''

# Wait, in VersePlayerCubit, what is the exact code for highlight?
