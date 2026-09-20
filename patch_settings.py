import re

with open("lib/screens/settings_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target_remove = re.search(r'  Future<void> _showHijriDialog.*?          \);\n        },\n      \);\n    }\n', content, re.DOTALL)

if target_remove:
    content = content.replace(target_remove.group(0), "")
    print("Removed _showHijriDialog")
else:
    print("Could not find _showHijriDialog")

target_replace = re.search(r'_buildListTile\(\n\s*"التاريخ الهجري".*?onTap: _showHijriDialog,\n\s*\),', content, re.DOTALL)

if target_replace:
    replacement = """_buildListTile(
              "ضبط التاريخ الهجري",
              "تحديث ومزامنة وتعديل التاريخ يدوياً",
              FontAwesomeIcons.calendarDays,
              onTap: () => Navigator.pushNamed(context, '/hijri_confirmation'),
            ),"""
    content = content.replace(target_replace.group(0), replacement)
    print("Replaced _buildListTile for Hijri")
else:
    print("Could not find _buildListTile for Hijri")
    # let's try a broader regex
    target2 = re.search(r'_buildListTile\([^;]+onTap: _showHijriDialog,\n\s*\),', content, re.DOTALL)
    if target2:
        print("Found with target2")

with open("lib/screens/settings_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
