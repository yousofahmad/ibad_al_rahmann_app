import re

with open('lib/features/wird/bloc/khatma_cubit.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
  Future<void> updatePrayerOffsets(String khatmaId, Map<String, int> newOffsets) async {
    if (state is! KhatmaLoaded) return;
    final khatmas = List<KhatmaModel>.from((state as KhatmaLoaded).khatmas);
    final kIndex = khatmas.indexWhere((k) => k.id == khatmaId);
    if (kIndex == -1) return;

    final updatedKhatma = khatmas[kIndex].copyWith(
      notificationOffsetMinutesMap: newOffsets,
      enableNotifications: true,
      notificationType: 'prayer',
    );
    khatmas[kIndex] = updatedKhatma;

    final box = Hive.box('appDataBox');
    final jsonStr = jsonEncode(updatedKhatma.toJson());
    await box.put('khatma_', jsonStr);

    emit(KhatmaLoaded(khatmas));
    await NotificationService.scheduleAll(khatmas);
  }
'''

content = content.replace('  Future<void> updateDailyTime(String khatmaId, String newTime) async {', replacement.strip() + '\n\n  Future<void> updateDailyTime(String khatmaId, String newTime) async {')

with open('lib/features/wird/bloc/khatma_cubit.dart', 'w', encoding='utf-8') as f:
    f.write(content)
