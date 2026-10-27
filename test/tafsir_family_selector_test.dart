import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_catalog.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/tafsir_family_selector.dart';

void main() {
  const books = [
    TafsirBook(
      id: 'saadi_ar',
      name: 'Tafsir As-Saadi',
      author: '',
      groupId: 'tafsir_al_saadi',
      groupName: 'Tafsir As-Saadi',
      languageCode: 'ar',
    ),
    TafsirBook(
      id: 'tabari_ar',
      name: 'Tafsir al-Tabari',
      author: '',
      groupId: 'tabari',
      groupName: 'Tafsir al-Tabari',
      languageCode: 'ar',
    ),
  ];

  testWidgets('Arabic names are searchable and select the intended family', (
    tester,
  ) async {
    final groups = TafsirCatalog.groupBooks(books);
    expect(
      groups.firstWhere((group) => group.id == 'tafsir_al_saadi').displayName,
      'تفسير السعدي',
    );
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TafsirFamilySelector(
              groups: groups,
              selectedGroupId: 'tafsir_al_saadi',
              onChanged: (group) => selected = group.id,
            ),
          ),
        ),
      ),
    );
    expect(find.text('تفسير السعدي'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tafsir-family-selector')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tabari');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tafsir-family-option-tabari')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tafsir-family-option-tafsir_al_saadi')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('tafsir-family-option-tabari')));
    await tester.pumpAndSettle();
    expect(selected, 'tabari');
    expect(tester.takeException(), isNull);
  });
}
