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

  test('only the matching QPC release assets are allowed package URLs', () {
    const urls = {
      'qpc_v2_1421':
          'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v2_1421.zip',
      'qpc_v4_tajweed_1441':
          'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v4_tajweed_1441.zip',
    };

    for (final entry in urls.entries) {
      expect(_format(entry.key, entry.value).compatible, isTrue);
    }
    expect(
      _format('qpc_v2_1421', urls['qpc_v4_tajweed_1441']!).compatible,
      isFalse,
    );
    expect(
      _format('qpc_v2_1421', 'https://example.com/qpc_v2_1421.zip').compatible,
      isFalse,
    );
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

MushafFormat _format(String id, String url) => MushafFormat.fromJson({
  'id': id,
  'name': id,
  'description': '',
  'page_count': 604,
  'line_count': 15,
  'has_tajweed': id == 'qpc_v4_tajweed_1441',
  'package_url': url,
  'sha256': 'f44c43f65631286cf598eeaf6d4b03a2f5fced56c6dca946de411efd359dc65f',
  'pagination_matches_builtin': false,
  'word_alignment_matches_builtin': true,
  'navigation_index_file': 'pagination.json',
  'navigation_index_sha256':
      '9648068e23c500c3ed0d69462f94719c8f10e2c93d64f7edd195e7f7c42df1ad',
});
