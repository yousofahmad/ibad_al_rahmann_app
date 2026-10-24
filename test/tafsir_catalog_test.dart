import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

const familyFixture = {
  'id': 'example_family',
  'name': 'تفسير متعدد اللغات',
  'author': 'المؤلف',
  'variants': [
    {
      'id': 'example_ar',
      'language_code': 'ar',
      'url': 'tafseer/ar-example.zip',
    },
    {
      'id': 'example_en',
      'language_code': 'en',
      'url': 'tafseer/en-example.zip',
    },
    {
      'id': 'example_es',
      'language_code': 'es',
      'url': 'tafseer/es-example.zip',
    },
  ],
};

class _CatalogAdapter implements HttpClientAdapter {
  _CatalogAdapter({this.offline = false});
  final bool offline;
  int requests = 0;
  final requestedPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    requestedPaths.add(options.uri.path);
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final isTafsirIndex = options.path.endsWith('/tafseer/tafseer_index.json');
    return ResponseBody.fromString(
      json.encode({
        'tafseer_books': [
          if (isTafsirIndex) ...[
            familyFixture,
            {
              'id': 'tabari',
              'name': 'QUL al-Tabari metadata',
              'author': '',
              'group_id': 'qul_tafsir_37',
              'group_name': 'Tafsir al-Tabari',
              'language_code': 'ar',
              'source_id': 37,
              'url': 'tafseer/ar-tafsir-al-tabari.zip',
            },
            {
              'id': 'ibn_katheer',
              'name': 'QUL Ibn Kathir metadata',
              'group_id': 'ibn_katheer',
              'group_name': 'تفسير ابن كثير',
              'language_code': 'ar',
              'source_id': 22,
              'url': 'tafseer/ar-tafsir-ibn-kathir.zip',
            },
            {
              'id': 'qul_tafsir_22',
              'name': 'Duplicate Ibn Kathir Arabic export',
              'group_id': 'ibn_katheer',
              'language_code': 'ar',
              'source_id': 22,
              'url': 'qul_local/tafseer/22-ar-tafsir-ibn-kathir.json.zip',
            },
            {
              'id': 'qul_tafsir_37',
              'name': 'Duplicate al-Tabari Arabic export',
              'group_id': 'tabari',
              'language_code': 'ar',
              'source_id': 37,
              'url': 'qul_local/tafseer/37-ar-tafsir-al-tabari.json.zip',
            },
            {
              'id': 'qul_tafsir_41',
              'name': 'Indonesian Jalalayn empty export',
              'group_id': 'jalalayn',
              'language_code': 'id',
              'source_id': 41,
              'url': 'tafseer/in-tafsir-jalalayn.zip',
            },
            {
              'id': 'qul_tafsir_250',
              'name': 'Asseraj fi Bayan Gharib AlQuran',
              'group_id': 'unassigned_source_250',
              'language_code': 'ar',
              'source_id': 250,
              'url': 'tafseer/qul_tafsir_250.zip',
            },
            {
              'id': 'qul_tafsir_bad_audit',
              'name': 'Unparsed catalog item',
              'language_code': 'ar',
              'audit_status': 'empty_export',
              'url': 'tafseer/unparsed.zip',
            },
            {
              'id': 'qul_tafsir_308',
              'name': 'Tafsir As-Saadi',
              'group_id': 'tafsir_al_saadi',
              'group_name': 'تفسير السعدي',
              'language_code': 'ar',
              'language_name': 'العربية',
              'source_id': 308,
              'audit_status': 'parsed_valid',
              'url': 'tafseer/qul_tafsir_308.zip',
            },
            {
              'id': 'qul_tafsir_503',
              'name': 'Tafsir As-Saadi - Indonesian',
              'group_id': 'tafsir_al_saadi',
              'group_name': 'تفسير السعدي',
              'language_code': 'id',
              'language_name': 'Bahasa Indonesia',
              'source_id': 503,
              'audit_status': 'parsed_valid',
              'url': 'tafseer/qul_tafsir_503.zip',
            },
          ] else ...[
            {
              'id': 'legacy_config_only',
              'name': 'Legacy app config book',
              'url': 'tafseer/legacy.zip',
            },
            {'id': 'muyassar', 'name': 'must not replace the built-in book'},
          ],
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_CatalogAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    TafsirHelper.availableBooks
      ..clear()
      ..addAll(TafsirHelper.defaultBooks);
  });

  tearDown(() {
    TafsirHelper.availableBooks
      ..clear()
      ..addAll(TafsirHelper.defaultBooks);
  });

  test('one explicit family holds three independently downloadable IDs', () {
    final books = TafsirCatalog.flattenItems([
      familyFixture,
    ]).map(TafsirBook.fromJson).toList();
    final groups = TafsirCatalog.groupBooks(books);
    expect(groups, hasLength(1));
    expect(groups.single.name, 'تفسير متعدد اللغات');
    expect(groups.single.variants.map((book) => book.id), [
      'example_ar',
      'example_en',
      'example_es',
    ]);
    expect(books.map((book) => book.languageLabel), [
      'العربية',
      'English',
      'Español',
    ]);
    expect(books.map((book) => book.isRtl), [true, false, false]);
    expect(books.map((book) => book.author).toSet(), {'المؤلف'});
  });

  test('legacy flat books remain separate; names are not fuzzy-matched', () {
    final maps = TafsirCatalog.flattenItems([
      {'id': 'book_a', 'name': 'Same title', 'author': 'A'},
      {'id': 'book_b', 'name': 'Same title', 'author': 'B'},
    ]);
    final books = maps.map(TafsirBook.fromJson);
    expect(TafsirCatalog.groupBooks(books), hasLength(2));
    expect(TafsirHelper.availableBookGroups, hasLength(3));
    expect(TafsirHelper.defaultBooks.every((book) => book.isRtl), isTrue);
  });

  test(
    'explicit same-language source editions are retained, IDs deduplicated',
    () {
      const a = TafsirBook(
        id: 'edition_a',
        name: 'Book',
        author: 'Author',
        groupId: 'family',
        languageCode: 'ar',
        edition: 'نسخة أ',
      );
      const b = TafsirBook(
        id: 'edition_b',
        name: 'Book',
        author: 'Author',
        groupId: 'family',
        languageCode: 'ar',
        edition: 'نسخة ب',
      );
      final group = TafsirCatalog.groupBooks([a, b, a]).single;
      expect(group.variants, hasLength(2));
      expect(group.variantLabel(a), 'العربية — نسخة أ');
      expect(group.variantLabel(b), 'العربية — نسخة ب');
    },
  );

  test(
    'language metadata and original download ID survive JSON round trip',
    () {
      final book = TafsirBook.fromJson({
        'id': 'legacy_download_id',
        'name': 'Book',
        'author': 'Author',
        'group_id': 'family',
        'group_name': 'Family',
        'language_code': 'es',
        'url': 'tafseer/es-example.zip',
        'text_direction': 'ltr',
        'source_id': 22,
      });
      final restored = TafsirBook.fromJson(book.toJson());
      expect(restored.id, 'legacy_download_id');
      expect(restored.sourceId, 22);
      expect(restored.familyId, 'family');
      expect(restored.familyName, 'Family');
      expect(restored.languageLabel, 'Español');
      expect(restored.url, book.url);
      expect(restored.isRtl, isFalse);
    },
  );

  test('invalid family/cache IDs are not accepted', () {
    expect(
      TafsirCatalog.flattenItems([
        {
          'id': '../invalid',
          'variants': [
            {'id': 'valid_variant'},
          ],
        },
      ]),
      isEmpty,
    );
    expect(
      TafsirCatalog.groupBooks([
        const TafsirBook(id: '../invalid', name: 'Book', author: ''),
      ]),
      isEmpty,
    );
  });

  test('unknown language is explicit instead of being mislabeled Arabic', () {
    final book = TafsirBook.fromJson({'id': 'unknown', 'name': 'Book'});
    expect(book.languageLabel, 'لغة غير محددة');
    expect(book.isRtl, isFalse);
  });

  test(
    'remote variants and per-family choice survive an offline restart',
    () async {
      final online = _CatalogAdapter();
      await TafsirHelper.fetchRemoteBooks(client: _client(online));
      expect(online.requests, 2);
      expect(
        online.requestedPaths[0],
        contains('/source/import-qul-resources/app_config.json'),
      );
      expect(
        online.requestedPaths[1],
        contains('/source/import-qul-resources/tafseer/tafseer_index.json'),
      );
      expect(TafsirHelper.availableBooks.first.name, 'التفسير الميسر');
      expect(
        TafsirHelper.availableBooks.any(
          (book) => book.id == 'legacy_config_only',
        ),
        isTrue,
      );
      expect(
        TafsirHelper.availableBooks
            .where((book) => book.id == 'ibn_katheer')
            .map((book) => book.name),
        ['تفسير ابن كثير'],
      );
      expect(
        TafsirHelper.availableBooks.where((book) => book.id == 'tabari'),
        hasLength(1),
      );
      expect(
        TafsirHelper.availableBooks
            .where((book) => book.id == 'tabari')
            .single
            .groupId,
        'tabari',
      );
      expect(
        TafsirHelper.availableBooks.where(
          (book) => {
            'qul_tafsir_22',
            'qul_tafsir_37',
            'qul_tafsir_41',
            'qul_tafsir_250',
            'qul_tafsir_bad_audit',
          }.contains(book.id),
        ),
        isEmpty,
      );
      final saadi = TafsirHelper.availableBookGroups.firstWhere(
        (group) => group.id == 'tafsir_al_saadi',
      );
      expect(saadi.variants.map((book) => book.languageLabel), [
        'العربية',
        'Bahasa Indonesia',
      ]);
      final group = TafsirHelper.availableBookGroups.firstWhere(
        (group) => group.id == 'example_family',
      );
      expect(group.variants, hasLength(3));
      await TafsirHelper.setSelectedBookId('example_es');
      expect(TafsirHelper.preferredBookForGroup(group).id, 'example_es');

      // Simulate a fresh process whose remote catalog is temporarily unavailable.
      TafsirHelper.availableBooks
        ..clear()
        ..addAll(TafsirHelper.defaultBooks);
      final offline = _CatalogAdapter(offline: true);
      await TafsirHelper.fetchRemoteBooks(client: _client(offline));
      expect(offline.requests, 2);
      final restored = TafsirHelper.availableBookGroups.firstWhere(
        (group) => group.id == 'example_family',
      );
      expect(restored.variants, hasLength(3));
      expect(TafsirHelper.getSelectedBookId(), 'example_es');
      expect(
        TafsirHelper.preferredBookForGroup(restored).languageLabel,
        'Español',
      );
    },
  );
}
