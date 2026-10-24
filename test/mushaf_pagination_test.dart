import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_pagination.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  test('builtin remains exact across all pages and verses', () {
    for (var page = 1; page <= 604; page++) {
      expect(MushafPagination.pageData(page), quran.getPageData(page));
    }
    for (var surah = 1; surah <= 114; surah++) {
      for (var ayah = 1; ayah <= quran.getVerseCount(surah); ayah++) {
        expect(
          MushafPagination.pageForAyah(surah, ayah),
          quran.getPageNumber(surah, ayah),
        );
      }
    }
    expect(MushafPagination.formatId, 'qpc_v1_builtin');
  });

  test(
    'previous mapping uses the previous selected format on the same page',
    () {
      final first = _index('first');
      final second = _index('second');
      MushafPagination.activate(first);
      MushafPagination.activate(second);
      expect(MushafPagination.previousPageData(1), first.pageData(1));
      expect(
        MushafPagination.previousPageForAyah(1, 1),
        first.pageForAyah(1, 1),
      );
      MushafPagination.activate(null);
    },
  );

  test(
    'strict parser rejects incomplete, malformed, and inconsistent indexes',
    () {
      final valid = _json('valid');
      expect(
        () => MushafPaginationIndex.fromJson({...valid, 'verses': {}}),
        throwsFormatException,
      );
      final junk = Map<String, dynamic>.from(valid['verses'] as Map)
        ..['junk:1'] = [1, 1];
      expect(
        () => MushafPaginationIndex.fromJson({...valid, 'verses': junk}),
        throwsFormatException,
      );
      final pages = List<dynamic>.from(valid['pages'] as List);
      final first = Map<String, dynamic>.from(pages.first as Map);
      final data = List<dynamic>.from(first['data'] as List);
      data[0] = {...data[0] as Map, 'start': -1};
      first['data'] = data;
      pages[0] = first;
      expect(
        () => MushafPaginationIndex.fromJson({...valid, 'pages': pages}),
        throwsFormatException,
      );
    },
  );

  test(
    'returned nested collections are deeply immutable and revision increments',
    () {
      final index = _index('immutable');
      final page = index.pageData(1);
      expect(() => page.first['start'] = 99, throwsUnsupportedError);
      expect(
        () => (page as dynamic).add(<String, dynamic>{}),
        throwsUnsupportedError,
      );
      final before = MushafPagination.revision;
      MushafPagination.activate(index);
      expect(MushafPagination.revision, before + 1);
      MushafPagination.activate(null);
    },
  );
}

Map<String, dynamic> _json(String id) {
  final pages = <Map<String, dynamic>>[];
  final memberships = <String, List<int>>{};
  for (var page = 1; page <= 604; page++) {
    final data = (quran.getPageData(page) as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    pages.add({'page': page, 'data': data});
    for (final entry in data) {
      for (
        var ayah = entry['start'] as int;
        ayah <= (entry['end'] as int);
        ayah++
      ) {
        memberships.putIfAbsent('${entry['surah']}:$ayah', () => []).add(page);
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
  return {
    'schema_version': 1,
    'format_id': id,
    'page_count': 604,
    'line_count': 15,
    'pages': pages,
    'verses': verses,
    'words': words,
  };
}

MushafPaginationIndex _index(String id) =>
    MushafPaginationIndex.fromJson(jsonDecode(jsonEncode(_json(id))));
