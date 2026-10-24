import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_pagination.dart';
import 'package:ibad_al_rahmann/features/quran/ui/optional_mushaf_hizb_data.dart';
import 'package:ibad_al_rahmann/features/quran/ui/quran_hizb_data.dart';
import 'package:ibad_al_rahmann/features/quran/ui/quran_rub_boundaries.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  setUp(() => MushafPagination.activate(null));
  tearDown(() => MushafPagination.activate(null));

  test('all 604 builtin header labels remain unchanged', () {
    for (var page = 1; page <= 604; page++) {
      expect(
        OptionalMushafHizbData.labelForPage(page),
        QuranHizbData.labelForPage(page),
        reason: 'Builtin boundary label on page $page',
      );
      expect(
        OptionalMushafHizbData.activeLabelForPage(page),
        QuranHizbData.activeLabelForPage(page),
        reason: 'Builtin active label on page $page',
      );
    }
  });

  test('all 240 generated boundaries match the existing canonical asset', () {
    final source =
        jsonDecode(
              File('assets/data/quran-metadata-rub.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(quranRubBoundaries, hasLength(240));
    const prefixes = ['حزب ', 'ربع الحزب ', 'نصف الحزب ', 'ثلاثة أرباع الحزب '];
    const digits = '٠١٢٣٤٥٦٧٨٩';
    for (var index = 0; index < quranRubBoundaries.length; index++) {
      final boundary = quranRubBoundaries[index];
      final row = source['${index + 1}'] as Map<String, dynamic>;
      expect('${boundary.surah}:${boundary.ayah}', row['first_verse_key']);
      final hizbNumber = (index ~/ 4 + 1).toString();
      final arabic = hizbNumber.split('').map((digit) {
        return digits[int.parse(digit)];
      }).join();
      expect(boundary.label, '${prefixes[index % 4]}$arabic');
    }
  });

  test('optional label follows its first ayah rather than a V1 page', () {
    final originalPage = quran.getPageNumber(5, 82);
    final movedPage = originalPage - 1;
    final labels = OptionalMushafHizbData.resolveRubLabels((surah, ayah) {
      if (surah == 5 && ayah == 82) return movedPage;
      return quran.getPageNumber(surah, ayah);
    });
    expect(labels[movedPage], contains('الحزب ١٣'));
    expect(labels[originalPage] ?? '', isNot(contains('الحزب ١٣')));
  });

  test('multiple boundaries sharing a page are not overwritten', () {
    final labels = OptionalMushafHizbData.resolveRubLabels((_, _) => 1);
    expect(labels, hasLength(1));
    expect(labels[1]!.split(' • '), hasLength(240));
    expect(labels[1], contains('الحزب ١'));
    expect(labels[1], contains('ثلاثة أرباع الحزب ٦٠'));
  });

  test('resolved boundary metadata cannot be mutated by a caller', () {
    final labels = OptionalMushafHizbData.resolveRubLabels(quran.getPageNumber);
    expect(() => labels[1] = 'changed', throwsUnsupportedError);
  });
}
