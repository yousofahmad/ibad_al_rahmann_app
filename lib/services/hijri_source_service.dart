import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';

class EgyptDarAlIftaProvider {
  static const String apiUrl = 'https://di107.dar-alifta.org/api/HijriDate?langID=2';

  Future<int?> fetchDay() async {
    try {
      AppLogger.log('HijriSync', 'Fetching from Dar Al-Ifta: $apiUrl');
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        // e.g. "9 Rabi' Al-Akhir 1448" or "10 Rabi' Al-Thani 1448"
        final body = json.decode(response.body);
        final dateStr = body.toString().trim();
        
        if (dateStr.isNotEmpty) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            return int.tryParse(parts[0]);
          }
        }
      } else {
        AppLogger.log('HijriSync', 'Dar Al-Ifta Error: Status code ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Dar Al-Ifta Exception: $e');
      debugPrint("Dar Al-Ifta fetch error: $e");
    }
    return null;
  }
}

class EgyptSurveyAuthorityProvider {
  static const String pageUrl = 'https://www.esa.gov.eg/praytimes.aspx';

  Future<int?> fetchDay() async {
    try {
      AppLogger.log('HijriSync', 'Fetching from Survey Authority: $pageUrl');
      final response = await http.get(
        Uri.parse(pageUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;
        // The table row for Cairo: <td>القاهرة</td> ... <td>9 ربيـــــــع الثانى 1448</td>
        final regex = RegExp(
          r'القاهرة.*?<\/td>\s*<td[^>]*>[^<]*<\/td>\s*<td[^>]*>([^<]+)<\/td>',
          dotAll: true,
        );
        final match = regex.firstMatch(html);
        if (match != null) {
          final hijriRaw = match.group(1)?.replaceAll('ـ', '').trim() ?? '';
          AppLogger.log('HijriSync', 'Survey Authority Raw Hijri: $hijriRaw');
          final dayMatch = RegExp(r'(\d+)').firstMatch(hijriRaw);
          if (dayMatch != null) {
            return int.tryParse(dayMatch.group(1)!);
          }
        } else {
          AppLogger.log('HijriSync', 'Survey Authority: Cairo row regex did not match.');
        }
      } else {
        AppLogger.log('HijriSync', 'Survey Authority Error: Status code ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Survey Authority Exception: $e');
      debugPrint("Survey Authority fetch error: $e");
    }
    return null;
  }
}

class HijriSourceService {
  static const String _localOffsetKey = 'local_hijri_offset';
  static const String _lastFetchDateKey = 'local_hijri_last_fetch';
  static const String _confirmedDateKey = 'local_hijri_confirmed_date';

  static final EgyptDarAlIftaProvider _darAlIftaProvider = EgyptDarAlIftaProvider();
  static final EgyptSurveyAuthorityProvider _surveyAuthorityProvider = EgyptSurveyAuthorityProvider();

  /// Attempts to fetch and save the offset once per day.
  static Future<void> syncOffsetIfNeeded() async {
    if (!PrayerService.isEgyptianSystem) {
      AppLogger.log('HijriSync', 'syncOffsetIfNeeded: Skipped because active system is Umm Al-Qura.');
      return;
    }

    // 1. Critical layer check on the eve of day 29 after Maghrib
    await checkEveOf29CriticalSync();

    final prefs = CacheHelper.prefs;
    final todayStr = DateTime.now().toString().substring(0, 10);
    
    final lastFetch = prefs.getString(_lastFetchDateKey);
    if (lastFetch == todayStr) return;

    // 2. Middle layer silent dual sync
    await _performDualSync(todayStr);
  }

  /// Critical Layer: Single live check on the eve of day 29 after Maghrib.
  static Future<bool> checkEveOf29CriticalSync() async {
    if (!PrayerService.isEgyptianSystem) {
      AppLogger.log('HijriSync', 'checkEveOf29CriticalSync: Skipped (active system is Umm Al-Qura).');
      return true;
    }

    final now = DateTime.now();
    final times = PrayerService().getPrayerTimesForDate(now);
    final maghrib = times?.maghrib ?? DateTime(now.year, now.month, now.day, 18, 0);

    final isAfterMaghrib = now.isAfter(maghrib);
    final effectiveDate = isAfterMaghrib ? now.add(const Duration(days: 1)) : now;
    
    // Base astronomical Hijri day for the active Islamic day
    final baseHijri = HijriCalendar.fromDate(effectiveDate);

    AppLogger.log(
      'HijriSync',
      'Critical Layer Check -> now: ${now.toIso8601String()}, maghrib: ${maghrib.toIso8601String()}, isAfterMaghrib: $isAfterMaghrib, baseHijriDay: ${baseHijri.hDay}',
    );

    // Only trigger on the eve of day 29 after Maghrib
    if (baseHijri.hDay != 29 || !isAfterMaghrib) {
      AppLogger.log('HijriSync', 'Critical Layer: Not eve of day 29 after Maghrib (Day: ${baseHijri.hDay}, afterMaghrib: $isAfterMaghrib). Skipping critical check.');
      return true;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final prefs = CacheHelper.prefs;
    final isAlreadyConfirmed = prefs.getString(_confirmedDateKey) == todayStr;

    if (isAlreadyConfirmed) {
      AppLogger.log('HijriSync', 'Critical Layer: Eve of 29 already confirmed for $todayStr.');
      return true;
    }

    AppLogger.log('HijriSync', 'Critical Layer Triggered: Eve of day 29 after Maghrib! Calling Dar Al-Ifta API for crescent confirmation...');
    
    final darAlIftaDay = await _darAlIftaProvider.fetchDay();
    if (darAlIftaDay != null) {
      final diff = darAlIftaDay - baseHijri.hDay;
      if (diff >= -2 && diff <= 2) {
        await prefs.setInt(_localOffsetKey, diff);
        await prefs.setString(_lastFetchDateKey, todayStr);
        await prefs.setString(_confirmedDateKey, todayStr);
        await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
        AppLogger.log('HijriSync', 'Critical Layer Success: Dar Al-Ifta confirmed day: $darAlIftaDay (offset: $diff). Date updated.');
        return true;
      }
    }

    // Call failed or returned null (no internet / server down)
    AppLogger.log('HijriSync', 'Critical Layer Failed: Unable to verify crescent with Dar Al-Ifta on eve of day 29. Sending notification to user.');
    await NotificationService.showImmediateNotification(
      title: 'تأكيد التاريخ الهجري (ليلة الرؤية)',
      body: 'تعذر الاتصال بدار الإفتاء للتأكد من بداية الشهر الجديد. اضغط هنا للتحديث.',
      payload: 'hijri_confirmation',
    );
    return false;
  }

  /// Force fetch the offset right now.
  static Future<bool> forceSync() async {
    final todayStr = DateTime.now().toString().substring(0, 10);
    AppLogger.log('HijriSync', 'Manual forceSync requested for $todayStr.');
    final success = await _performDualSync(todayStr);
    if (success) {
      AppLogger.log('HijriSync', 'Manual forceSync succeeded.');
    } else {
      AppLogger.log('HijriSync', 'Manual forceSync failed to fetch from official sources.');
    }
    return success;
  }

  static Future<bool> _performDualSync(String todayStr) async {
    final results = await Future.wait([
      _darAlIftaProvider.fetchDay(),
      _surveyAuthorityProvider.fetchDay(),
    ]);

    final darAlIftaDay = results[0];
    final esaDay = results[1];
    final today = DateTime.now();
    final localHijri = HijriCalendar.fromDate(today);

    AppLogger.log(
      'HijriSync',
      'Dual Sync Results -> Dar Al-Ifta Day: $darAlIftaDay, Survey Authority Day: $esaDay, Local Base Day: ${localHijri.hDay}',
    );

    // Comparison logic
    if (darAlIftaDay != null && esaDay != null) {
      if (darAlIftaDay == esaDay) {
        AppLogger.log(
          'HijriSync',
          'Verification Success: Both Dar Al-Ifta ($darAlIftaDay) and Survey Authority ($esaDay) agree on date for $todayStr.',
        );
      } else {
        AppLogger.log(
          'HijriSync',
          'WARNING: Discrepancy between Dar Al-Ifta ($darAlIftaDay) and Survey Authority ($esaDay) on $todayStr. Prioritizing Dar Al-Ifta as primary authority.',
        );
      }
    }

    // Primary authority is Dar Al-Ifta, fallback to Survey Authority if Dar Al-Ifta fails
    final chosenDay = darAlIftaDay ?? esaDay;
    if (chosenDay != null) {
      final diff = chosenDay - localHijri.hDay;
      if (diff >= -2 && diff <= 2) {
        final prefs = CacheHelper.prefs;
        await prefs.setInt(_localOffsetKey, diff);
        await prefs.setString(_lastFetchDateKey, todayStr);
        await prefs.setString(_confirmedDateKey, todayStr);
        await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
        return true;
      }
    }
    return false;
  }

  static Future<void> setManualOffset(int offset) async {
    final prefs = CacheHelper.prefs;
    final todayStr = DateTime.now().toString().substring(0, 10);
    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setString(_confirmedDateKey, todayStr);
    // don't set _lastFetchDateKey so that background task can still attempt API fetch if possible
  }

  static int? getLocalOffset() {
    return CacheHelper.prefs.getInt(_localOffsetKey);
  }

  static bool hasConfirmedToday() {
    final todayStr = DateTime.now().toString().substring(0, 10);
    return CacheHelper.prefs.getString(_confirmedDateKey) == todayStr;
  }
}
