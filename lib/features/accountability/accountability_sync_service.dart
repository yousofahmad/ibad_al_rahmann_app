import 'dart:convert';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';

class AccountabilitySyncService {
  static final List<String> _defaultPrayers = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
    'الضحى',
    'القيام',
    'السنن',
  ];
  static final List<String> _defaultQuran = [
    'ورد التلاوة',
    'حفظ جديد',
    'مراجعة',
    'سماع قرآن',
  ];
  static final List<String> _defaultAzkar = [
    'أذكار الصباح',
    'أذكار المساء',
    'أذكار النوم',
    'أذكار الصلاة',
  ];
  static final List<String> _defaultGoodDeeds = [
    'بر الوالدين',
    'صدقة',
    'صلة رحم',
    'إطعام مسكين',
    'زيارة مريض',
    'طلب علم',
  ];

  static Map<String, bool> _loadOrCreateMap(String key, List<String> defaultList) {
    final prefs = CacheHelper.prefs;
    final custom = prefs.getStringList('custom_items_$key') ?? [];
    final deleted = (prefs.getStringList('deleted_items_$key') ?? []).toSet();
    final items = [
      ...defaultList.where((e) => !deleted.contains(e)),
      ...custom.where((e) => !deleted.contains(e)),
    ];

    Map<String, bool> map = {};
    for (var item in items) {
      map[item] = false;
    }
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        final decoded = json.decode(jsonStr) as Map;
        decoded.forEach((k, v) {
          if (map.containsKey(k.toString())) {
            map[k.toString()] = v == true;
          }
        });
      } catch (_) {}
    }
    return map;
  }

  static double _calcPercent(Map<String, bool> map) {
    int checked = map.values.where((e) => e).length;
    return map.isEmpty ? 0 : (checked / map.length) * 100;
  }

  static Future<void> syncAndSaveTodayStats() async {
    final prefs = CacheHelper.prefs;
    final todayKey = await IslamicDay.todayKey();

    // 1. Load temp maps
    final prayersMap = _loadOrCreateMap('temp_prayers', _defaultPrayers);
    final quranMap = _loadOrCreateMap('temp_quran', _defaultQuran);
    final azkarMap = _loadOrCreateMap('temp_azkar', _defaultAzkar);
    final deedsMap = _loadOrCreateMap('temp_deeds', _defaultGoodDeeds);

    // 2. Sync Prayer Focus
    final focusLogRaw = prefs.getString('prayer_focus_log_$todayKey');
    if (focusLogRaw != null) {
      try {
        final Map<String, dynamic> focusMap = json.decode(focusLogRaw);
        focusMap.forEach((k, v) {
          String actualKey = k;
          if (k == 'الجمعة' && prayersMap.containsKey('الظهر')) {
            actualKey = 'الظهر';
          }
          if (prayersMap.containsKey(actualKey)) {
            if (v is Map && v['status'] != null && v['status'] != 'missed') {
              prayersMap[actualKey] = true;
            } else if (v == true) {
              prayersMap[actualKey] = true;
            }
          }
        });
      } catch (_) {}
    }

    // 3. Sync Azkar
    if (azkarMap.containsKey('أذكار الصباح')) {
      final done = await DailyTrackerService.isDone('morning_azkar');
      if (done) azkarMap['أذكار الصباح'] = true;
    }
    if (azkarMap.containsKey('أذكار المساء')) {
      final done = await DailyTrackerService.isDone('evening_azkar');
      if (done) azkarMap['أذكار المساء'] = true;
    }
    if (azkarMap.containsKey('أذكار الصلاة')) {
      final done = await DailyTrackerService.isDone('prayer_azkar');
      if (done) azkarMap['أذكار الصلاة'] = true;
    }

    // 4. Save temp maps back
    await prefs.setString('temp_prayers', json.encode(prayersMap));
    await prefs.setString('temp_quran', json.encode(quranMap));
    await prefs.setString('temp_azkar', json.encode(azkarMap));
    await prefs.setString('temp_deeds', json.encode(deedsMap));

    // 5. Calculate and save stats
    double prayerScore = _calcPercent(prayersMap);
    double quranScore = _calcPercent(quranMap);
    double azkarScore = _calcPercent(azkarMap);
    double deedsScore = _calcPercent(deedsMap);
    double totalScore = (prayerScore + quranScore + azkarScore + deedsScore) / 4;

    Map<String, dynamic> dailyData = {
      'date': todayKey,
      'prayer': prayerScore,
      'quran': quranScore,
      'azkar': azkarScore,
      'deeds': deedsScore,
      'total': totalScore,
    };
    await prefs.setString('stats_$todayKey', json.encode(dailyData));
  }
}
