with open("lib/screens/home_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
content = re.sub(r'Text\(\s*countdownStr,', r'Text(\n                        AppFormatters.toArabicDigits(countdownStr),', content)

with open("lib/screens/home_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

with open("lib/screens/time_for_allah_screen.dart", "r", encoding="utf-8") as f:
    t_content = f.read()
t_content = re.sub(r'Text\(\s*countdownStr,', r'Text(\n                        AppFormatters.toArabicDigits(countdownStr),', t_content)
with open("lib/screens/time_for_allah_screen.dart", "w", encoding="utf-8") as f:
    f.write(t_content)

print("Added toArabicDigits for countdownStr")
