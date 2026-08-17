import re

with open(r'lib\screens\prayer_focus_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

helper = '''class _PrayerFocusScreenState extends State<PrayerFocusScreen> with WidgetsBindingObserver {
  String _getLogicalDate() {
    final now = DateTime.now();
    if (now.hour < 4) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }
    return DateFormat('yyyy-MM-dd').format(now);
  }'''
  
content = content.replace('class _PrayerFocusScreenState extends State<PrayerFocusScreen> with WidgetsBindingObserver {', helper)
content = content.replace("final today = DateFormat('yyyy-MM-dd').format(DateTime.now());", "final today = _getLogicalDate();")
content = content.replace("final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());", "final todayKey = _getLogicalDate();")

with open(r'lib\screens\prayer_focus_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
