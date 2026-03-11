import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class FontsHelper {
  static final Set<String> _loadedFonts = {};

  static bool isFontLoaded(String family) => _loadedFonts.contains(family);

  static Future<void> loadFont(String family, String path) async {
    if (_loadedFonts.contains(family)) return;
    try {
      final loader = FontLoader(family)..addFont(rootBundle.load(path));
      await loader.load();
      _loadedFonts.add(family);
    } catch (e) {
      debugPrint('Error loading font $family: $e');
    }
  }

  static String getFontFamily(int pageNumber) {
    return 'QCF_V1_P$pageNumber';
  }

  static Future<void> loadFontFromFamily(String family) async {
    if (_loadedFonts.contains(family)) return;
    // Try to infer the page number from the family name, e.g., 'QCF_V1_P1'
    final regExp = RegExp(r'QCF_V1_P(\d+)');
    final match = regExp.firstMatch(family);
    if (match != null) {
      final pageNumberStr = match.group(1)!;
      final pageNumber = int.tryParse(pageNumberStr);
      if (pageNumber != null) {
        final fontPath = getFontPath(pageNumber);
        await loadFont(family, fontPath);
      }
    }
  }

  static String getFontPath(int pageNumber) {
    return 'assets/fonts/QPC V1 Font.ttf/p$pageNumber.ttf';
  }
}
