import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/feature_resource_repository.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _resourceRoot = String.fromEnvironment('IBAD_LOCAL_RESOURCE_ROOT');

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

  test(
    'merges the actual local QUL catalog without empty or duplicate books',
    () async {
      expect(_resourceRoot, isNotEmpty);

      await TafsirHelper.fetchRemoteBooks();

      final books = TafsirHelper.availableBooks;
      final byId = {for (final book in books) book.id: book};
      final index = await FeatureResourceRepository.configured.readJson(
        'tafseer/tafseer_index.json',
      );
      expect(index, isNotNull);
      final indexedBooks = (index!['tafseer_books'] as List)
          .whereType<Map>()
          .toList();
      expect(indexedBooks, hasLength(105));
      expect(books.where((book) => !book.isBuiltIn), hasLength(105));
      expect(
        byId.keys,
        containsAll(indexedBooks.map((item) => item['id'].toString())),
      );
      expect(byId.keys, containsAll(['muyassar', 'ibn_katheer', 'tabari']));
      expect(byId.keys, isNot(contains('qul_tafsir_41')));
      expect(byId.keys, isNot(contains('qul_tafsir_250')));
      expect(byId.keys, isNot(contains('qul_tafsir_22')));
      expect(byId.keys, isNot(contains('qul_tafsir_37')));

      expect(
        books.where((book) => book.sourceId == 22).map((book) => book.id),
        ['ibn_katheer'],
      );
      expect(
        books.where((book) => book.sourceId == 37).map((book) => book.id),
        ['tabari'],
      );

      final saadi = TafsirHelper.availableBookGroups.firstWhere(
        (group) => group.id == 'tafsir_al_saadi',
      );
      expect(saadi.variants.map((book) => book.id), contains('qul_tafsir_308'));
      expect(saadi.variants.map((book) => book.id), contains('qul_tafsir_503'));
      expect(
        saadi.variants
            .firstWhere((book) => book.id == 'qul_tafsir_503')
            .languageLabel,
        'Bahasa Indonesia',
      );
      expect(
        TafsirHelper.availableBookGroups.any((group) => group.id == 'as_saadi'),
        isFalse,
      );

      await CacheHelper.prefs.setString(
        'selected_tafsir_variant_as_saadi',
        'qul_tafsir_503',
      );
      expect(TafsirHelper.preferredBookForGroup(saadi).id, 'qul_tafsir_503');
    },
  );
}
