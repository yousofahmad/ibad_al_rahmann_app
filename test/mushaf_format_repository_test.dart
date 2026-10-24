import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in mushaf remains the default family and asset path', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MushafFormatRepository(
      preferences: await SharedPreferences.getInstance(),
      documentsDirectory: await Directory.systemTemp.createTemp('mushaf-test-'),
    );
    await repository.initialize();

    expect(repository.current.id, 'qpc_v1_builtin');
    expect(repository.current.pageCount, 604);
    expect(repository.current.lineCount, 15);
    expect(repository.fontFamily(17), 'QCF_V1_P17');
    expect(repository.pageFontPath(17), isNull);
    expect(FontsHelper.getFontFamily(17), 'QCF_V1_P17');
    expect(FontsHelper.getFontPath(17), 'assets/fonts/QPC V1 Font.ttf/p17.ttf');
  });

  test('incompatible catalog entries cannot be selected', () async {
    SharedPreferences.setMockInitialValues({
      'mushaf_catalog_json':
          '{"schema_version":1,"formats":[{"id":"bad","name":"bad","description":"bad","page_count":603,"line_count":15,"has_tajweed":false,"package_url":"mushaf/formats/bad.zip","sha256":"${'0' * 64}","size_bytes":1,"pagination_matches_builtin":false,"word_alignment_matches_builtin":true}]}',
    });
    final repository = MushafFormatRepository(
      preferences: await SharedPreferences.getInstance(),
      documentsDirectory: await Directory.systemTemp.createTemp('mushaf-test-'),
    );
    await repository.initialize();

    expect(repository.formats.map((format) => format.id), contains('bad'));
    expect(
      repository.formats
          .where((format) => format.id == 'bad')
          .single
          .compatible,
      isFalse,
    );
    expect(() => repository.select('bad'), throwsStateError);
  });
}
