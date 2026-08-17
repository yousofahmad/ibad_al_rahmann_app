import re

# 1. Update version in pubspec.yaml
with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    content = f.read()
content = re.sub(r'version: 1\.1\.3\+7', 'version: 1.1.4+8', content)
with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update version in settings_screen.dart
with open(r'lib\screens\settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
content = re.sub(r'??????? 1\.1\.3', '??????? 1.1.4', content)
with open(r'lib\screens\settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 3. Fix Prayer Focus Screen Logical Day
with open(r'lib\screens\prayer_focus_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

helper = '''  String _getLogicalDate() {
    final now = DateTime.now();
    if (now.hour < 4) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }
    return DateFormat('yyyy-MM-dd').format(now);
  }
'''
if '_getLogicalDate' not in content:
    content = content.replace('class _PrayerFocusScreenState extends State<PrayerFocusScreen> {', 'class _PrayerFocusScreenState extends State<PrayerFocusScreen> {\n' + helper)

content = content.replace("final today = DateFormat('yyyy-MM-dd').format(DateTime.now());", "final today = _getLogicalDate();")
content = content.replace("final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());", "final todayKey = _getLogicalDate();")

with open(r'lib\screens\prayer_focus_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched successfully!")
