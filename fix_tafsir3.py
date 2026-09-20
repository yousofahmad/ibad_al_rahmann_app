import re

with open('lib/core/helpers/tafsir_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
class TafsirExtractor {
  static String extractAyah(String text, int verseNumber) {
    if (text.isEmpty) return text;
    
    final markerRegex = RegExp(r'[\{\(\[﴿<]' + verseNumber.toString() + r'[\}\)\]﴾>]');
    final prevMarkerRegex = RegExp(r'[\{\(\[﴿<]' + (verseNumber - 1).toString() + r'[\}\)\]﴾>]');
    
    final currentMatch = markerRegex.firstMatch(text);
    final prevMatch = prevMarkerRegex.firstMatch(text);
    
    bool hasAnyMarkers = RegExp(r'[\{\(\[﴿<]\d+[\}\)\]﴾>]').hasMatch(text);
    if (!hasAnyMarkers) return text;

    int startIndex = 0;
    int endIndex = text.length;
    
    if (currentMatch != null) {
      if (prevMatch != null) {
        startIndex = prevMatch.end;
      } else {
        final matches = RegExp(r'[\{\(\[﴿<](\d+)[\}\)\]﴾>]').allMatches(text.substring(0, currentMatch.start));
        if (matches.isNotEmpty) {
          startIndex = matches.last.end;
        } else {
          startIndex = 0;
        }
      }
      endIndex = currentMatch.end;
    } else if (prevMatch != null) {
      startIndex = prevMatch.end;
      final matches = RegExp(r'[\{\(\[﴿<](\d+)[\}\)\]﴾>]').allMatches(text.substring(startIndex));
      if (matches.isNotEmpty) {
        endIndex = startIndex + matches.first.start;
      } else {
        endIndex = text.length;
      }
    }
    
    return text.substring(startIndex, endIndex).trim();
  }
}
'''

content = re.sub(r'class TafsirExtractor \{.*?^\}', replacement.strip(), content, flags=re.DOTALL|re.MULTILINE)

with open('lib/core/helpers/tafsir_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
