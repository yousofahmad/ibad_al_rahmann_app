with open("lib/core/helpers/app_formatters.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
target = r"static String toArabicDigits\(dynamic input\) \{"

replacement = r'''static String toEnglishDigits(dynamic input) {
    if (input == null) return '';
    String str = input.toString();
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(_arabicDigits[i], _englishDigits[i]);
    }
    return str;
  }

  static String toArabicDigits(dynamic input) {'''

content = re.sub(target, replacement, content)
with open("lib/core/helpers/app_formatters.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced with regex!")
