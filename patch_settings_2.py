import re

with open("lib/screens/settings_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target_dialog = re.search(r'  Future<void> _showHijriDialog\(\) async \{.*?    \}\n', content, re.DOTALL)
if target_dialog:
    # ensure it captures the whole dialog method
    # Actually, it's easier to just remove it line by line or find the exact block.
    # Let's just find `onTap: _showHijriDialog` and replace it
    pass

content = re.sub(r'_buildListTile\([\s\S]*?onTap:\s*_showHijriDialog,[\s\S]*?\),', 
"""_buildListTile(
              "ضبط التاريخ الهجري",
              "تحديث ومزامنة وتعديل التاريخ يدوياً",
              FontAwesomeIcons.calendarDays,
              onTap: () => Navigator.pushNamed(context, '/hijri_confirmation'),
            ),""", content)

with open("lib/screens/settings_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Replaced!")
