import 'dart:math';

class TafsirExtractor {
  static String extractAyah(String text, int verseNumber) {
    if (text.isEmpty) return text;
    
    // Check if the text contains {verseNumber} or similar markers
    final currentMarker = '{$verseNumber}';
    final prevMarker = '{${verseNumber - 1}}';
    
    // If neither marker is found, it might just be a normal single-ayah tafsir, or it lacks markers.
    // In that case, we can try to fall back to the whole text, but let's check for markers first.
    bool hasAnyMarkers = RegExp(r'\{\d+\}').hasMatch(text);
    if (!hasAnyMarkers) {
      return text;
    }

    // Split the text using regex that matches {any_number}
    // We want the chunk that ends with {verseNumber} OR starts with {verseNumber}
    // Usually, Tafsirs like Saadi format as: [Explanation of verse 1] {1} [Explanation of verse 2] {2}
    
    int startIndex = 0;
    int endIndex = text.length;
    
    int prevIndex = text.indexOf(prevMarker);
    int currIndex = text.indexOf(currentMarker);
    
    if (currIndex != -1) {
      // Format 1: Text comes BEFORE the marker. Example: "Explanation {1}"
      if (prevIndex != -1) {
        startIndex = prevIndex + prevMarker.length;
      } else {
        // Find the closest marker before current
        final matches = RegExp(r'\{(\d+)\}').allMatches(text.substring(0, currIndex));
        if (matches.isNotEmpty) {
          startIndex = matches.last.end;
        } else {
          startIndex = 0;
        }
      }
      endIndex = currIndex + currentMarker.length;
    } else if (prevIndex != -1) {
      // Format 2: Text comes AFTER the marker. Example: "{1} Explanation"
      startIndex = prevIndex;
      final matches = RegExp(r'\{(\d+)\}').allMatches(text.substring(startIndex + prevMarker.length));
      if (matches.isNotEmpty) {
        endIndex = startIndex + prevMarker.length + matches.first.start;
      } else {
        endIndex = text.length;
      }
    } else {
      // If we couldn't find exact markers but there are markers, maybe return the whole text?
      return text;
    }
    
    return text.substring(startIndex, endIndex).trim();
  }
}
