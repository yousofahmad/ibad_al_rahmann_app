import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:home_widget/home_widget.dart';

abstract class HijriSourceProvider {
  Future<int?> fetchOffset();
}

class EgyptDarAlIftaProvider extends HijriSourceProvider {
  static const String apiUrl = 'https://di107.dar-alifta.org/api/HijriDate?langID=2';

  @override
  Future<int?> fetchOffset() async {
    try {
      AppLogger.log('HijriSync', 'Fetching from $apiUrl');
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        // e.g. "3 Rabi' Al-Akhir 1448"
        final body = json.decode(response.body);
        final dateStr = body.toString().trim();
        
        if (dateStr.isNotEmpty) {
          final parts = dateStr.split(' ');
          if (parts.isNotEmpty) {
            final apiDay = int.tryParse(parts[0]);
            if (apiDay != null) {
              // Compare with local calculation without offset
              final today = DateTime.now();
              // Create local instance without any offsets
              final localHijri = HijriCalendar.fromDate(today);
              
              final diff = apiDay - localHijri.hDay;
              
              // Only accept reasonable differences (-2 to +2 days)
              if (diff >= -2 && diff <= 2) {
                return diff;
              }
            }
          }
        }
      } else {
        AppLogger.log('HijriSync', 'Error: Status code ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Exception: $e');
      debugPrint("Dar Al-Ifta fetch error: $e");
    }
    return null;
  }
}

class HijriSourceService {
  static const String _localOffsetKey = 'local_hijri_offset';
  static const String _lastFetchDateKey = 'local_hijri_last_fetch';
  static const String _confirmedDateKey = 'local_hijri_confirmed_date';

  static final HijriSourceProvider _provider = EgyptDarAlIftaProvider();

  /// Attempts to fetch and save the offset once per day.
  static Future<void> syncOffsetIfNeeded() async {
    final prefs = CacheHelper.prefs;
    final todayStr = DateTime.now().toString().substring(0, 10);
    
    final lastFetch = prefs.getString(_lastFetchDateKey);
    if (lastFetch == todayStr) return;

    final offset = await _provider.fetchOffset();
    if (offset != null) {
      await prefs.setInt(_localOffsetKey, offset);
      await prefs.setString(_lastFetchDateKey, todayStr);
      await prefs.setString(_confirmedDateKey, todayStr); // Confirmed by API
      await HomeWidget.updateWidget(name: 'PrayerWidgetProvider');
    }
  }

  /// Force fetch the offset right now.
  static Future<bool> forceSync() async {
    final offset = await _provider.fetchOffset();
    if (offset != null) {
      final prefs = CacheHelper.prefs;
      final todayStr = DateTime.now().toString().substring(0, 10);
      await prefs.setInt(_localOffsetKey, offset);
      await prefs.setString(_lastFetchDateKey, todayStr);
      await prefs.setString(_confirmedDateKey, todayStr);
      return true;
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
