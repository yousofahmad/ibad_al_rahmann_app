import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/mushaf_format_picker.dart';

class _PickerRepository extends MushafFormatRepository {
  _PickerRepository({
    required super.preferences,
    required super.documentsDirectory,
  });

  // Networking and disk imports are covered by the repository tests, not the
  // widget test's fake clock.
  @override
  Future<void> refreshCatalog() async {}
}

void main() {
  late Directory documents;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('mushaf-picker-docs-');
  });

  tearDown(() {
    documents.deleteSync(recursive: true);
  });

  Future<MushafFormatRepository> repository(
    List<Map<String, dynamic>> formats,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mushaf_catalog_json': jsonEncode({
        'schema_version': 1,
        'formats': formats,
      }),
    });
    final result = _PickerRepository(
      preferences: await SharedPreferences.getInstance(),
      documentsDirectory: documents,
    );
    await result.initialize();
    return result;
  }

  Future<void> show(WidgetTester tester, MushafFormatRepository source) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MushafFormatPicker(repository: source)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('built-in option remains visible with an empty catalog', (
    tester,
  ) async {
    final source = (await tester.runAsync(() => repository([])))!;
    await show(tester, source);
    expect(find.text('تنسيقات المصحف'), findsOneWidget);
    expect(find.text(MushafFormat.builtin.displayName), findsOneWidget);
    expect(find.text('الحالي'), findsOneWidget);
    expect(source.current.id, MushafFormat.builtin.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });

  testWidgets('incompatible format is hidden', (tester) async {
    final source = (await tester.runAsync(
      () => repository([
        {
          'id': 'unsupported_603',
          'name': 'تنسيق آخر ذو اسم عربي طويل لاختبار عرض الهاتف',
          'description': 'هذا التخطيط لا يطابق ترقيم صفحات المصحف الحالي',
          'page_count': 603,
          'line_count': 15,
          'has_tajweed': false,
          'package_url': 'mushaf/formats/unsupported_603.zip',
          'sha256': '0' * 64,
          'size_bytes': 100,
          'pagination_matches_builtin': false,
          'word_alignment_matches_builtin': true,
        },
      ]),
    ))!;
    expect(
      source.formats.map((format) => format.id),
      contains('unsupported_603'),
    );
    await show(tester, source);
    expect(
      find.text('تنسيق آخر ذو اسم عربي طويل لاختبار عرض الهاتف'),
      findsNothing,
    );
    expect(
      find.text('بعض التنسيقات غير المتوافقة مخفية لحماية التنقل والتظليل.'),
      findsNothing,
    );
    expect(find.text('تنزيل'), findsNothing);
    expect(find.text('تفعيل'), findsNothing);
    expect(source.current.id, MushafFormat.builtin.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });

  testWidgets('only supported layouts are listed and downloadable', (
    tester,
  ) async {
    final source = (await tester.runAsync(
      () => repository([
        _format(
          'qpc_v2_1421',
          'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v2_1421.zip',
        ),
        _format(
          'qpc_v4_tajweed_1441',
          'https://github.com/yousofahmad/ibad-alrahman-features/releases/download/qpc-layouts-v1/qpc_v4_tajweed_1441.zip',
        ),
        _format(
          'digital_khatt_v2',
          'mushaf/formats/digital_khatt_v2.zip',
          unicode: true,
        ),
        _format(
          'another_compatible_layout',
          'mushaf/formats/another_compatible_layout.zip',
        ),
      ]),
    ))!;
    expect(source.formats.map((format) => format.id), [
      MushafFormat.builtin.id,
      'qpc_v2_1421',
      'qpc_v4_tajweed_1441',
      'digital_khatt_v2',
      'another_compatible_layout',
    ]);
    await show(tester, source);

    expect(find.text(MushafFormat.builtin.displayName), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('مصحف المدينة المنورة (1421هـ)'),
      180,
      scrollable: scrollable,
    );
    expect(find.text('مصحف المدينة المنورة (1421هـ)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('مصحف التجويد الملوّن (1441هـ)'),
      180,
      scrollable: scrollable,
    );
    expect(find.text('مصحف التجويد الملوّن (1441هـ)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('الخط الرقمي — الإصدار الثاني'),
      180,
      scrollable: scrollable,
    );
    expect(find.text('الخط الرقمي — الإصدار الثاني'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('اسم تقني'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });
}

Map<String, dynamic> _format(String id, String url, {bool unicode = false}) => {
  'id': id,
  'name': 'اسم تقني',
  'description': '',
  'page_count': 604,
  'line_count': 15,
  'has_tajweed': id == 'qpc_v4_tajweed_1441',
  'package_url': url,
  'sha256': '0' * 64,
  'size_bytes': 10,
  'pagination_matches_builtin': false,
  'word_alignment_matches_builtin': true,
  'font_mode': unicode ? 'unicode_single' : 'page_glyph',
  if (unicode) 'license_sha256': '1' * 64,
  'navigation_index_file': 'pagination.json',
  'navigation_index_sha256': '2' * 64,
};
