import re

with open('lib/services/notification_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'  static Future<void> rescheduleToday\(\) async \{\s*try \{\s*await _platform\.invokeMethod\(''rescheduleToday''\);\s*\} catch \(_\) \{\}\s*\}')

replacement = '''  static bool _isScheduling = false;
  static int _lastScheduleTime = 0;

  static Future<void> rescheduleToday() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isScheduling || (now - _lastScheduleTime < 800)) {
      return;
    }
    
    _isScheduling = true;
    _lastScheduleTime = now;
    try {
      await _platform.invokeMethod('rescheduleToday');
    } catch (_) {
    } finally {
      _isScheduling = false;
    }
  }'''

content = pattern.sub(replacement, content)

with open('lib/services/notification_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
