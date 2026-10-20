import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// v2 deliberately does not load the former automatic Dar-Ifta overrides.
const egyptianHijriStateKey = 'egyptian_hijri_sync_state_v2';
const egyptianHijriConfirmationKey = 'egyptian_hijri_user_confirmation_v1';
const egyptianHijriDeferredKey = 'egyptian_hijri_confirmation_deferred_v1';

class EgyptianHijriDate {
  final int hDay, hMonth, hYear;
  const EgyptianHijriDate({
    required this.hDay,
    required this.hMonth,
    required this.hYear,
  });
  static const _months = [
    '',
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  String get longMonthName => _months[hMonth];
  String get format => '$hDay $longMonthName $hYear هـ';
  Map<String, int> toJson() => {'day': hDay, 'month': hMonth, 'year': hYear};
  @override
  bool operator ==(Object other) =>
      other is EgyptianHijriDate &&
      other.hDay == hDay &&
      other.hMonth == hMonth &&
      other.hYear == hYear;
  @override
  int get hashCode => Object.hash(hDay, hMonth, hYear);
}

class PendingHijriConfirmation {
  final DateTime civilDate;
  final EgyptianHijriDate displayedDate;
  final EgyptianHijriDate? surveyDate, darDate;
  final String reason;
  const PendingHijriConfirmation({
    required this.civilDate,
    required this.displayedDate,
    this.surveyDate,
    this.darDate,
    required this.reason,
  });
}

/// A user-confirmed anchor, advanced only within the same Hijri month to 29.
/// It never guesses whether a month ends on 29 or 30.
class EgyptianHijriUserConfirmation {
  final DateTime anchorDate;
  final EgyptianHijriDate hijri;
  final String confirmedAt;
  const EgyptianHijriUserConfirmation({
    required this.anchorDate,
    required this.hijri,
    required this.confirmedAt,
  });
  DateTime get expiresOn => DateTime(
    anchorDate.year,
    anchorDate.month,
    anchorDate.day + (hijri.hDay < 29 ? 29 - hijri.hDay : 0),
  );
  EgyptianHijriDate? lookup(DateTime civil) {
    final offset = DateTime.utc(civil.year, civil.month, civil.day)
        .difference(
          DateTime.utc(anchorDate.year, anchorDate.month, anchorDate.day),
        )
        .inDays;
    final value = hijri.hDay + offset;
    if (offset < 0 || value > 29 && offset != 0 || value < 1) return null;
    return EgyptianHijriDate(
      hDay: value,
      hMonth: hijri.hMonth,
      hYear: hijri.hYear,
    );
  }

  bool recheckDue(DateTime today) =>
      !DateTime.utc(today.year, today.month, today.day).isBefore(
        DateTime.utc(expiresOn.year, expiresOn.month, expiresOn.day),
      ) &&
      EgyptianHijriCalendar.civilKey(today) !=
          EgyptianHijriCalendar.civilKey(anchorDate);
  Map<String, dynamic> toJson() => {
    'anchorDate': EgyptianHijriCalendar.civilKey(anchorDate),
    ...hijri.toJson(),
    'confirmedAt': confirmedAt,
    'expiresOn': EgyptianHijriCalendar.civilKey(expiresOn),
  };
  static EgyptianHijriUserConfirmation parse(String raw) {
    final x = jsonDecode(raw);
    if (x is! Map || x['anchorDate'] is! String) {
      throw const FormatException('Invalid confirmation');
    }
    final date = EgyptianHijriCalendar.parseCivilKey(x['anchorDate']);
    final value = EgyptianHijriCalendar.parseDates({
      x['anchorDate']: x,
    })[x['anchorDate']]!;
    final stamp = DateTime.tryParse(x['confirmedAt']?.toString() ?? '');
    if (stamp == null) {
      throw const FormatException('Invalid confirmation timestamp');
    }
    final result = EgyptianHijriUserConfirmation(
      anchorDate: date,
      hijri: value,
      confirmedAt: stamp.toUtc().toIso8601String(),
    );
    if (x['expiresOn'] != EgyptianHijriCalendar.civilKey(result.expiresOn)) {
      throw const FormatException('Invalid confirmation expiry');
    }
    return result;
  }
}

/// One national calendar. Cairo is only the representative ESA row fetched.
class EgyptianHijriCalendar extends ChangeNotifier {
  EgyptianHijriCalendar._();
  static const assetPath = 'assets/data/egyptian_hijri_calendar.json';
  static const sourceName = 'الهيئة المصرية العامة للمساحة';
  static const sourceUrl = 'https://www.esa.gov.eg/monthlymwaket.aspx';
  static const city = 'القاهرة';
  static final instance = EgyptianHijriCalendar._();
  Map<String, EgyptianHijriDate> _survey = const {};
  EgyptianHijriUserConfirmation? _confirmation;
  PendingHijriConfirmation? _pending;
  String? _deferredOn, _status, _error;
  bool _initialized = false;
  bool get isInitialized => _initialized;
  String? get verificationStatus => _status;
  String? get lastError => _error;
  Map<String, EgyptianHijriDate> get surveyDates => _survey;
  EgyptianHijriUserConfirmation? get userConfirmation => _confirmation;
  PendingHijriConfirmation? get pendingConfirmation => _pending;
  bool get shouldPromptConfirmation =>
      _pending != null && _deferredOn != civilKey(_pending!.civilDate);

  Future<void> initialize({AssetBundle? bundle}) async {
    _survey = parseJson(await (bundle ?? rootBundle).loadString(assetPath));
    _initialized = true;
    _pending = null;
    _status = 'جدول المساحة المحفوظ؛ جارٍ مراجعة تحديث المصدرين.';
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(egyptianHijriStateKey);
      if (raw != null) {
        final state = jsonDecode(raw);
        if (state is Map && state['schemaVersion'] == 2) {
          _survey = Map.unmodifiable({
            ..._survey,
            ...parseDates(state['survey']),
          });
        }
      }
      restoreUserConfirmation(prefs);
    } catch (_) {
      /* Keep the bundled table when the cache is unavailable. */
    }
    notifyListeners();
  }

  void restoreUserConfirmation(SharedPreferences prefs) {
    _confirmation = null;
    _deferredOn = prefs.getString(egyptianHijriDeferredKey);
    try {
      final raw = prefs.getString(egyptianHijriConfirmationKey);
      if (raw != null) _confirmation = EgyptianHijriUserConfirmation.parse(raw);
    } catch (_) {
      /* Never display malformed or unbounded manual data. */
    }
  }

  static String civilKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static DateTime parseCivilKey(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
      throw const FormatException('Invalid civil key');
    }
    final date = DateTime.tryParse('${key}T00:00:00');
    if (date == null || civilKey(date) != key) {
      throw const FormatException('Invalid civil date');
    }
    return date;
  }

  static Map<String, EgyptianHijriDate> parseDates(dynamic raw) {
    if (raw is! Map) throw const FormatException('Invalid dates map');
    final result = <String, EgyptianHijriDate>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw const FormatException('Invalid civil key');
      }
      parseCivilKey(entry.key);
      final v = entry.value;
      if (v is! Map ||
          v['day'] is! int ||
          v['month'] is! int ||
          v['year'] is! int) {
        throw const FormatException('Invalid Hijri components');
      }
      final d = v['day'] as int, m = v['month'] as int, y = v['year'] as int;
      if (d < 1 || d > 30 || m < 1 || m > 12 || y < 1 || y > 9999) {
        throw const FormatException('Invalid Hijri range');
      }
      result[entry.key] = EgyptianHijriDate(hDay: d, hMonth: m, hYear: y);
    }
    return Map.unmodifiable(result);
  }

  static Map<String, EgyptianHijriDate> parseJson(String raw) {
    final x = jsonDecode(raw);
    if (x is! Map || x['schemaVersion'] != 1) {
      throw const FormatException('Invalid Egyptian calendar schema');
    }
    final s = x['source'];
    if (s is! Map ||
        s['name'] != sourceName ||
        s['url'] != sourceUrl ||
        s['city'] != city ||
        DateTime.tryParse(x['fetchedAt']?.toString() ?? '') == null) {
      throw const FormatException('Invalid Egyptian calendar source');
    }
    return parseDates(x['dates']);
  }

  EgyptianHijriDate? lookup(DateTime date) =>
      _confirmation?.lookup(date) ?? _survey[civilKey(date)];
  String dateSourceLabel(DateTime date) => _confirmation?.lookup(date) != null
      ? 'بتأكيد المستخدم'
      : (_survey.containsKey(civilKey(date)) ? sourceName : 'غير متاح');

  EgyptianHijriDate? choiceForAdjustment(
    DateTime civil,
    EgyptianHijriDate displayed,
    int adjustment,
  ) {
    if (adjustment < -1 || adjustment > 1) return null;
    final day = displayed.hDay + adjustment;
    if (day >= 1 && day <= 30) {
      return EgyptianHijriDate(
        hDay: day,
        hMonth: displayed.hMonth,
        hYear: displayed.hYear,
      );
    }
    // Crossing month/year boundaries requires an actually published adjacent
    // row, not an assumed 29/30-day month or a Hijri conversion library.
    final adjacent =
        _survey[civilKey(
          DateTime(civil.year, civil.month, civil.day + adjustment),
        )];
    if (adjacent == null ||
        adjacent.hMonth == displayed.hMonth &&
            adjacent.hYear == displayed.hYear) {
      return null;
    }
    if (adjustment < 0 && adjacent.hDay >= 29 ||
        adjustment > 0 && adjacent.hDay == 1) {
      return adjacent;
    }
    return null;
  }

  void applyUserConfirmation(EgyptianHijriUserConfirmation confirmation) {
    _confirmation = confirmation;
    _pending = null;
    _deferredOn = null;
    _status = 'تم حفظ تأكيدك للتاريخ؛ نعيد التحقق عند يوم ٢٩.';
    notifyListeners();
  }

  void deferConfirmation(String day) {
    _deferredOn = day;
    notifyListeners();
  }

  void replaceSnapshot(
    Map<String, EgyptianHijriDate> survey, {
    PendingHijriConfirmation? pending,
    String? status,
    String? error,
  }) {
    _survey = Map.unmodifiable(survey);
    _pending = pending;
    _initialized = true;
    _status = status;
    _error = error;
    notifyListeners();
  }

  void resetForTesting() {
    _survey = const {};
    _confirmation = null;
    _pending = null;
    _deferredOn = null;
    _status = null;
    _error = null;
    _initialized = false;
    notifyListeners();
  }
}
