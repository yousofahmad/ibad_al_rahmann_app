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

Future<http.Response?> _getWithLongRetry(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  const timeouts = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 45),
  ];
  for (var attempt = 0; attempt < timeouts.length; attempt++) {
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeouts[attempt]);
      if (response.statusCode < 500 && response.statusCode != 408) {
        return response;
      }
    } catch (_) {
      // Retry transient failures and weak connections with a longer timeout.
    }
    if (attempt + 1 < timeouts.length) {
      await Future<void>.delayed(Duration(seconds: 2 << attempt));
    }
  }
  return null;
}

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
      final response = await _getWithLongRetry(Uri.parse(apiUrl));
      if (response != null && response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final date = _findDate(decoded);
        if (date != null) return date;
        AppLogger.log(
          'HijriSync',
          'Dar Al-Ifta returned an unrecognized Hijri date: ${response.body}',
        );
      } else if (response != null) {
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
      final response = await _getWithLongRetry(
        Uri.parse(pageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      if (response != null && response.statusCode == 200) {
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
      } else if (response != null) {
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
  static const Duration _retryInterval = Duration(hours: 23);

  static final EgyptDarAlIftaProvider _darAlIftaProvider =
      EgyptDarAlIftaProvider();
  static final EgyptSurveyAuthorityProvider _surveyAuthorityProvider =
      EgyptSurveyAuthorityProvider();
  static bool _isSyncing = false;

  static HijriSourceDate? get storedHijriDate {
    final prefs = CacheHelper.prefs;
    final day = prefs.getInt('local_hijri_official_day');
    final month = prefs.getInt('local_hijri_official_month');
    final year = prefs.getInt('local_hijri_official_year');
    if (day == null || month == null || year == null) return null;
    if (day < 1 || day > 30 || month < 1 || month > 12) return null;
    return HijriSourceDate(day: day, month: month, year: year);
  }

  static bool get hasStoredDate => storedHijriDate != null;

  static bool get hasTrustedStoredDate {
    if (!hasStoredDate) return false;
    final prefs = CacheHelper.prefs;
    final source = prefs.getString('local_hijri_date_source');
    if (source == 'survey_authority') return false;
    final lastFetch = prefs.getString(_lastFetchDateKey);
    final olderSource = lastFetch == null
        ? null
        : prefs.getString('local_hijri_confirmed_source_$lastFetch');
    if (source == null && olderSource == 'survey_authority') return false;
    return true;
  }

  static bool get needsInternetRefresh =>
      PrayerService.isEgyptianSystem &&
      ((CacheHelper.prefs.getBool(_temporarySourceKey) ?? false) ||
          !hasTrustedStoredDate);

  /// The daily Dar Al-Ifta API is the live date source; ESA only verifies it.
  /// Return null when Dar is unavailable rather than substituting ESA's table.
  static HijriSourceDate? selectLiveDate({
    required HijriSourceDate? darAlIftaDate,
    required HijriSourceDate? surveyAuthorityDate,
  }) => darAlIftaDate;

  static HijriSourceDate projectOfflineDate(
    HijriSourceDate savedDate,
    int elapsedDays,
  ) {
    var projected = savedDate;
    for (var i = 0; i < elapsedDays; i++) {
      if (projected.day == 29) break;
      if (projected.day == 30) {
        final nextMonth = projected.month == 12 ? 1 : projected.month + 1;
        final nextYear = projected.month == 12
            ? projected.year + 1
            : projected.year;
        projected = HijriSourceDate(day: 1, month: nextMonth, year: nextYear);
      } else {
        projected = HijriSourceDate(
          day: projected.day + 1,
          month: projected.month,
          year: projected.year,
        );
      }
    }
    return projected;
  }

  /// Compares Egyptian sources after local midnight. Dar Al-Ifta is the
  /// provisional source until the Survey Authority catches up.
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
    if (hasStoredDate && hasTrustedStoredDate) {
      await _adoptStoredDate(currentTime, rescheduleNotifications);
    } else if (hasStoredDate) {
      final hadLocalOffset = prefs.containsKey(_localOffsetKey);
      final nativeNeedsReschedule =
          prefs.getBool('local_hijri_native_reschedule_required') ?? false;
      final fallbackWasApplied =
          prefs.getBool('local_hijri_library_fallback_applied') ?? false;
      await prefs.remove(_localOffsetKey);
      await prefs.setBool(_temporarySourceKey, true);
      if (hadLocalOffset || nativeNeedsReschedule || !fallbackWasApplied) {
        final libraryOffset = PrayerService().hijriOffset;
        await PrayerService.cacheHijriDatesForNative(libraryOffset);
        await _refreshHijriWidgets();
        PrayerService().refreshUI();
        if (rescheduleNotifications && hadLocalOffset) {
          await PrayerService().scheduleNotifications(isUserAction: false);
        }
        await prefs.setBool('local_hijri_library_fallback_applied', true);
        await prefs.setBool('local_hijri_native_reschedule_required', false);
      }
    }
    final temporaryDarSource = prefs.getBool(_temporarySourceKey) ?? false;
    final lastFetchDate = prefs.getString(_lastFetchDateKey);
    if (lastFetchDate == todayStr &&
        !temporaryDarSource &&
        hasTrustedStoredDate) {
      return;
    }

    final lastAttemptRaw = prefs.getString(_lastAttemptAtKey);
    if (lastAttemptRaw != null) {
      final lastAttempt = DateTime.tryParse(lastAttemptRaw);
      if (lastAttempt != null &&
          DateFormat('yyyy-MM-dd').format(lastAttempt) == todayStr &&
          currentTime.difference(lastAttempt) < _retryInterval) {
        await _applyOfflineProjection(currentTime);
        return;
      }
    }

    _isSyncing = true;
    try {
      final success = await _performDualSync(
        todayStr,
        currentTime,
        rescheduleNotifications: rescheduleNotifications,
      );
      if (!success) {
        await _applyOfflineProjection(currentTime);
        await _showSyncFailureNotification(todayStr);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Backwards-compatible entry point; the check is now civil-day based and
  /// automatic execution belongs to HijriSyncScheduler, not the prayer alarm.
  static Future<bool> checkEveOf29CriticalSync({
    DateTime? now,
    bool rescheduleNotifications = true,
  }) async {
    return true;
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
        await _applyOfflineProjection(now);
        await _showSyncFailureNotification(todayStr);
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
    int maxOffset = 3,
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

    // Dar Al-Ifta supplies today's live date. The Survey Authority's complete
    // calendar is only a verifier; never substitute it when the live API fails.
    final chosenDate = selectLiveDate(
      darAlIftaDate: darAlIftaDate,
      surveyAuthorityDate: esaDate,
    );
    if (chosenDate == null) return false;

    final offset = resolveOffsetForDate(chosenDate, comparisonDate);
    if (offset == null) {
      AppLogger.log(
        'HijriSync',
        'Rejected Dar Al-Ifta Hijri date ${_formatDate(chosenDate)}: no safe offset within +/-3 days of the local calculation.',
      );
      return false;
    }

    HijriCalendar.setLocal('ar');
    final previousOffset = prefs.getInt(_localOffsetKey);
    final previousDate = storedHijriDate;
    final wasTemporary = prefs.getBool(_temporarySourceKey) ?? false;
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
    final chosenSource = esaDate != null && chosenDate.sameDate(esaDate)
        ? 'both_authorities'
        : 'dar_alifta_api';
    await _saveStoredDate(chosenDate, comparisonDate, chosenSource);
    await prefs.setString(
      'local_hijri_confirmed_source_$todayStr',
      chosenSource,
    );
    await prefs.setBool(_temporarySourceKey, temporaryDarSource);
    await prefs.setBool('local_hijri_native_reschedule_required', false);
    await prefs.setBool('local_hijri_library_fallback_applied', false);

    await PrayerService.cacheHijriDatesForNative(offset);
    await _refreshHijriWidgets();
    PrayerService().refreshUI();

    if (rescheduleNotifications && (dateChanged || previousOffset != offset)) {
      await PrayerService().scheduleNotifications(isUserAction: false);
    }

    final newlyVerified = previousDate == null || wasTemporary;
    if (dateChanged || newlyVerified) {
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

  static Future<void> _saveStoredDate(
    HijriSourceDate date,
    DateTime civilDate,
    String source,
  ) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt('local_hijri_official_day', date.day);
    await prefs.setInt('local_hijri_official_month', date.month);
    await prefs.setInt('local_hijri_official_year', date.year);
    await prefs.setString(
      'local_hijri_anchor_civil_date',
      DateFormat('yyyy-MM-dd').format(civilDate),
    );
    await prefs.setString('local_hijri_date_source', source);
  }

  static Future<void> _adoptStoredDate(
    DateTime now,
    bool rescheduleNotifications,
  ) async {
    final prefs = CacheHelper.prefs;
    final date = storedHijriDate;
    if (date == null || !hasTrustedStoredDate) return;
    final offset = resolveOffsetForDate(date, now);
    if (offset == null) {
      AppLogger.log(
        'HijriSync',
        'Stored Android date ${_formatDate(date)} could not be resolved by the Dart calendar.',
      );
      return;
    }
    final offsetChanged = prefs.getInt(_localOffsetKey) != offset;
    final nativeRescheduleRequired =
        prefs.getBool('local_hijri_native_reschedule_required') ?? false;
    if (!offsetChanged && !nativeRescheduleRequired) return;

    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setInt(_lockedMonthKey, date.month);
    await prefs.setInt(_lockedYearKey, date.year);
    await prefs.setBool('local_hijri_native_reschedule_required', false);
    await PrayerService.cacheHijriDatesForNative(offset);
    await _refreshHijriWidgets();
    PrayerService().refreshUI();
    if (rescheduleNotifications) {
      try {
        await PrayerService().scheduleNotifications(isUserAction: false);
      } catch (e) {
        AppLogger.log(
          'HijriSync',
          'Native date adoption reschedule failed: $e',
        );
      }
    }
  }

  static Future<bool> _applyOfflineProjection(DateTime now) async {
    final prefs = CacheHelper.prefs;
    final savedDate = storedHijriDate;
    if (savedDate == null || !hasTrustedStoredDate) {
      final hadLocalOffset = prefs.containsKey(_localOffsetKey);
      final nativeNeedsReschedule =
          prefs.getBool('local_hijri_native_reschedule_required') ?? false;
      await prefs.remove(_localOffsetKey);
      await prefs.setBool(_temporarySourceKey, true);
      if (hadLocalOffset || nativeNeedsReschedule) {
        final libraryOffset = PrayerService().hijriOffset;
        await PrayerService.cacheHijriDatesForNative(libraryOffset);
        await _refreshHijriWidgets();
        PrayerService().refreshUI();
        await prefs.setBool('local_hijri_native_reschedule_required', false);
        await prefs.setBool('local_hijri_library_fallback_applied', true);
        try {
          await PrayerService().scheduleNotifications(isUserAction: false);
        } catch (e) {
          AppLogger.log('HijriSync', 'Library fallback reschedule failed: $e');
        }
      }
      return false;
    }

    final anchorRaw = prefs.getString('local_hijri_anchor_civil_date');
    final anchor = anchorRaw == null ? null : DateTime.tryParse(anchorRaw);
    if (anchor == null) return false;
    final today = DateTime.utc(now.year, now.month, now.day);
    final anchorDay = DateTime.utc(anchor.year, anchor.month, anchor.day);
    final elapsedDays = today.difference(anchorDay).inDays;
    if (elapsedDays <= 0) return false;

    // Offline projection is intentionally capped at Hijri day 29. The app
    // must not guess whether the next day is day 30 or the new month's 1st.
    final projectedDate = projectOfflineDate(savedDate, elapsedDays);
    final offset = resolveOffsetForDate(projectedDate, today);
    if (offset == null) return false;

    final previousOffset = prefs.getInt(_localOffsetKey);
    final previousHijri = PrayerService.getHijriWithOffset(0, today);
    final updatedHijri = HijriCalendar.fromDate(
      today.add(Duration(days: offset)),
    );
    final changed =
        previousHijri.hDay != updatedHijri.hDay ||
        previousHijri.hMonth != updatedHijri.hMonth ||
        previousHijri.hYear != updatedHijri.hYear;

    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setInt(_lockedMonthKey, projectedDate.month);
    await prefs.setInt(_lockedYearKey, projectedDate.year);
    await prefs.setString(
      _confirmedDateKey,
      DateFormat('yyyy-MM-dd').format(today),
    );
    await prefs.setBool(_temporarySourceKey, true);
    await _saveStoredDate(projectedDate, today, 'offline_estimate');

    if (changed || previousOffset != offset) {
      await PrayerService.cacheHijriDatesForNative(offset);
      await _refreshHijriWidgets();
      PrayerService().refreshUI();
      try {
        await PrayerService().scheduleNotifications(isUserAction: false);
      } catch (e) {
        AppLogger.log(
          'HijriSync',
          'Offline notification reschedule failed: $e',
        );
      }
    }
    return true;
  }

  static Future<void> _showSyncFailureNotification(String todayStr) async {
    final prefs = CacheHelper.prefs;
    final key = 'local_hijri_failure_notified_$todayStr';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    final date = storedHijriDate;
    final body = date == null || !hasTrustedStoredDate
        ? 'تعذر الاتصال بالمصادر المصرية، ولا يوجد تاريخ رسمي محفوظ. سيُستخدم تاريخ المكتبة مؤقتًا؛ حدّثه من الإعدادات أو أدخله يدويًا.'
        : date.day >= 29
        ? 'فشل تحديث المصادر المصرية، ووصل التاريخ المحفوظ إلى اليوم 29. اتصل بالإنترنت لتأكيد هل الغد 30 أم غرة الشهر.'
        : 'تعذر الاتصال بالمصادر المصرية. سيواصل التطبيق من التاريخ المحفوظ مؤقتًا وسيحاول التحديث مجددًا.';
    await NotificationService.showImmediateNotification(
      title: 'تعذّر تحديث التاريخ الهجري',
      body: body,
      payload: 'hijri_confirmation',
    );
  }

  /// Records an explicit sighting decision for the current Egyptian date.
  static Future<bool> setManualHijriDate(HijriSourceDate date) async {
    if (!PrayerService.isEgyptianSystem) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final offset = resolveOffsetForDate(date, today);
    if (offset == null) return false;

    final prefs = CacheHelper.prefs;
    final previousOffset = prefs.getInt(_localOffsetKey);
    await prefs.setInt(_localOffsetKey, offset);
    await prefs.setInt(_lockedMonthKey, date.month);
    await prefs.setInt(_lockedYearKey, date.year);
    await prefs.setString(
      _confirmedDateKey,
      DateFormat('yyyy-MM-dd').format(today),
    );
    await prefs.setString(
      'local_hijri_confirmed_source_${DateFormat('yyyy-MM-dd').format(today)}',
      'manual',
    );
    await prefs.setBool(_temporarySourceKey, true);
    await _saveStoredDate(date, today, 'manual');
    await prefs.setBool('local_hijri_library_fallback_applied', false);
    await PrayerService.cacheHijriDatesForNative(offset);
    await _refreshHijriWidgets();
    PrayerService().refreshUI();
    if (previousOffset != offset) {
      await PrayerService().scheduleNotifications(isUserAction: false);
    }
    await prefs.remove(_lastAttemptAtKey);
    return true;
  }

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
