import 'package:adhan/adhan.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:ibad_al_rahmann/core/helpers/islamic_day.dart';
import 'package:ibad_al_rahmann/core/helpers/prayer_day_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

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

  static Map<String, bool> _loadOrCreateMap(
    String key,
    List<String> defaultList,
  ) {
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

  static bool _isPrayerPast(String prayerName) {
    final times = PrayerService().getPrayerTimes();
    if (times == null) return true;
    final now = DateTime.now();
    switch (prayerName) {
      case 'Ø§Ù„Ù Ø¬Ø±':
        return now.isAfter(times.fajr);
      case 'Ø§Ù„Ø¸Ù‡Ø±':
      case 'Ø§Ù„Ø¬Ù…Ø¹Ø©':
        return now.isAfter(times.dhuhr);
      case 'Ø§Ù„Ø¹ØµØ±':
        return now.isAfter(times.asr);
      case 'Ø§Ù„Ù…ØºØ±Ø¨':
        return now.isAfter(times.maghrib);
      case 'Ø§Ù„Ø¹Ø´Ø§Ø¡':
        return now.isAfter(times.isha);
      default:
        return true;
    }
  }

  static Future<void> syncAndSaveTodayStats() async {
    final prefs = CacheHelper.prefs;
    final todayKey = await IslamicDay.todayKey();
    final activeKey = PrayerDayHelper.getActivePrayerCycleDate();

    // 1. Load temp maps
    final prayersMap = _loadOrCreateMap('temp_prayers', _defaultPrayers);
    final quranMap = _loadOrCreateMap('temp_quran', _defaultQuran);
    final azkarMap = _loadOrCreateMap('temp_azkar', _defaultAzkar);
    final deedsMap = _loadOrCreateMap('temp_deeds', _defaultGoodDeeds);

    // 2. Sync Prayer Focus
    final focusLogRaw =
        prefs.getString('prayer_focus_log_$activeKey') ??
        prefs.getString('prayer_focus_log_$todayKey');
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
    final pastPrayers = prayersMap.keys.where((k) => _isPrayerPast(k)).toList();
    int totalPrayers = pastPrayers.length;
    int checkedPrayers = pastPrayers.where((k) => prayersMap[k] == true).length;
    double prayerScore =
        totalPrayers == 0 ? 0.0 : (checkedPrayers / totalPrayers) * 100.0;

    int totalQuran = quranMap.length;
    int checkedQuran = quranMap.values.where((e) => e).length;
    double quranScore =
        totalQuran == 0 ? 0.0 : (checkedQuran / totalQuran) * 100.0;

    int totalAzkar = azkarMap.length;
    int checkedAzkar = azkarMap.values.where((e) => e).length;
    double azkarScore =
        totalAzkar == 0 ? 0.0 : (checkedAzkar / totalAzkar) * 100.0;

    int totalDeeds = deedsMap.length;
    int checkedDeeds = deedsMap.values.where((e) => e).length;
    double deedsScore =
        totalDeeds == 0 ? 0.0 : (checkedDeeds / totalDeeds) * 100.0;

    int totalAll = totalPrayers + totalQuran + totalAzkar + totalDeeds;
    int totalChecked =
        checkedPrayers + checkedQuran + checkedAzkar + checkedDeeds;
    double totalScore =
        totalAll == 0 ? 0.0 : (totalChecked / totalAll) * 100.0;

    Map<String, dynamic> dailyData = {
      'date': activeKey,
      'prayer': prayerScore,
      'quran': quranScore,
      'azkar': azkarScore,
      'deeds': deedsScore,
      'total': totalScore,
    };
    await prefs.setString('stats_$activeKey', json.encode(dailyData));
    if (activeKey != todayKey) {
      final todayData = Map<String, dynamic>.from(dailyData)
        ..['date'] = todayKey;
      await prefs.setString('stats_$todayKey', json.encode(todayData));
    }
  }
}
