import re

with open('lib/core/helpers/tafsir_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

extractor_code = '''
class TafsirExtractor {
  static String extractAyah(String text, int verseNumber) {
    if (text.isEmpty) return text;
    
    final currentMarker = '{'+verseNumber.toString()+'}';
    final prevMarker = '{'+(verseNumber - 1).toString()+'}';
    
    bool hasAnyMarkers = RegExp(r'\{\d+\}').hasMatch(text);
    if (!hasAnyMarkers) return text;

    int startIndex = 0;
    int endIndex = text.length;
    
    int prevIndex = text.indexOf(prevMarker);
    int currIndex = text.indexOf(currentMarker);
    
    if (currIndex != -1) {
      if (prevIndex != -1) {
        startIndex = prevIndex + prevMarker.length;
      } else {
        final matches = RegExp(r'\{(\d+)\}').allMatches(text.substring(0, currIndex));
        if (matches.isNotEmpty) {
          startIndex = matches.last.end;
        } else {
          startIndex = 0;
        }
      }
      endIndex = currIndex + currentMarker.length;
    } else if (prevIndex != -1) {
      startIndex = prevIndex;
      final matches = RegExp(r'\{(\d+)\}').allMatches(text.substring(startIndex + prevMarker.length));
      if (matches.isNotEmpty) {
        endIndex = startIndex + prevMarker.length + matches.first.start;
      } else {
        endIndex = text.length;
      }
    }
    
    return text.substring(startIndex, endIndex).trim();
  }
}
'''

# Add the class at the end of the file
if 'class TafsirExtractor' not in content:
    content += '\n' + extractor_code

# Now modify getVerseTafsir
replacement = '''
  static String getVerseTafsir(int surahNumber, int verseNumber, {String? bookId}) {
    final targetId = bookId ?? getSelectedBookId();
    if (targetId == 'muyassar') {
      return _muyassarCache['\_\'] ?? '';
    }

    final cacheKey = '\_\';
    final surahMap = _cache[cacheKey];
    if (surahMap != null && surahMap.containsKey(verseNumber)) {
      var text = surahMap[verseNumber] ?? '';
      if (RegExp(r'^\d+:\d+$').hasMatch(text.trim())) {
        final targetAyahNum = int.tryParse(text.trim().split(':')[1]) ?? 0;
        if (surahMap.containsKey(targetAyahNum) &&
            !RegExp(r'^\d+:\d+$').hasMatch(surahMap[targetAyahNum]!.trim())) {
          text = surahMap[targetAyahNum]!;
        }
      }
      return TafsirExtractor.extractAyah(text, verseNumber);
    }

    return '';
  }
'''

content = re.sub(r'  static String getVerseTafsir.*?return \'\';\n  \}', replacement.strip(), content, flags=re.DOTALL)

with open('lib/core/helpers/tafsir_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
