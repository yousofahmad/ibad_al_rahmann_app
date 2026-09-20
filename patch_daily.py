with open("lib/features/wird/bloc/khatma_cubit.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''    final box = Hive.box('appDataBox');
    final jsonStr = jsonEncode(updatedKhatma.toJson());
    await box.put('khatma_$khatmaId', jsonStr);

    await NotificationService.cancelKhatmaNotifications(khatmaId);'''

replacement = '''    final box = Hive.box('appDataBox');
    final jsonStr = jsonEncode(updatedKhatma.toJson());
    await box.put('khatma_$khatmaId', jsonStr);

    final prefs = CacheHelper.prefs;
    await prefs.setString('khatma_$khatmaId', jsonStr);

    await NotificationService.cancelKhatmaNotifications(khatmaId);'''

if target in content:
    content = content.replace(target, replacement)
    with open("lib/features/wird/bloc/khatma_cubit.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added prefs.setString to updateDailyTime")
else:
    print("Target not found")
