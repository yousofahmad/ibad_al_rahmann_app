import 'dart:convert';

import 'package:flutter/services.dart';

/// A verified Hijri date published for a civil date by the Egyptian Survey Authority.
class EgyptianHijriDate {
  final int hDay;
  final int hMonth;
  final int hYear;

  const EgyptianHijriDate({
    required this.hDay,
    required this.hMonth,
    required this.hYear,
  });

  static const List<String> _monthNames = <String>[
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

  String get longMonthName => _monthNames[hMonth];

  String get format => '$hDay $longMonthName $hYear هـ';

  @override
  bool operator ==(Object other) =>
      other is EgyptianHijriDate &&
      other.hDay == hDay &&
      other.hMonth == hMonth &&
      other.hYear == hYear;

  @override
  int get hashCode => Object.hash(hDay, hMonth, hYear);
}

class EgyptianHijriCalendar {
  EgyptianHijriCalendar._();

  static const String assetPath = 'assets/data/egyptian_hijri_calendar.json';
  static const String sourceName = 'الهيئة المصرية العامة للمساحة';
  static const String sourceUrl = 'https://www.esa.gov.eg/monthlymwaket.aspx';
  static const String city = 'القاهرة';

  static final EgyptianHijriCalendar instance = EgyptianHijriCalendar._();
  Map<String, EgyptianHijriDate> _dates = const <String, EgyptianHijriDate>{};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    _dates = parseJson(raw);
    _initialized = true;
  }

  /// Parses and validates the complete supplied data file.
  /// No calculated or offset-based values are accepted here.
  static Map<String, EgyptianHijriDate> parseJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Invalid Egyptian Hijri calendar schema');
    }
    final source = decoded['source'];
    if (source is! Map<String, dynamic> ||
        source['name'] != sourceName ||
        source['url'] != sourceUrl ||
        source['city'] != city) {
      throw const FormatException('Invalid Egyptian Hijri calendar source');
    }
    final fetchedAt = DateTime.tryParse(decoded['fetchedAt'].toString());
    if (fetchedAt == null) {
      throw const FormatException('Invalid fetchedAt timestamp');
    }
    final dates = decoded['dates'];
    if (dates is! Map<String, dynamic>) {
      throw const FormatException('Invalid Egyptian Hijri calendar dates');
    }

    final parsed = <String, EgyptianHijriDate>{};
    final keyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    for (final entry in dates.entries) {
      if (!keyPattern.hasMatch(entry.key)) {
        throw FormatException('Invalid civil date key: ${entry.key}');
      }
      final civil = DateTime.tryParse('${entry.key}T00:00:00');
      if (civil == null ||
          civil.year.toString().padLeft(4, '0') != entry.key.substring(0, 4) ||
          civil.month.toString().padLeft(2, '0') != entry.key.substring(5, 7) ||
          civil.day.toString().padLeft(2, '0') != entry.key.substring(8, 10)) {
        throw FormatException('Invalid civil date key: ${entry.key}');
      }
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        throw FormatException('Invalid Hijri date value: ${entry.key}');
      }
      final day = value['day'];
      final month = value['month'];
      final year = value['year'];
      if (day is! int ||
          month is! int ||
          year is! int ||
          day < 1 ||
          day > 30 ||
          month < 1 ||
          month > 12 ||
          year < 1) {
        throw FormatException('Invalid Hijri components: ${entry.key}');
      }
      parsed[entry.key] = EgyptianHijriDate(
        hDay: day,
        hMonth: month,
        hYear: year,
      );
    }
    return Map.unmodifiable(parsed);
  }

  static String civilKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Looks up local civil calendar components exactly; no timezone conversion.
  EgyptianHijriDate? lookup(DateTime civilDate) => _dates[civilKey(civilDate)];

  void resetForTesting() {
    _dates = const <String, EgyptianHijriDate>{};
    _initialized = false;
  }
}
