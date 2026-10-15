import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

/// A fully parsed Hijri date received from an Egyptian authority.
@immutable
class HijriSourceDate {
  final int day;
  final int month;
  final int year;

  const HijriSourceDate({
    required this.day,
    required this.month,
    required this.year,
  });

  bool matches(HijriCalendar date) =>
      day == date.hDay && month == date.hMonth && year == date.hYear;

  bool sameDate(HijriSourceDate other) =>
      day == other.day && month == other.month && year == other.year;

  static HijriSourceDate? parse(String raw) {
    final normalized = _normalize(raw);
    final numbers = RegExp(r'\d+').allMatches(normalized).toList();
    if (numbers.length < 2) return null;

    final day = int.tryParse(numbers.first.group(0)!);
    final year = int.tryParse(numbers.last.group(0)!);
    if (day == null || year == null || day < 1 || day > 30) return null;

    final monthText = normalized
        .substring(numbers.first.end, numbers.last.start)
        .trim();
    final month = _monthFromName(monthText);
    if (month == null || year < 1300 || year > 1700) return null;

    return HijriSourceDate(day: day, month: month, year: year);
  }

  static String _normalize(String value) {
    var result = value
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r"['’`.-]"), '')
        .toLowerCase();
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _monthFromName(String monthText) {
    final value = _normalize(monthText);

    if (value.contains('muharram') || value.contains('محرم')) return 1;
    if (value.contains('safar') || value.contains('صفر')) return 2;
    if (value.contains('rabi') || value.contains('ربيع')) {
      if (value.contains('awwal') ||
          value.contains('awal') ||
          value.contains('اول')) {
        return 3;
      }
      if (value.contains('thani') ||
          value.contains('akhir') ||
          value.contains('ثان') ||
          value.contains('اخر')) {
        return 4;
      }
    }
    if (value.contains('jumada') || value.contains('جماد')) {
      if (value.contains('thani') ||
          value.contains('akhir') ||
          value.contains('ثان') ||
          value.contains('اخر')) {
        return 6;
      }
      if (value.contains('awwal') ||
          value.contains('awal') ||
          value.contains('اول')) {
        return 5;
      }
    }
    if (value.contains('rajab') || value.contains('رجب')) return 7;
    if (value.contains('shaban') || value.contains('شعبان')) return 8;
    if (value.contains('shawwal') || value.contains('شوال')) return 10;
    if (value.contains('ramadan') || value.contains('رمضان')) return 9;
    if (value.contains('qidah') ||
        value.contains('qadah') ||
        value.contains('قعد')) {
      return 11;
    }
    if (value.contains('hijjah') ||
        value.contains('hijja') ||
        value.contains('حج')) {
      return 12;
    }
    return null;
  }
}

class EgyptDarAlIftaProvider {
  static const String apiUrl =
      'https://di107.dar-alifta.org/api/HijriDate?langID=2';

  Future<HijriSourceDate?> fetchDate() async {
    try {
      AppLogger.log('HijriSync', 'Fetching from Dar Al-Ifta: $apiUrl');
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final date = _findDate(decoded);
        if (date != null) return date;
        AppLogger.log(
          'HijriSync',
          'Dar Al-Ifta returned an unrecognized Hijri date: ${response.body}',
        );
      } else {
        AppLogger.log(
          'HijriSync',
          'Dar Al-Ifta Error: Status code ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Dar Al-Ifta Exception: $e');
      debugPrint('Dar Al-Ifta fetch error: $e');
    }
    return null;
  }

  /// Kept for callers from older app versions and diagnostics.
  Future<int?> fetchDay() async => (await fetchDate())?.day;

  static HijriSourceDate? _findDate(dynamic value) {
    if (value is String) return HijriSourceDate.parse(value);
    if (value is List) {
      for (final item in value) {
        final date = _findDate(item);
        if (date != null) return date;
      }
    }
    if (value is Map) {
      for (final item in value.values) {
        final date = _findDate(item);
        if (date != null) return date;
      }
    }
    return null;
  }
}

class EgyptSurveyAuthorityProvider {
  static const String pageUrl = 'https://www.esa.gov.eg/praytimes.aspx';

  Future<HijriSourceDate?> fetchDate() async {
    try {
      AppLogger.log('HijriSync', 'Fetching from Survey Authority: $pageUrl');
      final response = await http
          .get(
            Uri.parse(pageUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;
        // The Cairo row contains Gregorian then Hijri dates in adjacent cells.
        final regex = RegExp(
          r'القاهرة.*?<\/td>\s*<td[^>]*>[^<]*<\/td>\s*<td[^>]*>([^<]+)<\/td>',
          dotAll: true,
        );
        final match = regex.firstMatch(html);
        if (match != null) {
          final rawDate = match.group(1)?.replaceAll('ـ', '').trim() ?? '';
          AppLogger.log('HijriSync', 'Survey Authority Raw Hijri: $rawDate');
          final date = HijriSourceDate.parse(rawDate);
          if (date != null) return date;
          AppLogger.log(
            'HijriSync',
            'Survey Authority returned an unrecognized Hijri date: $rawDate',
          );
        } else {
          AppLogger.log(
            'HijriSync',
            'Survey Authority: Cairo row regex did not match.',
          );
        }
      } else {
        AppLogger.log(
          'HijriSync',
          'Survey Authority Error: Status code ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.log('HijriSync', 'Survey Authority Exception: $e');
      debugPrint('Survey Authority fetch error: $e');
    }
    return null;
  }

  /// Kept for callers from older app versions and diagnostics.
  Future<int?> fetchDay() async => (await fetchDate())?.day;
}

class HijriSourceService {
  static const String _localOffsetKey = 'local_hijri_offset';
  static const String _lastFetchDateKey = 'local_hijri_last_fetch';
  static const String _lastAttemptAtKey = 'local_hijri_last_attempt_at';
  static const String _confirmedDateKey = 'local_hijri_confirmed_date';
  static const String _lockedMonthKey = 'local_hijri_locked_month';
  static const String _lockedYearKey = 'local_hijri_locked_year';
  static const String _temporarySourceKey = 'local_hijri_dar_alifta_temporary';
  static const String _lastNotifiedCorrectionKey =
      'local_hijri_last_notified_correction';
  static const Duration _retryInterval = Duration(minutes: 45);

  static final EgyptDarAlIftaProvider _darAlIftaProvider =
      EgyptDarAlIftaProvider();
  static final EgyptSurveyAuthorityProvider _surveyAuthorityProvider =
      EgyptSurveyAuthorityProvider();
  static bool _isSyncing = false;

  /// Synchronizes once per local day, beginning at midnight. If Dar Al-Ifta
  /// leads a stale/missing ESA page, recheck periodically until ESA catches up.
  static Future<void> syncOffsetIfNeeded({
    DateTime? now,
    bool rescheduleNotifications = true,
  }) async {
    if (!PrayerService.isEgyptianSystem) {
      AppLogger.log(
        'HijriSync',
        'syncOffsetIfNeeded: Skipped because active system is Umm Al-Qura.',
      );
      return;
    }
    if (_isSyncing) return;

    final currentTime = now ?? DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(currentTime);
    final prefs = CacheHelper.prefs;
    final temporaryDarSource = prefs.getBool(_temporarySourceKey) ?? false;
    final lastFetchDate = prefs.getString(_lastFetchDateKey);
    if (lastFetchDate == todayStr && !temporaryDarSource) return;

    final lastAttemptRaw = prefs.getString(_lastAttemptAtKey);
    if (lastAttemptRaw != null) {
      final lastAttempt = DateTime.tryParse(lastAttemptRaw);
      if (lastAttempt != null &&
          DateFormat('yyyy-MM-dd').format(lastAttempt) == todayStr &&
          currentTime.difference(lastAttempt) < _retryInterval) {
        return;
      }
    }

    _isSyncing = true;
    try {
      if (_isCriticalCrescentWindow(currentTime)) {
        final success = await _performDualSync(
          todayStr,
          currentTime,
          effectiveDate: currentTime.add(const Duration(days: 1)),
          rescheduleNotifications: rescheduleNotifications,
        );
        if (!success) {
          await _showCriticalSyncNotification(todayStr);
        }
        return;
      }

      await _performDualSync(
        todayStr,
        currentTime,
        rescheduleNotifications: rescheduleNotifications,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Critical moon-sighting check on the eve of Hijri day 29 after Maghrib.
  static Future<bool> checkEveOf29CriticalSync({
    DateTime? now,
    bool rescheduleNotifications = true,
  }) async {
    if (!PrayerService.isEgyptianSystem) {
      AppLogger.log(
        'HijriSync',
        'checkEveOf29CriticalSync: Skipped (active system is Umm Al-Qura).',
      );
      return true;
    }

    final currentTime = now ?? DateTime.now();
    if (!_isCriticalCrescentWindow(currentTime)) return true;

    final todayStr = DateFormat('yyyy-MM-dd').format(currentTime);
    if (CacheHelper.prefs.getString(_confirmedDateKey) == todayStr) return true;
    if (_isSyncing) return false;

    _isSyncing = true;
    try {
      final success = await _performDualSync(
        todayStr,
        currentTime,
        effectiveDate: currentTime.add(const Duration(days: 1)),
        rescheduleNotifications: rescheduleNotifications,
      );
      if (!success) await _showCriticalSyncNotification(todayStr);
      return success;
    } finally {
      _isSyncing = false;
    }
  }

  static bool _isCriticalCrescentWindow(DateTime now) {
    final times = PrayerService().getPrayerTimesForDate(now);
    final maghrib =
        times?.maghrib ?? DateTime(now.year, now.month, now.day, 18);
    if (!now.isAfter(maghrib)) return false;
    final activeDay = PrayerService.getHijriWithOffset(
      PrayerService().hijriOffset,
      now.add(const Duration(days: 1)),
    );
    return activeDay.hDay == 29;
  }

  static Future<void> _showCriticalSyncNotification(String todayStr) async {
    final notificationKey = 'local_hijri_critical_notified_$todayStr';
    final prefs = CacheHelper.prefs;
    if (prefs.getBool(notificationKey) == true) return;
    await prefs.setBool(notificationKey, true);
    await NotificationService.showImmediateNotification(
      title: 'تأكيد التاريخ الهجري (ليلة الرؤية)',
      body: 'تعذر الاتصال بالمصادر الرسمية للتأكد من بداية الشهر الجديد. اضغط هنا للمحاولة مجددًا.',
      payload: 'hijri_confirmation',
    );
  }

  /// Force fetch the full Hijri date from both Egyptian sources right now.
  static Future<bool> forceSync() async {
    if (!PrayerService.isEgyptianSystem || _isSyncing) return false;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    AppLogger.log('HijriSync', 'Manual forceSync requested for $todayStr.');

    _isSyncing = true;
    try {
      final success = await _performDualSync(
        todayStr,
        now,
        rescheduleNotifications: true,
      );
      if (!success) {
        AppLogger.log(
          'HijriSync',
          'Manual forceSync failed to fetch a usable date from official sources.',
        );
      }
      return success;
    } finally {
      _isSyncing = false;
    }
  }

  /// Finds the small civil-day offset that makes a calculated Hijri date equal
  /// the complete day/month/year received from an authority. This handles the
  /// important 30 -> 1 and 1 -> 30 month-boundary cases.
  static int? resolveOffsetForDate(
    HijriSourceDate authoritativeDate,
    DateTime baseDate, {
    int maxOffset = 2,
  }) {
    final civilDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    for (var offset = -maxOffset; offset <= maxOffset; offset++) {
      final candidate = HijriCalendar.fromDate(
        civilDate.add(Duration(days: offset)),
      );
      if (authoritativeDate.matches(candidate)) return offset;
    }
    return null;
  }

  static Future<bool> _performDualSync(
    String todayStr,
    DateTime now, {
    DateTime? effectiveDate,
    bool rescheduleNotifications = true,
  }) async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(_lastAttemptAtKey, now.toIso8601String());

    final results = await Future.wait([
      _darAlIftaProvider.fetchDate(),
      _surveyAuthorityProvider.fetchDate(),
    ]);
    final darAlIftaDate = results[0];
    final esaDate = results[1];
    final comparisonDate = effectiveDate ?? now;

    AppLogger.log(
      'HijriSync',
      'Dual Sync Results -> Dar Al-Ifta: ${_formatDate(darAlIftaDate)}, Survey Authority: ${_formatDate(esaDate)}, Effective date: ${comparisonDate.toIso8601String()}',
    );

    if (darAlIftaDate != null && esaDate != null) {
      if (darAlIftaDate.sameDate(esaDate)) {
        AppLogger.log(
          'HijriSync',
          'Verification Success: Dar Al-Ifta and Survey Authority agree on $todayStr.',
        );
      } else {
        AppLogger.log(
          'HijriSync',
          'Source discrepancy: Dar Al-Ifta ${_formatDate(darAlIftaDate)}; Survey Authority ${_formatDate(esaDate)}. Using Dar Al-Ifta until ESA catches up.',
        );
      }
    }

    // Dar Al-Ifta is the temporary primary on discrepancies; ESA is a fallback
    // when the API is unavailable. Once ESA matches, the temporary state clears.
    final chosenDate = darAlIftaDate ?? esaDate;
    if (chosenDate == null) return false;

    final offset = resolveOffsetForDate(chosenDate, comparisonDate);
    if (offset == null) {
      AppLogger.log(
        'HijriSync',
        'Rejected authoritative Hijri date ${_formatDate(chosenDate)}: no safe offset within +/-2 days of the local calculation.',
      );
      return false;
    }

    HijriCalendar.setLocal('ar');
    final previousOffset = prefs.getInt(_localOffsetKey);
    final previousHijri = PrayerService.getHijriWithOffset(
      PrayerService().hijriOffset,
      comparisonDate,
    );
    final updatedHijri = HijriCalendar.fromDate(
      DateTime(
        comparisonDate.year,
        comparisonDate.month,
        comparisonDate.day,
      ).add(Duration(days: offset)),
    );
    final dateChanged =
        previousHijri.hDay != updatedHijri.hDay ||
        previousHijri.hMonth != updatedHijri.hMonth ||
        previousHijri.hYear != updatedHijri.hYear;
    final temporaryDarSource =
        darAlIftaDate != null &&
        (esaDate == null || !darAlIftaDate.sameDate(esaDate));

    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setInt(_lockedMonthKey, updatedHijri.hMonth);
    await prefs.setInt(_lockedYearKey, updatedHijri.hYear);
    await prefs.setString(_lastFetchDateKey, todayStr);
    await prefs.setString(_confirmedDateKey, todayStr);
    await prefs.setString(
      'local_hijri_confirmed_source_$todayStr',
      darAlIftaDate == null ? 'survey_authority' : 'dar_alifta_api',
    );
    await prefs.setBool(_temporarySourceKey, temporaryDarSource);

    await PrayerService.cacheHijriDatesForNative(offset);
    await _refreshHijriWidgets();
    PrayerService().refreshUI();

    if (rescheduleNotifications && (dateChanged || previousOffset != offset)) {
      await PrayerService().scheduleNotifications(isUserAction: false);
    }

    if (dateChanged) {
      await _showDateCorrectionNotification(
        updatedHijri,
        todayStr,
        temporaryDarSource: temporaryDarSource,
      );
    }

    AppLogger.log(
      'HijriSync',
      'Hijri date updated to ${_formatDate(chosenDate)} (offset: $offset, temporary Dar Al-Ifta: $temporaryDarSource).',
    );
    return true;
  }

  static String _formatDate(HijriSourceDate? date) =>
      date == null ? 'unavailable' : '${date.day}/${date.month}/${date.year}';

  static Future<void> _refreshHijriWidgets() async {
    for (final name in const [
      'PrayerWidgetProvider',
      'PrayerWidgetLargeProvider',
      'PrayerWidgetWideProvider',
    ]) {
      try {
        await HomeWidget.updateWidget(name: name);
      } catch (e) {
        AppLogger.log('HijriSync', 'Widget update failed for $name: $e');
      }
    }
  }

  static Future<void> _showDateCorrectionNotification(
    HijriCalendar date,
    String todayStr, {
    required bool temporaryDarSource,
  }) async {
    final correctionKey = '$todayStr:${date.hDay}-${date.hMonth}-${date.hYear}';
    final prefs = CacheHelper.prefs;
    if (prefs.getString(_lastNotifiedCorrectionKey) == correctionKey) return;

    HijriCalendar.setLocal('ar');
    final dateText = '${date.hDay} ${date.longMonthName} ${date.hYear} هـ';
    final body = temporaryDarSource
        ? 'تم تصحيح التاريخ إلى $dateText وفق دار الإفتاء المصرية مؤقتًا حتى تحديث جدول هيئة المساحة.'
        : 'تم تصحيح التاريخ الهجري إلى $dateText من المصدر المصري المتاح.';
    await NotificationService.showImmediateNotification(
      title: 'تم تحديث التاريخ الهجري',
      body: body,
      payload: 'home',
    );
    await prefs.setString(_lastNotifiedCorrectionKey, correctionKey);
  }

  static Future<void> setManualOffset(int offset) async {
    final prefs = CacheHelper.prefs;
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final newHijri = HijriCalendar.fromDate(today.add(Duration(days: offset)));
    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setInt(_lockedMonthKey, newHijri.hMonth);
    await prefs.setInt(_lockedYearKey, newHijri.hYear);
    await prefs.setString(_confirmedDateKey, todayStr);
    await prefs.setString('local_hijri_confirmed_source_$todayStr', 'manual');
    await PrayerService.cacheHijriDatesForNative(offset);
    await _refreshHijriWidgets();
    PrayerService().refreshUI();
    await PrayerService().scheduleNotifications(isUserAction: false);
  }

  static int? getLocalOffset() => CacheHelper.prefs.getInt(_localOffsetKey);

  static bool hasConfirmedToday() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return CacheHelper.prefs.getString(_confirmedDateKey) == todayStr;
  }
}
