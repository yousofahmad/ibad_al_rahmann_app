import 'dart:convert';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';

class AccountabilitySyncService {
  static final List<String> _defaultPrayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static final List<String> _defaultQuran = ['ورد التلاوة', 'ورد الحفظ', 'ورد المراجعة'];
  static final List<String> _defaultAzkar = ['أذكار الصباح', 'أذكار المساء', 'أذكار الصلاة', 'السنن'];
  static final List<String> _defaultGoodDeeds = ['الصدقة', 'صيام يوم', 'صلة الرحم', 'قيام الليل', 'الضحى'];

  static Map<String, bool> _loadOrCreateMap(String key, List<String> defaultList) {
    final prefs = CacheHelper.prefs;
    final jsonStr = prefs.getString(key);
    Map<String, bool> map = {};
    if (jsonStr != null) {
      try {
        final decoded = json.decode(jsonStr) as Map;
        map = decoded.map((k, v) => MapEntry(k.toString(), v == true));
      } catch (_) {}
    } else {
      for (var e in defaultList) {
        map[e] = false;
      }
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
            } else if (v is Map && v['status'] == 'missed') {
              prayersMap[actualKey] = false;
            }
          }
        });
      } catch (_) {}
    }

    // 3. Sync Azkar
    if (azkarMap.containsKey('أذكار الصباح')) {
      azkarMap['أذكار الصباح'] = await DailyTrackerService.isDone('morning_azkar');
    }
    if (azkarMap.containsKey('أذكار المساء')) {
      azkarMap['أذكار المساء'] = await DailyTrackerService.isDone('evening_azkar');
    }
    if (azkarMap.containsKey('أذكار الصلاة')) {
      azkarMap['أذكار الصلاة'] = await DailyTrackerService.isDone('prayer_azkar');
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
