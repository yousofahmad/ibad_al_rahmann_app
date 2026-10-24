import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_content_parser.dart';

void main() {
  Map<String, dynamic> parse(Map<String, dynamic> root) =>
      parseTafsirContentWithStats(root);

  String text(Map<String, dynamic> result, int surah, int ayah) =>
      ((result['data'] as Map)[surah] as List).cast<Map>().singleWhere(
            (item) => item['ayah'] == ayah,
          )['text']
          as String;

  test('resolves an arbitrary-length pointer chain iteratively', () {
    final result = parse({
      '2:1': '2:2',
      '2:2': '2:3',
      '2:3': {
        'text': 'authoritative',
        'ayah_keys': ['2:3'],
      },
    });

    expect(text(result, 2, 1), 'authoritative');
    expect(text(result, 2, 2), 'authoritative');
    expect((result['stats'] as Map)['resolvedPointers'], 2);
  });

  test('resolves an explicit valid cross-surah pointer to its source root', () {
    final result = parse({
      '1:1': '2:3',
      '2:3': {
        'text': 'shared source',
        'ayah_keys': ['2:3', '2:4'],
      },
    });

    expect(text(result, 1, 1), 'shared source');
    expect(text(result, 2, 3), 'shared source');
    expect(text(result, 2, 4), 'shared source');
  });

  test('preserves one authoritative shared passage for every listed ayah', () {
    final result = parse({
      '49:1': {
        'text': 'same passage [1] /(1)/ [[footnote]]',
        'ayah_keys': ['49:1', '49:2', '49:2'],
      },
    });

    expect(text(result, 49, 1), 'same passage [1] /(1)/ [[footnote]]');
    expect(text(result, 49, 2), 'same passage [1] /(1)/ [[footnote]]');
    expect((result['stats'] as Map)['nonEmptyAyahs'], 2);
  });

  test(
    'keeps plain string tafsir text and does not split marker-like text',
    () {
      final result = parse({'1:1': 'English [1] /(1)/ footnote'});
      expect(text(result, 1, 1), 'English [1] /(1)/ footnote');
    },
  );

  test('clears dangling pointers without exposing the pointer text', () {
    final result = parse({'2:1': '2:2'});
    expect(text(result, 2, 1), isEmpty);
    expect(text(result, 2, 1), isNot('2:2'));
    expect((result['stats'] as Map)['invalidReferences'], 1);
  });

  test('clears every member of a cyclic pointer chain safely', () {
    final result = parse({'2:1': '2:2', '2:2': '2:1'});
    expect(text(result, 2, 1), isEmpty);
    expect(text(result, 2, 2), isEmpty);
    expect((result['stats'] as Map)['invalidReferences'], 2);
  });

  test('deduplicates and sorts output ayahs and surahs', () {
    final result = parse({
      '3:2': {
        'text': 'three',
        'ayah_keys': ['3:2', '3:2'],
      },
      '3:1': 'one',
      '2:1': 'two',
    });
    final data = result['data'] as Map;
    expect(data.keys, [2, 3]);
    expect((data[3] as List).map((item) => item['ayah']), [1, 2]);
  });

  test(
    'explicit ayah content takes precedence over overlapping group metadata',
    () {
      final result = parse({
        '2:1': {
          'text': 'group',
          'ayah_keys': ['2:1', '2:2', '2:3'],
        },
        '2:2': {
          'text': 'dedicated',
          'ayah_keys': ['2:2'],
        },
        '2:3': '2:2',
      });
      expect(text(result, 2, 1), 'group');
      expect(text(result, 2, 2), 'dedicated');
      expect(text(result, 2, 3), 'dedicated');
    },
  );

  test('oversized invalid coordinates do not discard valid content', () {
    final huge = '9' * 100;
    final result = parse({
      '$huge:1': 'invalid',
      '1:$huge': 'invalid',
      '1:1': 'valid',
    });
    expect(text(result, 1, 1), 'valid');
    expect((result['stats'] as Map)['nonEmptyAyahs'], 1);
  });

  test('ignores malformed keys but accepts an archive with valid content', () {
    final result = parse({
      'not-an-ayah': 'ignored',
      '0:1': 'ignored',
      '115:1': 'ignored',
      '1:1': {
        'text': 'valid',
        'ayah_keys': ['1:1', 'bad'],
      },
    });
    expect(text(result, 1, 1), 'valid');
    expect((result['stats'] as Map)['surahCount'], 1);
  });

  test('malformed values produce an empty valid ayah entry', () {
    final result = parse({
      '1:1': <String, dynamic>{'ayah_keys': 'bad'},
    });
    expect(text(result, 1, 1), isEmpty);
  });

  test('rejects empty or completely unusable archives', () {
    expect(
      () => parseTafsirContent(<String, dynamic>{}),
      throwsFormatException,
    );
    expect(
      () => parseTafsirContent({'bad': 'not a coordinate'}),
      throwsFormatException,
    );
    expect(() => parseTafsirContent([]), throwsFormatException);
  });
}
