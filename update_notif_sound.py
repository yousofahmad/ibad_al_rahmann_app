# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\services\notification_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''    await _scheduleNative(
      950,
      'الصلاة على النبي ﷺ',
      'اللهم صلِّ وسلم على نبينا محمد',
      targetDate.hour,
      targetDate.minute,
      'saly_3ala_mo7amad',
      payload: 'salawat',
      year: targetDate.year,
      month: targetDate.month,
      day: targetDate.day,
      intervalMinutes: intervalMinutes,
      allowedDays: days.join(','),
      customSoundName: 'saly_3ala_mo7amad',
    );'''

new_code = '''    final prefs = await SharedPreferences.getInstance();
    final soundName = prefs.getString('flutter.salawat_periodic_sound') ?? 'saly_3ala_mo7amad';

    await _scheduleNative(
      950,
      'الصلاة على النبي ﷺ',
      'اللهم صلِّ وسلم على نبينا محمد',
      targetDate.hour,
      targetDate.minute,
      soundName,
      payload: 'salawat',
      year: targetDate.year,
      month: targetDate.month,
      day: targetDate.day,
      intervalMinutes: intervalMinutes,
      allowedDays: days.join(','),
      customSoundName: soundName,
    );'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")