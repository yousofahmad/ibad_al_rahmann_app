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

if 'class TafsirExtractor' not in content:
    content += '\n' + extractor_code

# use replace instead of regex
match_str = '''  static String getVerseTafsir(int surahNumber, int verseNumber, {String? bookId}) {
    final targetId = bookId ?? getSelectedBookId();
    if (targetId == 'muyassar') {
      return _muyassarCache['\_\'] ?? '';
    }

    final cacheKey = '\_\';
    final surahMap = _cache[cacheKey];
    if (surahMap != null && surahMap.containsKey(verseNumber)) {
      var text = surahMap[verseNumber] ?? '';
      if (RegExp(r'^\\d+:\\d+\$').hasMatch(text.trim())) {
        final targetAyahNum = int.tryParse(text.trim().split(':')[1]) ?? 0;
        if (surahMap.containsKey(targetAyahNum) &&
            !RegExp(r'^\\d+:\\d+\$').hasMatch(surahMap[targetAyahNum]!.trim())) {
          text = surahMap[targetAyahNum]!;
        }
      }
      return text;
    }

    return '';
  }'''

replace_str = '''  static String getVerseTafsir(int surahNumber, int verseNumber, {String? bookId}) {
    final targetId = bookId ?? getSelectedBookId();
    if (targetId == 'muyassar') {
      return _muyassarCache['\_\'] ?? '';
    }

    final cacheKey = '\_\';
    final surahMap = _cache[cacheKey];
    if (surahMap != null && surahMap.containsKey(verseNumber)) {
      var text = surahMap[verseNumber] ?? '';
      if (RegExp(r'^\\d+:\\d+\$').hasMatch(text.trim())) {
        final targetAyahNum = int.tryParse(text.trim().split(':')[1]) ?? 0;
        if (surahMap.containsKey(targetAyahNum) &&
            !RegExp(r'^\\d+:\\d+\$').hasMatch(surahMap[targetAyahNum]!.trim())) {
          text = surahMap[targetAyahNum]!;
        }
      }
      return TafsirExtractor.extractAyah(text, verseNumber);
    }

    return '';
  }'''

# Replace
if match_str in content:
    content = content.replace(match_str, replace_str)
else:
    # Just in case there's slight formatting mismatch, we'll try a fallback regex
    # but we'll use lambda to avoid escape sequence issues
    import re
    content = re.sub(r'return text;\n    \}\n\n    return \'\';\n  \}', r'return TafsirExtractor.extractAyah(text, verseNumber);\n    }\n\n    return \'\';\n  }', content)

with open('lib/core/helpers/tafsir_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
