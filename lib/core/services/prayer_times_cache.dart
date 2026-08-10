import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class PrayerTimesCache {
  static const String _boxName = 'prayer_times_box';

  static Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  static Future<void> putEntry(String key, Map<String, dynamic> value) async {
    final box = await _openBox();
    await box.put(key, value);
  }

  static Future<Map<String, dynamic>?> getEntry(String key) async {
    final box = await _openBox();
    final dynamic raw = box.get(key);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> remove(String key) async {
    final box = await _openBox();
    await box.delete(key);
  }

  static Future<void> clearStaleEntries() async {
    final now = DateTime.now();
    final todayKey = DateFormat('dd-MM-yyyy').format(now);

    final box = await _openBox();
    final keys = box.keys.toList();
    for (final dynamic rawKey in keys) {
      if (rawKey is! String) {
        await box.delete(rawKey);
        continue;
      }
      // Keep all entries whose key starts with today's date prefix (supports address suffix)
      final bool isTodayEntry =
          rawKey.startsWith('$todayKey|') || rawKey == todayKey;
      if (!isTodayEntry) {
        await box.delete(rawKey);
      }
    }
  }
}
