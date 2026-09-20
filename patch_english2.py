with open("lib/core/helpers/app_formatters.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''  /// Converts any string or number containing English digits (0-9) to Eastern Arabic digits (Ù -Ù©).
  static String toArabicDigits(dynamic input) {'''

replacement = '''  static String toEnglishDigits(dynamic input) {
    if (input == null) return '';
    String str = input.toString();
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(_arabicDigits[i], _englishDigits[i]);
    }
    return str;
  }

  /// Converts any string or number containing English digits (0-9) to Eastern Arabic digits (Ù -Ù©).
  static String toArabicDigits(dynamic input) {'''

if target in content:
    content = content.replace(target, replacement)
    with open("lib/core/helpers/app_formatters.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added toEnglishDigits")
else:
    print("Target not found")
