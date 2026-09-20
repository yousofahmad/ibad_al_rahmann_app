import 'test_extractor.dart';

class TafsirExtractor2 {
  static String extractAyah(String text, int verseNumber) {
    if (text.isEmpty) return text;
    
    // Check if the text contains verseNumber in brackets like {1}, (1), [1], ﴿1﴾, <1>
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

void main() {
  String sample = "بسم الله ﴿1﴾ الحمد لله (2) الرحمن الرحيم {3}";
  print(TafsirExtractor2.extractAyah(sample, 2)); // Should be "الحمد لله (2)"
  print(TafsirExtractor2.extractAyah(sample, 3)); // Should be "الرحمن الرحيم {3}"
  print(TafsirExtractor2.extractAyah(sample, 1)); // Should be "بسم الله ﴿1﴾"
}
