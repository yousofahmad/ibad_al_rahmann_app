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

  testWidgets('native language labels select the exact downloadable variant', (
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
    expect(find.text('English'), findsWidgets);
    expect(find.text('Español'), findsWidgets);
    final english = tester.widget<Text>(find.text('English').last);
    expect(english.textDirection, TextDirection.ltr);
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(selected, 'family_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single-language family shows a disabled language choice', (
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
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('tafsir-language-selector')),
    );
    expect(dropdown.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
