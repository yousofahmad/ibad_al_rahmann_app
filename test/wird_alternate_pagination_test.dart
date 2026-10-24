import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_pagination.dart';
import 'package:ibad_al_rahmann/features/wird/utils/wird_calculator.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  tearDown(() => MushafPagination.activate(null));

  test('builtin Juz starts retain the Madinah 1405 reference map', () {
    expect(WirdCalculator.juzStartPages, <int>[
      1,
      22,
      42,
      62,
      82,
      102,
      122,
      142,
      162,
      182,
      202,
      222,
      242,
      262,
      282,
      302,
      322,
      342,
      362,
      382,
      402,
      422,
      442,
      462,
      482,
      502,
      522,
      542,
      562,
      582,
    ]);
  });

  test('Juz sessions resolve every canonical start in an alternate format', () {
    final alternate = _indexWithMovedBoundary();
    MushafPagination.activate(alternate);

    final expectedStarts = <int>[
      1,
      22,
      42,
      62,
      82,
      102,
      122,
      142,
      162,
      182,
      202,
      222,
      242,
      262,
      282,
      302,
      322,
      342,
      362,
      382,
      402,
      422,
      442,
      462,
      482,
      502,
      522,
      542,
      562,
      582,
    ];
    // The fake format moves the Juz 7 boundary one page earlier.
    expect(WirdCalculator.juzStartPages[6], expectedStarts[6] - 1);

    for (var juz = 0; juz < 30; juz++) {
      final session = WirdCalculator.getSession(
        sessionIndex: juz,
        totalSessions: 30,
        unit: WirdUnit.juz,
      );
      final coordinate = _juzStarts[juz];
      expect(
        session.startPage,
        alternate.pageForAyah(coordinate[0], coordinate[1]),
        reason: 'Juz ${juz + 1} must use its canonical start ayah',
      );
    }

    final finalSession = WirdCalculator.getSession(
      sessionIndex: 29,
      totalSessions: 30,
      unit: WirdUnit.juz,
    );
    expect(finalSession.endPage, alternate.pageCount);

    MushafPagination.activate(null);
    expect(WirdCalculator.juzStartPages, expectedStarts);
  });
}

const _juzStarts = <List<int>>[
  [1, 1],
  [2, 142],
  [2, 253],
  [3, 93],
  [4, 24],
  [4, 148],
  [5, 84],
  [6, 111],
  [7, 88],
  [8, 41],
  [9, 94],
  [11, 6],
  [12, 53],
  [15, 1],
  [17, 1],
  [18, 75],
  [21, 1],
  [23, 1],
  [25, 21],
  [27, 56],
  [29, 46],
  [33, 31],
  [36, 28],
  [39, 32],
  [41, 47],
  [46, 1],
  [51, 31],
  [58, 1],
  [67, 1],
  [78, 1],
];

MushafPaginationIndex _indexWithMovedBoundary() {
  const movedSurah = 5;
  const movedAyah = 84;
  final movedPage = quran.getPageNumber(movedSurah, movedAyah);
  final destinationPage = movedPage - 1;
  final pages = <int, List<Map<String, dynamic>>>{};

  for (var page = 1; page <= 604; page++) {
    pages[page] = quran
        .getPageData(page)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  final source = pages[movedPage]!;
  final sourceRecord = source.firstWhere(
    (entry) =>
        entry['surah'] == movedSurah &&
        (entry['start'] as int) <= movedAyah &&
        movedAyah <= (entry['end'] as int),
  );
  final sourceIndex = source.indexOf(sourceRecord);
  source.removeAt(sourceIndex);
  final start = sourceRecord['start'] as int;
  final end = sourceRecord['end'] as int;
  if (start < movedAyah) {
    source.insert(sourceIndex, {
      'surah': movedSurah,
      'start': start,
      'end': movedAyah - 1,
    });
  }
  if (movedAyah < end) {
    source.insert(sourceIndex + (start < movedAyah ? 1 : 0), {
      'surah': movedSurah,
      'start': movedAyah + 1,
      'end': end,
    });
  }
  pages[destinationPage]!.add({
    'surah': movedSurah,
    'start': movedAyah,
    'end': movedAyah,
  });

  final memberships = <String, List<int>>{};
  for (final entry in pages.entries) {
    for (final record in entry.value) {
      for (
        var ayah = record['start'] as int;
        ayah <= (record['end'] as int);
        ayah++
      ) {
        memberships
            .putIfAbsent('${record['surah']}:$ayah', () => [])
            .add(entry.key);
      }
    }
  }
  final verses = <String, List<int>>{
    for (final entry in memberships.entries)
      entry.key: [entry.value.first, entry.value.last],
  };
  final words = <String, Map<String, int>>{
    for (final entry in verses.entries) entry.key: {'1': entry.value.first},
  };

  return MushafPaginationIndex.fromJson({
    'schema_version': 1,
    'format_id': 'fake_boundary_shift',
    'page_count': 604,
    'line_count': 15,
    'pages': [
      for (final entry in pages.entries)
        {'page': entry.key, 'data': entry.value},
    ],
    'verses': verses,
    'words': words,
  });
}
