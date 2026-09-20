with open("lib/core/helpers/app_formatters.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target = r'''  static String toArabicDigits\(String input\) \{'''

replacement = r'''  static String toEnglishDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  static String toArabicDigits(String input) {'''

if re.search(target, content):
    content = re.sub(target, replacement, content)
    with open("lib/core/helpers/app_formatters.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added toEnglishDigits")
else:
    print("Target not found")
