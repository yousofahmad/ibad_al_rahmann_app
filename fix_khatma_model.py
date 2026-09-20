import re

with open('lib/features/wird/data/khatma_model.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
  final String? dailyTime;
  final int notificationOffsetMinutes; // Legacy or fallback
  final Map<String, int>? notificationOffsetMinutesMap; // Prayer-specific offsets
  final String accountabilityLabel;
'''
content = re.sub(r'  final String\? dailyTime;\n  final int notificationOffsetMinutes;\n  final String accountabilityLabel;', replacement.strip(), content)

replacement_constructor = '''
    this.dailyTime,
    this.notificationOffsetMinutes = 30,
    this.notificationOffsetMinutesMap,
    this.startPrayerOffset = 0,
'''
content = content.replace('    this.dailyTime,\n    this.notificationOffsetMinutes = 30,\n    this.startPrayerOffset = 0,', replacement_constructor.strip())

replacement_copywith_args = '''
    String? dailyTime,
    int? notificationOffsetMinutes,
    Map<String, int>? notificationOffsetMinutesMap,
    int? startPrayerOffset,
'''
content = content.replace('    String? dailyTime,\n    int? notificationOffsetMinutes,\n    int? startPrayerOffset,', replacement_copywith_args.strip())

replacement_copywith_body = '''
      dailyTime: dailyTime ?? this.dailyTime,
      notificationOffsetMinutes: notificationOffsetMinutes ?? this.notificationOffsetMinutes,
      notificationOffsetMinutesMap: notificationOffsetMinutesMap ?? this.notificationOffsetMinutesMap,
      startPrayerOffset: startPrayerOffset ?? this.startPrayerOffset,
'''
content = content.replace('      dailyTime: dailyTime ?? this.dailyTime,\n      notificationOffsetMinutes: notificationOffsetMinutes ?? this.notificationOffsetMinutes,\n      startPrayerOffset: startPrayerOffset ?? this.startPrayerOffset,', replacement_copywith_body.strip())

replacement_tojson = '''
      'dailyTime': dailyTime,
      'notificationOffsetMinutes': notificationOffsetMinutes,
      'notificationOffsetMinutesMap': notificationOffsetMinutesMap,
      'startPrayerOffset': startPrayerOffset,
'''
content = content.replace('      \'dailyTime\': dailyTime,\n      \'notificationOffsetMinutes\': notificationOffsetMinutes,\n      \'startPrayerOffset\': startPrayerOffset,', replacement_tojson.strip())

replacement_fromjson = '''
      dailyTime: json['dailyTime'],
      notificationOffsetMinutes: json['notificationOffsetMinutes'] ?? 30,
      notificationOffsetMinutesMap: json['notificationOffsetMinutesMap'] != null 
          ? Map<String, int>.from(json['notificationOffsetMinutesMap']) 
          : null,
      startPrayerOffset: json['startPrayerOffset'] ?? 0,
'''
content = content.replace('      dailyTime: json[\'dailyTime\'],\n      notificationOffsetMinutes: json[\'notificationOffsetMinutes\'] ?? 30,\n      startPrayerOffset: json[\'startPrayerOffset\'] ?? 0,', replacement_fromjson.strip())

with open('lib/features/wird/data/khatma_model.dart', 'w', encoding='utf-8') as f:
    f.write(content)
