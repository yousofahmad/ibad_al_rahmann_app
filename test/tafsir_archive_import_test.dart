import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';

List<int> _zip(Map<String, dynamic> root) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('nested/data.json', json.encode(root)));
  return ZipEncoder().encode(archive);
}

void main() {
  test('imports direct JSON into all 114 serialized surah files', () {
    final result = prepareDownloadedArchive(<int>[
      ...utf8.encode(
        json.encode(<String, dynamic>{
          '1:1': <String, dynamic>{
            'text': 'Grouped {1} full passage (1) [[translated note]]',
          },
        }),
      ),
    ]);

    final files = Map<String, String>.from(result['files'] as Map);
    final stats = Map<String, int>.from(result['stats'] as Map);
    expect(files, hasLength(114));
    expect(
      json.decode(files['1']!)['ayahs'][0]['text'],
      'Grouped {1} full passage (1) (translated note)',
    );
    expect(stats['readableAyahs'], 1);
  });

  test('imports ZIP and resolves chained and cross-surah pointers', () {
    final bytes = _zip(<String, dynamic>{
      '1:1': '1:2',
      '1:2': '2:1',
      '2:1': <String, dynamic>{'text': 'Target passage'},
    });
    final result = prepareDownloadedArchive(bytes);
    final files = Map<String, String>.from(result['files'] as Map);
    final first = json.decode(files['1']!)['ayahs'] as List;
    final second = json.decode(files['2']!)['ayahs'] as List;
    expect(
      first,
      contains(
        predicate(
          (item) =>
              (item as Map)['ayah'] == 1 && item['text'] == 'Target passage',
        ),
      ),
    );
    expect(
      first,
      contains(
        predicate(
          (item) =>
              (item as Map)['ayah'] == 2 && item['text'] == 'Target passage',
        ),
      ),
    );
    expect(second.single['text'], 'Target passage');
  });

  test('rejects missing JSON, invalid roots, and empty readable content', () {
    final noJson = Archive()..addFile(ArchiveFile.string('readme.txt', 'no'));
    expect(
      () => prepareDownloadedArchive(ZipEncoder().encode(noJson)),
      throwsFormatException,
    );
    expect(
      () => prepareDownloadedArchive(utf8.encode('[]')),
      throwsFormatException,
    );
    expect(
      () => prepareDownloadedArchive(utf8.encode(json.encode({'1:1': '1:2'}))),
      throwsFormatException,
    );
  });

  test('cycles remain empty rather than exposing pointer indices', () {
    final result = prepareDownloadedArchive(
      utf8.encode(
        json.encode({
          '1:1': '1:2',
          '1:2': '1:1',
          '1:3': <String, dynamic>{'text': 'Readable'},
        }),
      ),
    );
    final ayahs =
        json.decode(
              Map<String, String>.from(result['files'] as Map)['1']!,
            )['ayahs']
            as List;
    expect(ayahs.first['text'], isEmpty);
    expect(ayahs[1]['text'], isEmpty);
    expect(ayahs[2]['text'], 'Readable');
  });
}
