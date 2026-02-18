import 'package:flutter/services.dart';

class FontsHelper {
  static Future<void> loadFont(String family, String path) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(path));
    await loader.load();
  }

  static String getFontFamily(int pageNumber) {
    return 'QCF_P${pageNumber.toString().padLeft(3, "0")}';
  }

  static Future<void> loadFontFromFamily(String family) async {
    // Try to infer the page number from the family name, e.g., 'QCF_P001'
    final regExp = RegExp(r'QCF_P(\d{3})');
    final match = regExp.firstMatch(family);
    if (match != null) {
      final pageNumber = int.tryParse(match.group(1)!);
      if (pageNumber != null) {
        final fontPath = getFontPath(pageNumber);
        await loadFont(family, fontPath);
      }
    }
    // If the family name does not match the expected pattern, do nothing.
  }

  static String getFontPath(int pageNumber) {
    // return 'assets/fonts/pages/QCF2${pageNumber.toString().padLeft(3, "0")}.ttf';
    return 'assets/fonts/qcf4/QCF4${pageNumber.toString().padLeft(3, "0")}_X-Regular.ttf';
  }
}
