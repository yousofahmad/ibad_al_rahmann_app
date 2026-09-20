import re

with open('lib/features/wird/bloc/khatma_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
    final box = Hive.box('appDataBox');
    final jsonStr = jsonEncode(updatedKhatma.toJson());
    await box.put('khatma_', jsonStr);
    
    final prefs = CacheHelper.prefs;
    await prefs.setString('khatma_', jsonStr);

    await NotificationService.cancelKhatmaNotifications(khatmaId);
    await NotificationService.rescheduleAllKhatmaNotifications();

    emit(KhatmaLoaded(khatmas));
  }
'''

content = content.replace('''
    final box = Hive.box('appDataBox');
    final jsonStr = jsonEncode(updatedKhatma.toJson());
    await box.put('khatma_', jsonStr);

    emit(KhatmaLoaded(khatmas));
    await NotificationService.scheduleAll(khatmas);
  }''', replacement)

with open('lib/features/wird/bloc/khatma_cubit.dart', 'w', encoding='utf-8') as f:
    f.write(content)
