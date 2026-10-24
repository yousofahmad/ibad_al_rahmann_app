import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in font families preserve the original 604-page pattern', () {
    for (var page = 1; page <= 604; page++) {
      expect(FontsHelper.getFontFamily(page), 'QCF_V1_P$page');
      expect(
        FontsHelper.getFontPath(page),
        'assets/fonts/QPC V1 Font.ttf/p$page.ttf',
      );
    }
  });

  test('sameFormatFamily compares known format prefixes, not page numbers', () {
    expect(FontsHelper.sameFormatFamily('QCF_V1_P1', 'QCF_V1_P604'), isTrue);
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_QPC_V2_1421_P120',
        'IBAD_QPC_V2_1421_P121',
      ),
      isTrue,
    );
    expect(
      FontsHelper.sameFormatFamily('QCF_V1_P1', 'IBAD_QPC_V2_1421_P1'),
      isFalse,
    );
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_QPC_V2_1421_P1',
        'IBAD_QPC_V4_TAJWEED_1441_P1',
      ),
      isFalse,
    );
    expect(FontsHelper.sameFormatFamily('', 'QCF_V1_P1'), isFalse);
    expect(
      FontsHelper.sameFormatFamily('/tmp/QCF_V1_P1.ttf', 'QCF_V1_P1'),
      isFalse,
    );
  });

  test('built-in font loading uses the real bundled p604 asset', () async {
    await FontsHelper.loadFontFromFamily('QCF_V1_P604');
    expect(FontsHelper.isFontLoaded('QCF_V1_P604'), isTrue);
  });

  test(
    'database built-in branch precedes optional repository initialization',
    () {
      final source = File(
        'lib/features/quran/data/db_helper.dart',
      ).readAsStringSync();
      final getter = source.indexOf('Future<Database> get database async');
      final branch = source.indexOf('if (manager.current.isBuiltin)', getter);
      final initialize = source.indexOf('await manager.initialize()', getter);
      final supportDirectory = source.indexOf(
        'getApplicationSupportDirectory',
        getter,
      );
      expect(getter, greaterThanOrEqualTo(0));
      expect(branch, greaterThan(getter));
      expect(initialize, greaterThan(branch));
      expect(supportDirectory, lessThan(0));
      expect(source, contains("getDatabasesPath()"));
      expect(source, contains("assets', 'databases'"));
    },
  );
}
