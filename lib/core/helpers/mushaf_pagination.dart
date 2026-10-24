import 'dart:convert';

import 'package:quran/quran.dart' as quran;

int _canonicalVerseNumber(int surah, int ayah) {
  var result = ayah;
  for (var current = 1; current < surah; current++) {
    result += quran.getVerseCount(current);
  }
  return result;
}

/// Immutable, format-aware pagination index. Optional formats must be built
/// from their selected layout/words databases; this class never infers pages.
class MushafPaginationIndex {
  final String formatId;
  final int pageCount;
  final int lineCount;
  final Map<int, List<Map<String, dynamic>>> _pages;
  final Map<String, List<int>> _verses;
  final Map<String, Map<int, int>> _words;

  MushafPaginationIndex._(
    this.formatId,
    this.pageCount,
    this.lineCount,
    this._pages,
    this._verses,
    this._words,
  );

  factory MushafPaginationIndex.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 ||
        json['format_id'] is! String ||
        json['format_id'] == '' ||
        json['page_count'] is! int ||
        json['line_count'] is! int ||
        json['pages'] is! List ||
        json['verses'] is! Map ||
        json['words'] is! Map) {
      throw const FormatException('Invalid pagination index metadata');
    }
    const pageCount = 604;
    const lineCount = 15;
    if (json['page_count'] != pageCount || json['line_count'] != lineCount) {
      throw const FormatException('Unsupported pagination dimensions');
    }

    final expectedKeys = <String>{};
    for (var surah = 1; surah <= 114; surah++) {
      final count = quran.getVerseCount(surah);
      for (var ayah = 1; ayah <= count; ayah++) {
        expectedKeys.add('$surah:$ayah');
      }
    }
    if (expectedKeys.length != 6236) {
      throw const FormatException('Unexpected Quran verse count');
    }

    final pages = <int, List<Map<String, dynamic>>>{};
    for (final raw in json['pages'] as List) {
      if (raw is! Map || raw['page'] is! int || raw['data'] is! List) {
        throw const FormatException('Invalid page record');
      }
      final page = raw['page'] as int;
      if (page < 1 || page > pageCount || pages.containsKey(page)) {
        throw const FormatException('Invalid page number');
      }
      final records = <Map<String, dynamic>>[];
      for (final item in raw['data'] as List) {
        if (item is! Map ||
            item['surah'] is! int ||
            item['start'] is! int ||
            item['end'] is! int) {
          throw const FormatException('Invalid verse range');
        }
        final surah = item['surah'] as int;
        final start = item['start'] as int;
        final end = item['end'] as int;
        if (surah < 1 ||
            surah > 114 ||
            start < 1 ||
            end < start ||
            end > quran.getVerseCount(surah)) {
          throw const FormatException('Out-of-bounds verse range');
        }
        records.add(
          Map<String, dynamic>.unmodifiable({
            'surah': surah,
            'start': start,
            'end': end,
          }),
        );
      }
      if (records.isEmpty) throw const FormatException('Empty page data');
      for (var i = 1; i < records.length; i++) {
        final previous = records[i - 1];
        final current = records[i];
        if ((current['surah'] as int) < (previous['surah'] as int) ||
            (current['surah'] == previous['surah'] &&
                (current['start'] as int) <= (previous['end'] as int))) {
          throw const FormatException('Unordered or overlapping page ranges');
        }
      }
      pages[page] = List.unmodifiable(records);
    }
    if (pages.length != pageCount ||
        pages.keys.any((page) => !pages.containsKey(page))) {
      throw const FormatException('Missing pages');
    }

    final memberships = <String, List<int>>{};
    var previousCanonical = 0;
    for (final entry in pages.entries) {
      for (final record in entry.value) {
        final surah = record['surah'] as int;
        for (
          var ayah = record['start'] as int;
          ayah <= (record['end'] as int);
          ayah++
        ) {
          final canonical = _canonicalVerseNumber(surah, ayah);
          if (canonical < previousCanonical) {
            throw const FormatException('Page data is not in canonical order');
          }
          previousCanonical = canonical;
          memberships.putIfAbsent('$surah:$ayah', () => <int>[]).add(entry.key);
        }
      }
    }
    if (!memberships.keys.toSet().containsAll(expectedKeys) ||
        memberships.length != expectedKeys.length) {
      throw const FormatException('Page data does not cover every verse');
    }

    final verses = <String, List<int>>{};
    final rawVerses = json['verses'] as Map;
    if (rawVerses.length != expectedKeys.length ||
        rawVerses.keys.map((key) => key.toString()).toSet().length !=
            expectedKeys.length ||
        rawVerses.keys
            .map((key) => key.toString())
            .toSet()
            .difference(expectedKeys)
            .isNotEmpty) {
      throw const FormatException('Invalid verse key set');
    }
    for (final entry in rawVerses.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! List || value.length != 2 || value.any((e) => e is! int)) {
        throw const FormatException('Invalid verse mapping');
      }
      final first = value[0] as int;
      final last = value[1] as int;
      final actual = memberships[key]!;
      if (first < 1 ||
          last > pageCount ||
          first > last ||
          actual.first != first ||
          actual.last != last ||
          actual.toSet().length != actual.length) {
        throw const FormatException('Verse mapping disagrees with page data');
      }
      verses[key] = List.unmodifiable([first, last]);
    }

    final rawWords = json['words'] as Map;
    if (rawWords.length != expectedKeys.length ||
        rawWords.keys
            .map((key) => key.toString())
            .toSet()
            .difference(expectedKeys)
            .isNotEmpty) {
      throw const FormatException('Invalid word key set');
    }
    final words = <String, Map<int, int>>{};
    for (final entry in rawWords.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! Map || value.isEmpty || !verses.containsKey(key)) {
        throw const FormatException('Invalid word mapping');
      }
      final mapped = <int, int>{};
      var previousPage = 0;
      for (final word in value.entries) {
        final position = word.key is int
            ? word.key as int
            : int.tryParse('${word.key}');
        final page = word.value is int ? word.value as int : null;
        if (position == null ||
            page == null ||
            position < 1 ||
            page < 1 ||
            page > pageCount ||
            page < previousPage ||
            page < verses[key]![0] ||
            page > verses[key]![1]) {
          throw const FormatException('Invalid word page mapping');
        }
        previousPage = page;
        mapped[position] = page;
      }
      if (mapped.length != value.length)
        throw const FormatException('Duplicate word position');
      words[key] = Map.unmodifiable(mapped);
    }

    return MushafPaginationIndex._(
      json['format_id'] as String,
      pageCount,
      lineCount,
      Map.unmodifiable(pages),
      Map.unmodifiable(verses),
      Map.unmodifiable(words),
    );
  }

  static MushafPaginationIndex fromString(String value) =>
      MushafPaginationIndex.fromJson(jsonDecode(value) as Map<String, dynamic>);

  int pageForAyah(int surah, int ayah) {
    final value = _verses['$surah:$ayah'];
    if (value == null) throw StateError('Ayah is absent from pagination index');
    return value[0];
  }

  List<Map<String, dynamic>> pageData(int page) =>
      List.unmodifiable(_pages[page] ?? const []);

  bool pageContainsAyah(int page, int surah, int ayah) {
    final range = _verses['$surah:$ayah'];
    return range != null && page >= range[0] && page <= range[1];
  }

  int? pageForWord(int surah, int ayah, int oneBasedPosition) =>
      _words['$surah:$ayah']?[oneBasedPosition];
}

/// Single navigation API for builtin and verified optional Mushaf formats.
class MushafPagination {
  static MushafPaginationIndex? _active;
  static MushafPaginationIndex? _previous;
  static int _revision = 0;

  static int get pageCount => _active?.pageCount ?? 604;
  static int get lineCount => _active?.lineCount ?? 15;
  static String get formatId => _active?.formatId ?? 'qpc_v1_builtin';
  static bool get isBuiltin => _active == null;
  static int get revision => _revision;

  static int pageForAyah(int surah, int ayah) =>
      _active?.pageForAyah(surah, ayah) ?? quran.getPageNumber(surah, ayah);
  static List<Map<String, dynamic>> pageData(int page) =>
      _active?.pageData(page) ??
      (quran.getPageData(page) as List).cast<Map<String, dynamic>>();
  static bool pageContainsAyah(int page, int surah, int ayah) =>
      _active?.pageContainsAyah(page, surah, ayah) ??
      quran
          .getPageData(page)
          .any(
            (e) =>
                e['surah'] == surah &&
                (e['start'] as int) <= ayah &&
                (e['end'] as int) >= ayah,
          );
  static int? pageForWord(int surah, int ayah, int oneBasedPosition) =>
      _active?.pageForWord(surah, ayah, oneBasedPosition);

  static List<Map<String, dynamic>> previousPageData(int page) =>
      _previous?.pageData(page) ??
      (quran.getPageData(page) as List).cast<Map<String, dynamic>>();
  static int previousPageForAyah(int surah, int ayah) =>
      _previous?.pageForAyah(surah, ayah) ?? quran.getPageNumber(surah, ayah);

  static void activate(MushafPaginationIndex? index) {
    _previous = _active;
    _active = index;
    _revision++;
  }

  static MushafPaginationIndex? get previousIndex => _previous;
}
