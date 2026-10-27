import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_catalog.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/tafsir_language_selector.dart';

void main() {
  const books = [
    TafsirBook(
      id: 'family_ar',
      name: 'تفسير',
      author: '',
      groupId: 'family',
      languageCode: 'ar',
      isBuiltIn: true,
    ),
    TafsirBook(
      id: 'family_en',
      name: 'تفسير',
      author: '',
      groupId: 'family',
      languageCode: 'en',
    ),
    TafsirBook(
      id: 'family_es',
      name: 'تفسير',
      author: '',
      groupId: 'family',
      languageCode: 'es',
    ),
  ];

  testWidgets('native-language labels select the exact downloadable variant', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 280,
              child: TafsirLanguageSelector(
                group: TafsirCatalog.groupBooks(books).single,
                selectedBookId: 'family_ar',
                downloadedStatus: const {'family_en': true},
                onChanged: (book) => selected = book.id,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tafsir-language-selector')));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    final englishRow = tester.widget<ListTile>(
      find.byKey(const ValueKey('tafsir-language-option-family_en')),
    );
    expect((englishRow.title! as Text).textDirection, TextDirection.ltr);
    expect(englishRow.leading, isA<Icon>());
    await tester.tap(
      find.byKey(const ValueKey('tafsir-language-option-family_en')),
    );
    await tester.pumpAndSettle();
    expect(selected, 'family_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('long edition labels remain readable in the chooser', (
    tester,
  ) async {
    const longBook = TafsirBook(
      id: 'long_id',
      name: 'Book',
      author: '',
      groupId: 'long_family',
      languageCode: 'id',
      languageName: 'Bahasa Indonesia',
      edition:
          'Edisi bahasa Indonesia dengan nama yang cukup panjang agar tidak terpotong di layar ponsel',
    );
    const arabicBook = TafsirBook(
      id: 'arabic_id',
      name: 'Book',
      author: '',
      groupId: 'long_family',
      languageCode: 'ar',
    );
    final group = TafsirCatalog.groupBooks([arabicBook, longBook]).single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: TafsirLanguageSelector(
              group: group,
              selectedBookId: arabicBook.id,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tafsir-language-selector')));
    await tester.pumpAndSettle();
    final longRow = tester.widget<ListTile>(
      find.byKey(const ValueKey('tafsir-language-option-long_id')),
    );
    expect(
      (longRow.title! as Text).data,
      contains('Edisi bahasa Indonesia dengan nama yang cukup panjang'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single-language family keeps its selector disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TafsirLanguageSelector(
            group: TafsirCatalog.groupBooks([books.first]).single,
            selectedBookId: books.first.id,
            onChanged: (_) => fail('a single variant must not change'),
          ),
        ),
      ),
    );
    final selector = tester.widget<InkWell>(
      find.byKey(const ValueKey('tafsir-language-selector')),
    );
    expect(selector.onTap, isNull);
    expect(tester.takeException(), isNull);
  });
}
