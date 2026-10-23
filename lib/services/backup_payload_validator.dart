import 'package:quran/quran.dart' as quran;

/// Pure validation for backup payloads before any user data is changed.
class BackupPayloadValidator {
  const BackupPayloadValidator._();

  static bool isValid(Map<String, dynamic> data) {
    final version = data['version'];
    // Current exports are 1.2.0. Accept earlier major-one payloads, never
    // silently interpret a future/incompatible schema or a boolean as a version.
    if (version is! String || !RegExp(r'^1(?:\.\d+){0,2}$').hasMatch(version)) {
      return false;
    }
    if (data['preferences'] == null &&
        data['bookmarks'] == null &&
        data['khatmas'] == null) {
      return false;
    }
    return _isPreferences(data['preferences']) &&
        _isBookmarks(data['bookmarks']) &&
        _isKhatmas(data['khatmas']);
  }

  static bool _isPreferences(Object? value) {
    if (value == null) return true;
    if (value is! Map || value.keys.any((key) => key is! String)) return false;
    return value.values.every(_isPreferenceValue);
  }

  static bool _isPreferenceValue(Object? value) {
    if (value == null || value is bool || value is String) return true;
    if (value is num) return value.isFinite;
    return value is List &&
        value.every((item) => item is String || item == null);
  }

  static bool _isBookmarks(Object? value) {
    if (value == null) return true;
    if (value is! List) return false;
    return value.every((item) {
      if (item is! Map) return false;
      final surah = item['surahNumber'];
      final verse = item['verseNumber'];
      final timestamp = item['bookmarkedAt'];
      if (surah is! num || verse is! num || timestamp is! String) return false;
      if (!surah.isFinite ||
          !verse.isFinite ||
          surah % 1 != 0 ||
          verse % 1 != 0) {
        return false;
      }
      if (surah < 1 ||
          surah > 114 ||
          verse < 1 ||
          verse > quran.getVerseCount(surah.toInt())) {
        return false;
      }
      return DateTime.tryParse(timestamp) != null;
    });
  }

  static bool _isKhatmas(Object? value) =>
      value == null ||
      (value is Map && value.keys.every((key) => key is String));
}
