import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

/// Centralized formatting utility for Arabic numerals, LTR text wrapping,
/// and prayer time / name localizations across the entire application.
class AppFormatters {
  static const String ltr = '\u200E';
  static const String rtl = '\u200F';

  static const List<String> _englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const List<String> _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// Converts any string or number containing English digits (0-9) to Eastern Arabic digits (٠-٩).
  static String toArabicDigits(dynamic input) {
    if (input == null) return '';
    String str = input.toString();
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(_englishDigits[i], _arabicDigits[i]);
    }
    return str;
  }

  /// Wraps a value with Left-To-Right (LTR) unicode marks so numbers, times, and countdowns
  /// render in correct order inside Right-To-Left (RTL) Arabic interfaces.
  static String wrapLtr(dynamic value) {
    if (value == null) return '';
    return '$ltr$value$ltr';
  }

  /// Formats duration or hour/min/sec into a two-digit padded string.
  static String twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Formats time in Arabic (either 12-hour with localized ص/م or 24-hour).
  static String formatTime(DateTime time, {bool is24Hour = false, bool convertToArabicDigits = false}) {
    String formatted = is24Hour ? DateFormat('HH:mm').format(time) : DateFormat.jm('ar').format(time);
    return convertToArabicDigits ? toArabicDigits(formatted) : formatted;
  }

  /// Returns standard Arabic display name for any [Prayer] enum value.
  static String getPrayerArabicName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      case Prayer.none:
        return 'الفجر';
    }
  }
}

/// Extension on [Prayer] enum for clean, direct localization.
extension PrayerArabicExtension on Prayer {
  String get arabicName => AppFormatters.getPrayerArabicName(this);
}

/// Extension on [String] for convenient Arabic digit conversions and LTR wrapping.
extension ArabicDigitsStringExtension on String {
  String get toArabicDigits => AppFormatters.toArabicDigits(this);
  String get wrapLtr => AppFormatters.wrapLtr(this);
}

/// Extension on [num] for convenient Arabic digit conversions and LTR wrapping.
extension ArabicDigitsNumExtension on num {
  String get toArabicDigits => AppFormatters.toArabicDigits(this);
  String get wrapLtr => AppFormatters.wrapLtr(this);
}
