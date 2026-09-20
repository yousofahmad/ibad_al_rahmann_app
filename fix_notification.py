import re

with open('lib/services/notification_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''          for (final entry in prayers.entries) {
            final name = entry.key;
            final time = entry.value;
            int offset = khatma.notificationOffsetMinutesMap != null && khatma.notificationOffsetMinutesMap!.containsKey(name)
                ? khatma.notificationOffsetMinutesMap![name]!
                : khatma.notificationOffsetMinutes;
            final t = time.add(Duration(minutes: offset));'''

content = content.replace('''          for (final entry in prayers.entries) {
            final name = entry.key;
            final time = entry.value;
            final t = time.add(Duration(minutes: khatma.notificationOffsetMinutes));''', replacement)

with open('lib/services/notification_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
