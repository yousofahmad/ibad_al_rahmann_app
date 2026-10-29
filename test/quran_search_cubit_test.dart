import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';

void main() {
  late SearchCubit cubit;

  setUp(() => cubit = SearchCubit());
  tearDown(() => cubit.close());

  test('finds verses when the query omits Quranic diacritics', () {
    cubit.onSearch('الرحمن');

    final state = cubit.state as OnSearch;
    expect(
      state.verses.any(
        (verse) => verse.surahNumber == 1 && verse.verseNumber == 1,
      ),
      isTrue,
    );
  });

  test(
    'matches diacritized queries and returns the original Uthmani verse',
    () {
      cubit.onSearch('ٱلرَّحْمَٰنِ');

      final state = cubit.state as OnSearch;
      final verse = state.verses.singleWhere(
        (item) => item.surahNumber == 1 && item.verseNumber == 1,
      );
      expect(verse.content, contains('ٱلرَّحۡمَٰنِ'));
    },
  );

  test('clears short queries and explicit clear resets the controller', () {
    cubit.controller.text = 'رب';
    cubit.onSearch('رب');
    expect((cubit.state as OnSearch).verses, isEmpty);

    cubit.controller.text = 'الرحمن';
    cubit.clear();
    expect(cubit.controller.text, isEmpty);
    expect((cubit.state as OnSearch).verses, isEmpty);
  });
}
